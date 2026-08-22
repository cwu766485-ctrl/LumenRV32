# heterogeneous_soc 公开版规格

## 1. 范围

公开版是 RV32IM 单核 CPU、DMA、存储子系统和低速外设组成的可综合 SoC。它不包含外部参考加速器 RTL 或相关软件、模型和验证工件。

## 2. CPU

- RV32IM、顺序、单发射、五级流水：IF / ID / EX / MEM / WB。
- I-Cache、D-Cache、EX/MEM/WB forwarding、load-use hazard stall。
- 16/32-entry BTB + 2-bit BHT 配置、prefetch queue、2-entry store queue。
- PMU 统计 cycle、instruction、cache miss、branch、fetch/data wait、store queue 等事件。
- 不含 RV32F/D、乱序执行、superscalar、MMU 或硬件 cache coherence。

## 3. 互连与存储

- CPU instruction/data 与 DMA 经 native-to-AXI4 adapter 接入 AXI4 crossbar。
- slave：ROM、RAM、EXTMEM/DDR bridge、AXI4-Lite control island。
- crossbar RTL 具备受限 multi-outstanding、ID response routing 和 cross-ID read OoO；CPU/DMA adapter 当前只发 local ID 0，write data 不支持 AXI3 式 WID interleaving。
- CPU 与 DMA 共享数据由软件完成 cache maintenance 与所有权管理。

## 4. 控制与外设

| 地址 | 接口 | 功能 |
| --- | --- | --- |
| `0x2000_5000` | AXI4-Lite | DMA registers |
| 其余控制 aperture | AXI-to-APB | UART、Timer、GPIO、SPI、QSPI、I2C、PMU 等 |

## 5. 验证与实现

- RTL 专项：branch predictor、CPU AXI RAM path、DMA、D-Cache、AXI/APB、外设。
- 独立 VIP harness：`verify/vip_sanity/`。
- FPGA：ZU15EG BRAM/UART 与 CPU/DMA DDR4 smoke 入口。
- ASIC：`tools/asic/run_dc_cpu.sh`，必须由本机授权 28 nm `.db` 和 PVT/SDC 驱动；报告为 pre-layout estimate，不能冒充 signoff。

## 6. 已知边界

外部参考加速器已从公开版移除。历史板测或文档中涉及该加速器的结论不适用于本公开版本；重新上板时仅可验收 CPU/DMA 路径。
