# 28 nm Design Compiler：RV32IM CPU baseline

## 目标与边界

本流程只综合 `riscv_cpu_core`，用于建立 CPU microarchitecture 的 28 nm
PPA baseline。它不综合完整 SoC、AXI fabric、DDR 或外设，也不是
physical signoff、IR/EM、DFT、低功耗或 post-layout 结论。

`docs/PDK_USAGE_GUIDE.md` 规定 PDK 不入 Git、路径仅通过本机环境变量传入；本
数字 CPU flow 不包含 ADS/RF 电路仿真。

## 本机前提

在已加载 Synopsys DC 与合法 28 nm PDK 的 Linux shell 中设置本机变量。实际
值不可提交、不可写入文档或 tracked log：

```bash
# 必须在 Bash 提示符执行；不要先进入 `dc_shell>`。
# 变量值仅示意；使用本机已授权的 .db 文件。
export ASIC28_MAX_LIB='<slow/setup corner standard-cell .db>'
export ASIC28_MIN_LIB='<fast/hold corner standard-cell .db>'  # 可选但建议
export ASIC28_CLK_NS=5.000  # 首轮 200 MHz；之后用相同约束做 sweep

bash tools/asic/run_dc_cpu.sh
```

`export`、`bash` 和 `grep` 是 Bash 命令，不能在 `dc_shell>` 提示符执行。
该启动脚本会自行启动 DC；若已进入 DC，请先输入 `exit` 返回 Bash。尖括号
`<...>` 只是文档占位符，实际执行时必须替换为真实本机文件路径，不能原样输入。

若希望在已经打开的 `dc_shell>` 中直接运行，不使用 Bash wrapper，则使用 DC Tcl：

```tcl
# 以下值必须换为本机真实 .db 路径；不是 Bash 的 export 语法。
set ::env(REPO_ROOT) "<repository root>"
set ::env(ASIC28_MAX_LIB) "/local/pdk/slow_setup.db"
set ::env(ASIC28_MIN_LIB) "/local/pdk/fast_hold.db"
set ::env(ASIC28_CLK_NS) "5.000"
set ::env(ASIC28_OUT_DIR) "<repository root>/build/asic28_cpu"
source $::env(REPO_ROOT)/tools/asic/dc_cpu_synth.tcl
```

两种启动方式二选一；推荐 Bash wrapper，因为环境变量、输出目录和日志更容易复现。

DC 必须能访问 `ASIC28_MAX_LIB`。若设置 `ASIC28_MIN_LIB`，脚本使用
`set_min_library` 建立 hold 分析关联。corner、V/T、operating condition 的
准确含义以 PDK 文档为准；不要根据文件名臆测。

可选变量：

| 变量 | 默认值 | 含义 |
| --- | ---: | --- |
| `ASIC28_IO_DELAY_NS` | `0.200` | CPU 同步集成边界的输入/输出 delay |
| `ASIC28_CLK_UNCERTAINTY_NS` | `0.100` | baseline clock uncertainty |
| `ASIC28_CLK_TRANSITION_NS` | `0.050` | baseline clock transition |
| `ASIC28_MAX_CORES` | `4` | DC host cores |
| `ASIC28_OUT_DIR` | `build/asic28_cpu` | 忽略的本地输出目录 |
| `DC_BIN` | `dc_shell` | DC 可执行文件名/本机路径 |

I/O delay、uncertainty 与 transition 是用于 CPU RTL A/B 的统一假设，而不是
封装、板级或 SoC signoff 约束。修改它们必须建立新的 baseline，不能与旧报告
直接比较。

## 结果与验收

输出位于忽略目录 `build/asic28_cpu/`：

- `check_design.rpt`：必须无设计错误；
- `qor.rpt`、`area.rpt`：面积和 QoR；
- `timing_setup.rpt`、`timing_hold.rpt`、`constraints.rpt`：setup/hold；
- `power_vectorless.rpt`：仅 vectorless 估算，不能作为真实 workload 功耗；
- `riscv_cpu_core.ddc`、mapped Verilog、SDC：本地交接产物。

