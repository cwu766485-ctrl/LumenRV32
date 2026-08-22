# 其他 APB 外设

## RTL 清单

| 外设 | RTL | 说明 |
| --- | --- | --- |
| UART | `rtl/perips/uart.v` | 控制台与板级smoke输出 |
| Timer | `rtl/perips/timer.v` | 计时/中断 |
| GPIO | `rtl/perips/gpio.v` | 通用I/O |
| SPI | `rtl/perips/spi.v` | 通用SPI |
| QSPI | `rtl/perips/qspi.v` | Flash访问/启动相关路径 |
| PMU | `rtl/perips/pmu.v` | cycle、事件计数与性能观测 |
| I2C | `rtl/perips/i2c_master.v` | 见 [i2c_master.md](i2c_master.md) |

## 共同集成点

- APB address decode：`rtl/perips/apb_perips.v`
- 验证入口：`tools/run_axi_apb_regression.ps1`
- QSPI仅保留通用 APB controller 与仿真验证，不再保留 A100T 专用 boot wrapper。
- PMU寄存器：[`pmu.md`](pmu.md)

## 维护方式

当某个外设的寄存器、时序或板级路径达到独立复杂度时，以
[`TEMPLATE.md`](TEMPLATE.md) 新增其专页；不把新规格继续追加到日期化历史记录。
