# ZU15EG 板级路径

公开版保留两条板级验证路径：

1. `tools/build_zu15eg_riscv_bram_uart.ps1`：最小 BRAM + UART 镜像，用于复位、时钟、RISC-V
   执行与串口连通性检查。
2. `tools/build_zu15eg_ddr4_cpu_smoke.ps1` 与 `tools/run_zu15eg_ddr4_cpu_smoke.ps1`：CPU/DMA
   访问 PL DDR4 的受控 smoke。

实际板卡状态受 JTAG 枚举、MIG calibration、当前 bitstream 与本次日志共同约束。不得把历史板测
记录代替本次验收；复验应保存命令、bit/LTX SHA-256、UART/ILA 证据和报告。

`tools/build_zu15eg_soc_ddr4.tcl` 是遗留的完整 SoC DDR4 实验 Tcl，当前公开版已无对应上层入口，
不属于推荐构建流程。