首轮只接受 `check_design` 正常且 setup/hold 均无违例的配置作为该频点 PASS。
应先用同一 library、corner、I/O 约束扫描若干 clock period，再比较 Fmax/area。
若脚本报 `.db` 不可读、`No target library found`、`unmapped components` 或 mapping
gate 缺失，该轮即为 FAIL，所有同轮输出均不可用于 PPA 对比。

## PPA 优化纪律

1. 先依据 `timing_setup.rpt` 的真实 worst path 决定改动，禁止只改约束来制造
   更好 WNS。
2. 乘法、旁路、移位、cache tag/data mux 或高扇出控制路径分别处理；每个 RTL
   改动先跑对应 XSim 专项，再跑 ISA/FreeRTOS smoke。
3. `cache_ram_1r1w` 目前是行为级 array。未接 28 nm SRAM macro 时，DC 可能以
   flip-flop/mux 实现 cache；此时 cell area 只能作为 RTL baseline，不能和
   SRAM-macro 面积混报。
4. 当前默认 32-entry BTB/BHT 已有功能验证和短窗口 CoreMark 对照。可在同一
   DC 条件下与 16-entry 对照，依据实际 timing/area 决定保留与否。
5. `compile_ultra` baseline 禁用 retiming 与自动 clock gating 试验；这些是后续
   单独验证的 PPA 实验，不能与基线混在一起。

在有真实 workload VCD/SAIF、准确 activity、供电和 PVT 定义前，功耗只可称为
vectorless estimate，不能称为芯片功耗或 signoff 结果。

## SRAM-aware 首轮结果（2026-08-22）

本轮以本机已授权的 28 nm 标准单元 slow/setup 与 fast/hold corner、同一 PVT 的
本地 SRAM macro wrapper 执行 `riscv_cpu_core` 综合。wrapper、SRAM `.db`、DC
报告和映射网表均在忽略的 `build/` 目录；仓库不保存 PDK 路径、macro 文件或其内容。

- `CacheUseBlockRam` 同步读 D-cache 专项 XSim：`DCACHE_STORE_PATH_TB_PASS`。
- DC QoR：macro count = 2，证明 I-cache 与 D-cache data array 均实际绑定 macro。
- 5.000 ns（200 MHz）setup：critical path 4.88 ns、slack +0.01 ns、TNS 0，**setup PASS**。
- 面积：standard-cell combinational 17163.92、noncombinational 20938.39、两块 macro
  37546.83，总 cell area 75649.13（library area unit）；该数字是 pre-layout estimate，
  不可视为 die area。
- hold：最坏 hold slack -0.11 ns，12618 条违例，**hold FAIL**。因此本轮不是可签收
  PPA baseline；不可宣称 200 MHz 已闭合。

最坏 setup 路径位于 ID/EX 相关跳转操作数寄存器路径。下一轮应先补齐真实的 clock
tree/uncertainty、I/O load 与 min-delay 约束策略，定位并修复 hold，再在完全相同条件
下比较分支预测器、旁路或高扇出控制逻辑的 RTL 优化。不得仅放宽 hold 约束来制造 PASS。

### Hold 建模与修复复验（2026-08-22）

首轮的 `0.100 ns` clock uncertainty 同时约束 setup 与 hold，会把 setup jitter/margin
不恰当地全部施加在 pre-CTS hold 分析上。flow 现明确拆分为 setup uncertainty `0.100 ns`
与 hold uncertainty `0.020 ns`，并在综合中启用普通标准单元 delay-buffer 的 hold 修复。

- 同 RTL、同 library、同 5.000 ns clock 下，setup 仍为 critical path 4.88 ns、slack
  +0.01 ns、TNS 0；macro count 与 total cell area 均不变。
- hold 从 12618 条、最坏 -0.11 ns 收敛为 53 条、最坏 -0.03 ns。
- 剩余违例全为 register-to-SRAM-macro address/data min path，而不是 CPU pipeline 的
  EX、forwarding 或 branch path。

这证明首轮的绝大多数 hold 报警源于约束建模；剩余 53 条需要在后续 CTS、placement 和
寄生参数可用后，由物理实现阶段插入 hold buffer 或实施有依据的 useful skew。当前
CPU-only pre-CTS flow 仍标记为 **hold not closed**，不得通过进一步减小 hold margin 或
在 RTL 中人为插入反相器来制造通过。
