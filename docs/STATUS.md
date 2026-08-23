# 当前状态：公开 CPU/DMA 版

更新时间：2026-08-22。

## 已实现

- RV32IM 单发射五级流水 CPU：I/D Cache、BTB/2-bit BHT、prefetch queue、store queue、PMU、JTAG/debug。
- AXI4 数据面：CPU instruction/data、DMA 与 ROM/RAM/DDR/EXTMEM/control island 的互连。
- AXI4-Lite/APB 控制面：DMA 和 UART、Timer、GPIO、SPI、QSPI、I2C、PMU 等外设。
- AXI fabric：CPU I/D 和 DMA 可访问的单全局-outstanding crossbar；尚不支持 AXI ID、多 outstanding、ID-aware response routing、OoO 或 write-data interleaving，不能称为商业级完整 AXI fabric。
- 28 nm DC CPU profile 与 ZU15EG CPU-focused FPGA PPA 的脚本入口。
- `verify/vip_sanity/`：APB、AXI4、AXI4-Lite、UART、I2C、SPI 的独立 DUT harness。

## 已有验证证据

- `BRANCH_PREDICTOR_TB_PASS`
- `AXI4_CPU_RAM_PATH_PASS`
- `VIP_SANITY_DUT_COMPILE_PASS`（APB / AXI4 / AXI4-Lite / UART / I2C / SPI）
- ZU15EG BRAM/UART、DDR4 CPU/DMA smoke 有历史验收记录；本次公开版删除外部加速器后，需按当前 commit 重新实现并上板才可重新签收。

## 公开版明确不包含

- 外部参考加速器 RTL、软件、测试、工具和板测结论。
- 多核 cache coherence、ACE/CHI、完整 AXI write-data interleaving、通用 AI 推理运行时。
- ASIC post-layout signoff、IR/EM、DFT、UPF signoff 或真实 workload 功耗签收。

## 下一步

1. 复跑 CPU、AXI/APB、DMA、D-Cache、CoreMark 与 FreeRTOS 的新鲜回归。
2. 以当前 RTL 重新生成 ZU15EG CPU/DMA DDR4 镜像，完成冷启动稳定性和 ILA 证据归档。
3. 围绕 PMU 的真实瓶颈做 CPU PPA 实验：分支预测、fetch、store queue 或关键路径结构优化。
