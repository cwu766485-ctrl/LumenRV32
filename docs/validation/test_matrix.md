# 验证测试矩阵

更新时间：2026-08-27（+08:00）。本页是当前公开 CPU/DMA SoC 的验证索引；`PASS` 只表示表中所列命令和范围，不外推到未覆盖功能。

## 2026-08-27：Pipeline hazard UVM（新鲜结果）

`pipeline_hazard_test` 已在 Vivado 2024.1 XSim 与 Rocky-8.10 / VCS V-2023.12-SP1 重新执行：

- XSim：`CPU_UVM_PIPELINE_HAZARD_SCOREBOARD_PASS hold_load=2 redirect=92 data=12`，`CPU_UVM_PIPELINE_HAZARD_PASS`，UVM `0 error / 0 fatal`。
- VCS：同一 scoreboard token 与 `CPU_UVM_PIPELINE_HAZARD_PASS`，UVM `0 error / 0 fatal`。
- 入口：`tools/run_cpu_uvm_smoke.ps1 -TestName pipeline_hazard_test` 与 `bash tools/run_cpu_uvm_smoke.sh pipeline_hazard_test`。

这项结果仅覆盖受控的 EX/MEM/WB forwarding、load-use bubble、JAL/JALR redirect；不替代 ISA 随机测试、ISS differential、coverage closure 或 formal proof。

## 使用规则

- 每次改动先跑受影响的最小测试，再跑对应的回归入口。
- `FRESH` 是本次 UVM 工作中重新执行的结果；`RECORDED` 是已有专项记录，本轮未重跑；`BLOCKED` 与 `NOT_RUN` 不是失败，也不是通过。
- XSim 共享工作目录，PowerShell 回归必须串行运行。

## CPU 面试边界

| 范围 | 入口 | 证据/检查点 | 状态 |
| --- | --- | --- | --- |
| UVM architecture smoke | `tools/run_cpu_uvm_smoke.ps1` | native-memory BFM、forwarding、store/load、taken-branch flush、GPR/memory scoreboard、SVA | `FRESH PASS`：XSim，UVM 0 error / 0 fatal |
| UVM architecture smoke | `bash tools/run_cpu_uvm_smoke.sh` | 与 XSim 使用同一 DUT、UVM test 和 SVA | `FRESH PASS`：VCS，`CPU_UVM_VCS_SMOKE_PASS` |
| JALR timing fix | `tools/run_id_jalr_forwarding_tb.ps1` | EX-to-JALR interlock、MEM/WB late forwarding | `RECORDED PASS` |
| Branch predictor | `tools/run_branch_predictor_tb.ps1` | BTB/BHT update 与预测路径 | `RECORDED PASS` |
| D-Cache store path | `tools/run_dcache_store_path_tb.ps1` | store queue、cache/memory 可见性 | `RECORDED PASS` |
| CPU native-to-AXI path | `tools/run_axi4_cpu_ram_path_tb.ps1` | I/D request、AXI handshake、backpressure | `RECORDED PASS` |
| RV32 ISA regression | `tools/run_isa_regression.ps1` | RV32UI signature | `BLOCKED`：当前缺 RISC-V GCC/预生成工件 |

## Debug、SoC 与外设

| 范围 | 入口 | 证据/检查点 | 状态 |
| --- | --- | --- | --- |
| JTAG DMI CDC | `tools/run_jtag_dmi_cdc_tb.ps1` | 异步 TCK/CPU 时钟、40-bit payload、req/ack | `RECORDED PASS` |
| USER2 DMI transport | `tools/run_jtag_user2_transport_tb.ps1` | USER2 scan、response buffer、连续事务 | `RECORDED PASS` |
| ZU15EG USER2 debug | `tools/run_zu15eg_user2_dmi.ps1 -Mode full` | DMSTATUS、halt、GPR read、resume | `RECORDED BOARD PASS`；仅自定义 USER2/DMI 范围 |
| Bare-metal SoC smoke | `tools/run_sw_example.ps1 -ExampleName simple` | CPU 执行、cache/AXI 基本路径、PMU | `RECORDED PASS` |
| AXI/APB control path | `tools/run_axi_apb_regression.ps1` | AXI-Lite-to-APB、寄存器访问 | 有专项入口；本轮 `NOT_RUN` |
| DMA | `tools/run_dma_full_regression.ps1` | mem2mem、UART/SPI、external-memory 等 | 有专项入口；本轮 `NOT_RUN` |
| I2C RTL | `tools/run_i2c_master_tb.ps1` | ACK/NACK、读写与时序 | 有专项入口；本轮 `NOT_RUN` |
| QSPI / PS-I2C | `run_zu15eg_qspi_read_id.ps1` / `run_zu15eg_ps_i2c_read.ps1` | 板级外设读取 | 有脚本；未作为当前 commit 验收 |
| Protocol VIP | `verify/vip_sanity/scripts/run_dut_harness_compile.ps1` | APB、AXI4、AXI-Lite、UART、I2C、SPI harness 编译 | harness 已准备；外部 VIP `NOT_RUN` |

## 当前只推进的下一项

在重新运行 CPU 定向回归前，不新增第二个大型验证环境。下一项仅为 `tests/pipeline_hazard_test.svh`：将 EX/MEM/WB forwarding、load-use bubble、JAL/JALR redirect 拆成一个独立 UVM test，并保留现有 smoke 作为最小回归。
