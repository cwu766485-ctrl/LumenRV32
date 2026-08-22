# AXI4-Lite / APB 控制岛

`axi4_control_island` 对 CPU 的 AXI4 请求解码：DMA AXI4-Lite 控制窗口位于
`0x2000_5000`；低速外设访问经 `axi_lite_apb_bridge` 和 `apb_perips` 转到 UART、Timer、GPIO、
SPI、QSPI、I2C 与 PMU。

`0x2000_6000` 保留为未实现窗口：在公开版中它只返回静默的确定性响应，不连接外部加速器。

相关 RTL：`rtl/interconnect/axi4_control_island.v`、`rtl/perips/dma_axil_wrapper.v`、
`rtl/perips/axi_lite_apb_bridge.v`、`rtl/perips/apb_perips.v`。
