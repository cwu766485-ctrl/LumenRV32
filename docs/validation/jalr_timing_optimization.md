# JALR forwarding 时序优化记录

## 目标

建立一次可复核的 `timing report → RTL 改动 → 功能回归 → 同约束 DC A/B` 闭环。

初始 28 nm DC 报告定位到一个 EX 结果直接经 ID forwarding 进入下一条 `JALR` 目标操作数的反馈路径。该路径跨越 EX 运算、forwarding 选择、JALR 操作数生成与 `id_ex` 捕获，不适合继续作为高频单周期组合链。

## RTL 改动与取舍

- `rtl/core/id.v`：JALR 的 base operand 改为只从 MEM/WB forwarding 或寄存器堆取得；普通 ALU/branch 的 EX forwarding 保持不变。
- `rtl/core/riscv_cpu_core.v`：检测“前一条非 load EX 指令写入 JALR rs1”的情况，插入一个 `jalr_ex_alu_hazard_flag` bubble。
- 因而 JALR 紧跟产生其 base 的 ALU 指令时会多一个周期；换来的是 JALR target 不再依赖同周期 EX combinational result。该改动是明确的 timing/IPC trade-off，不应描述为无代价提频。

## 功能验证

| 项目 | 命令/用例 | 新鲜结果 |
| --- | --- | --- |
| ID forwarding 定向 TB | `tools/run_id_jalr_forwarding_tb.ps1` | `ID_JALR_FORWARDING_TB_PASS` |
| EX 结果紧邻 JALR 的 SoC 程序 | `tests/example/jalr_forwarding` | XSim `TEST_PASS`，675 cycles / 161 instructions |
| 基础 CPU 程序 smoke | `run_sw_example.ps1 -ExampleName simple` | XSim `TEST_PASS`，3250 cycles / 2010 instructions |

定向 TB 覆盖 JALR 的 MEM forwarding、WB forwarding、寄存器堆 fallback，以及非 JALR 指令仍保留 EX forwarding。

## 28 nm DC timing-cone A/B

为避免 behavioral cache array 主导面积，A/B 使用 `rtl/soc/jalr_timing_cone_top.v`：它包含真实的 `ex`、`id`、`id_ex` 模块和其寄存器边界，但不代表完整 CPU 或 SoC 面积。该 harness 只用于量化本次 EX→JALR feedback cone。

共同条件：28 nm 标准单元 SS setup corner、`ASIC28_CLK_NS=5.000`、输入/输出 delay 0.200 ns、setup uncertainty 0.100 ns。仅加载 max/setup `.db`；由于本地 FF/min `.db` 与 SS 库 cell namespace 不匹配，**本次不报告 hold 结论**。

| 版本 | 受测路径 | logic levels | data arrival | setup slack |
| --- | --- | ---: | ---: | ---: |
| baseline（改动前 commit） | `producer_op2_r_reg[0]` → `u_id_ex/op1_jump_reg[31]` | 80 | 4.90 ns | +0.00 ns |
| optimized（本改动） | 直接 EX→ID/EX 路径 | 已不存在 | — | — |
| optimized（本改动） | `late_data_r_reg[31]` → `u_id_ex/op1_jump_reg[31]` | 0 | 0.09 ns | +4.77 ns |

这证明的是目标组合反馈 cone 被切断，并由已寄存的 MEM/WB late value 驱动；它**不等价于完整 CPU Fmax 从 200 MHz 提升到更高频率**，也不能将 timing-cone 的 cell area 当作完整 CPU area。完整 CPU 的 SRAM-aware PPA 仍需匹配 PVT 的 SRAM macro wrapper 和完整实施约束。

## 复现

先在 Linux shell（不是 `dc_shell>` prompt）设置本机 PDK 环境变量，再运行：

```bash
export ASIC28_MAX_LIB='<local 28nm SS setup .db>'
export ASIC28_TOP=jalr_timing_cone_top
export ASIC28_CLK_NS=5.000
export ASIC28_OUT_DIR=build/asic28_jalr_cone
bash tools/asic/run_dc_cpu.sh
```

优化前结果应从该改动父 commit 使用相同命令重跑；对比 `jalr_ex_to_idex.rpt` 和 `jalr_late_to_idex.rpt`。PDK、`.db`、DC 输出和报告均为本地生成物，不提交到 Git。

## 边界与下一步

- 尚未完成全 ISA 回归、同 commit 的完整 CPU SRAM-aware DC，或更新后的 ZU15EG P&R；不得复用历史 FPGA 结果作为本改动的板级验收。
- 后续若继续提频，应以完整 CPU 的真实 worst path 为准，依次评估 operand-select、branch/JALR、旁路网络和高扇出控制，而不是扩大本 timing cone 的数字。
