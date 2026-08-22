# 模块说明索引

本目录记录公开 CPU/DMA 版的现行模块边界、RTL 入口和验证入口。历史变更统一记录在
[`../update_log.md`](../update_log.md)，当前签收状态以 [`../STATUS.md`](../STATUS.md) 为准。

| 模块 | 说明 |
| --- | --- |
| 顶层 SoC | [soc_top.md](soc_top.md) |
| RV32IM CPU | [cpu.md](cpu.md) |
| I/D Cache 与预测 | [cache_predictor.md](cache_predictor.md) |
| AXI4 互连与存储 | [axi_memory.md](axi_memory.md) |
| AXI4-Lite / APB 控制岛 | [control_island.md](control_island.md) |
| DMA | [dma.md](dma.md) |
| I2C master | [i2c_master.md](i2c_master.md) |
| 其他 APB 外设 | [apb_peripherals.md](apb_peripherals.md) |
| FPGA / ZU15EG 板级 | [fpga_zu15eg.md](fpga_zu15eg.md) |
| 验证与回归 | [verification.md](verification.md) |

建议阅读顺序：`soc_top → cpu/cache → axi_memory/control_island → dma → verification`；
板级工作再阅读 `fpga_zu15eg`。
