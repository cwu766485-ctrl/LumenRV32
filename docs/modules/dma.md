# DMA

DMA 通过 AXI4-Lite 寄存器配置，通过 native-to-AXI4 adapter 访问存储路径。它与 CPU I/D
访问共享 AXI4 crossbar，适合作为 burst、backpressure、缓存与外部存储交互的验证对象。

公开回归入口：`tools/run_dma_full_regression.ps1`；寄存器封装 RTL 为
`rtl/perips/dma_axil_wrapper.v`。
