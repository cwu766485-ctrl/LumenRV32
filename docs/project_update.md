# 项目阶段摘要

## 当前公开主线

项目已收敛为 CPU/DMA SoC：RV32IM 五级流水、I/D Cache、branch predictor、PMU、JTAG/debug、AXI4/AXI4-Lite/APB、DMA 与低速外设。代码和说明均以 `docs/STATUS.md`、`docs/SPEC.md` 为准。

## 已完成的工程闭环

- CPU pipeline/cache/branch predictor 的专项仿真与 PMU 可观测性。
- AXI4 control island、AXI-to-APB、DMA、外设的模块级验证入口。
- ZU15EG BRAM/UART 与 CPU/DMA DDR4 bring-up 脚本；旧板测须与当前 RTL 版本分开记录。
- ZU15EG FPGA CPU-focused profile 与 28 nm DC CPU-only profile。
- APB、AXI4、AXI4-Lite、UART、I2C、SPI 的 VIP 接入 harness。

## 公开版收敛说明

外部参考加速器因为没有可验证的再分发许可证，已从公开源树移除。相关实现和工件不会作为本项目公开功能、验证结果或简历能力描述。

## 后续路线

1. 重签 CPU/DMA 回归与 ZU15EG CPU/DMA smoke。
2. 用 PMU 数据驱动 CPU 性能优化，并以 XSim、FPGA、DC 报告交叉验证。
3. 继续推进 AXI 受限并发能力的验证，而非将未验证能力写为产品级协议支持。
