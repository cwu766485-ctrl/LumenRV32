# 协议 VIP 独立接入与自检

本目录是将第三方或自研 VIP 接到本仓库真实 DUT RTL 的**独立验证入口**。它不复制
`rtl/` 中的设计，也不把受限 VIP、license 或 PDK 文件提交进仓库。

## 目录与 DUT 对应关系

| 目录 | DUT harness | 真实 RTL | 建议连接的 VIP |
| --- | --- | --- | --- |
| `apb/` | `apb_perips_vip_harness` | `apb_perips.v` | APB master VIP |
| `axi_lite/` | `axi_lite_to_apb_vip_harness` | `axi_lite_apb_bridge.v` | AXI-Lite master VIP，APB monitor/slave VIP |
| `axi4/` | `axi4_control_island_vip_harness` | `axi4_control_island.v` | AXI4 master VIP；DMA/NPU AXI-Lite slave VIP 或 BFM |
| `uart/` | `uart_vip_harness` | `uart.v` | UART receiver/transmitter VIP |
| `i2c/` | `i2c_vip_harness` | `i2c_master.v` | I2C slave VIP（open-drain） |
| `spi/` | `spi_vip_harness` | `spi.v` | SPI slave VIP |

`vip_ahb` 暂不纳入：当前 SoC 没有 AHB/AHB-Lite DUT 接口。

## BFM 与 VIP 的验收边界

BFM 只要能依据 task/时序驱动和响应端口即可；VIP 应至少再包含 protocol monitor/checker，
并能运行正向与反向场景。接入后每项最小验收是：

1. 正常传输：写、读或一个完整串行帧；
2. backpressure/等待：AXI/AXI-Lite `READY` 延迟、APB `PREADY` 延迟，或串行从设备延迟响应；
3. 非法或边界场景：AXI `RESP`、I2C NACK/Repeated START、SPI CPOL/CPHA、UART framing；
4. VIP monitor 抓到完整 transaction，checker 未报协议错误；
5. DUT 现有定向 TB 仍通过，防止“为了适配 VIP”改变 RTL 语义。

## 连接规则

- 全部 harness 的 `rst` 为**低有效同步复位**，即 `rst==0` 时复位。
- `apb_perips` 的地址分区采用 `paddr[15:12]`：UART=`1`、SPI=`3`、I2C=`8`。
- UART/SPI harness 暴露的是外设寄存器侧端口；通常由 APB harness 驱动寄存器，同时由
  UART/SPI VIP 观察物理引脚。将它们拆开是为了先把 VIP 接口与串行时序独立定位。
- I2C 的 `scl`、`sda` 是 open-drain `tri` 网络。slave VIP 只能拉低或释放为 `Z`，不得主动驱动高电平。
- `axi4_control_island_vip_harness` 面向控制窗口，当前仅支持单拍控制访问（`AxLEN=0`）。
  DMA/NPU 子窗口分别是 `0x2000_5000` / `0x2000_6000`；其余 `0x2xxx_xxxx` 路由 APB。
- crossbar 的四主/四从聚合端口是 SoC 内部形式，不应直接接商业 AXI VIP。若后续要以 VIP
  覆盖 Stage B/C，将单独增加标准 AXI4-to-packed adapter，并把可接受的 ID 宽度、burst 与
  outstanding 限制写入测试计划；不能借 adapter 宣称 fabric 已无约束支持任意 AXI4 traffic。

## 使用方式

1. 不要复制 VIP 到本仓库。将其根目录写入本机环境变量或仿真工程 include 路径。
2. 从对应目录选择 harness 作为 DUT top；VIP 自己的 top/agent 负责 `clk`、`rst`、driver、monitor 和 scoreboard。
3. `filelist.f` 给出了项目 RTL 的最小编译集合。以 VIP 文档指定的 simulator 编译选项为准。
4. 首先运行 `scripts/run_dut_harness_compile.ps1`，它只编译本仓库 harness 和 DUT，证明接线无语法问题；
   再在 VIP 工程中加入 VIP package/filelist。

本目录的通过标准由外部 VIP 工程产生；没有新鲜 VIP 日志前，不把任何项目写成“VIP PASS”。
