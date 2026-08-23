# 项目更新日志

## 2026-08-23 +08:00

### JALR forwarding 时序闭环

- 将 JALR base operand 从直接 EX forwarding feedback 改为 MEM/WB late forwarding 或寄存器堆，并在 EX ALU → JALR RAW 时插入一个显式 bubble；普通 ALU/branch 的 EX forwarding 不变。
- 新增 `id_jalr_forwarding_tb.sv` 与 `jalr_forwarding` bare-metal SoC 用例；本次 XSim 分别得到 `ID_JALR_FORWARDING_TB_PASS`、`TEST_PASS`（675 cycles / 161 instructions）和 `simple` smoke `TEST_PASS`（3250 cycles / 2010 instructions）。
- 使用本机授权 28 nm SS setup standard-cell library、同一 5.000 ns 约束，对改动前/后 `jalr_timing_cone_top` 完成 DC A/B：改动前 EX→ID/EX 路径 80 logic levels、4.90 ns、+0.00 ns slack；改动后直接路径被移除，MEM/WB late-value→ID/EX 路径为 0.09 ns、+4.77 ns slack。该数字仅代表定向 timing cone，不代表完整 CPU PPA/Fmax，且本次没有有效 min library 的 hold 结论。
- 修正 DC 脚本在未启用 SRAM profile 时把空 SRAM library 加入 `link_library` 的问题；新增 timing-cone 的可复现报告入口。
- 同步修正文档中历史遗留的 AXI multi-outstanding/OoO 表述：当前公开实现为单个全局 outstanding transaction。

## 2026-08-22 +08:00

### 公开版收敛与隐私清理

- 删除外部参考加速器的 RTL、wrapper、软件用例、专项 TB、工具与模块文档；`reference_project/` 保持本地忽略，不进入 Git。
- 新鲜验证：`run_axi4_control_island_tb.ps1` 通过；`run_sw_example.ps1 -ExampleName simple -Snapshot public_cpu_dma_smoke` 通过（`TEST_PASS`）。
- 公开 SoC 固定为 CPU/DMA 版，保留一个 quiescent reserved accelerator slot 以维持既有 control-island/crossbar 集成边界。
- 删除脚本中硬编码的本机 Python 用户目录，将 DC 文档绝对路径改为 `<repository root>` 占位符。
- 清除项目模板中的工具供应商名称；Apache-2.0 上游文件的版权头、`LICENSE` 与 `NOTICE` 仍保留。
- 本次仅完成公开源树收敛；新的 CPU/DMA SoC XSim、FPGA 和板测验收须在当前 commit 重新执行。
