# SoC 顶层

`rtl/soc/heterogeneous_soc_top.v` 集成 RV32IM 五级流水 CPU、I/D Cache、AXI4 数据互连、
ROM/RAM/外部存储接口、DMA、AXI4-Lite/APB 外设、PMU 与 JTAG debug。

CPU 的 I-Cache、D-Cache 通过各自的 `native_to_axi4_master` 进入 AXI4；DMA 通过第三个
master 进入同一互连。低速 UART、Timer、GPIO、SPI、QSPI、I2C、PMU 由控制岛转接至 APB。

公开版不集成外部加速器 RTL；顶层保留静默 master/control 槽以维持已有端口和地址布局。
