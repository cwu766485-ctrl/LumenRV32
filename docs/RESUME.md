# heterogeneous_soc 项目介绍（公开 CPU/DMA 版）

## 项目定位

设计并验证一个以 RV32IM 单发射五级流水 CPU 为核心的 SoC。重点是把 CPU microarchitecture、存储层次、AXI/APB 互连、DMA、调试与性能观测做成可综合、可回归、可上板的工程闭环，而不是只实现单个指令级 CPU。

## 核心设计

### CPU microarchitecture

- Verilog 实现 RV32IM 五级顺序流水：IF、ID、EX、MEM、WB。
- 实现 EX/MEM/WB forwarding、load-use hazard stall、flush/redirect，避免数据与控制冒险破坏提交顺序。
- I-Cache、D-Cache、prefetch queue 和 store queue 用于缓解外部存储延迟。
- 16/32-entry BTB 与 2-bit BHT 分支预测；通过 PMU 统计预测命中、redirect、fetch wait 和 cache miss，支持以数据驱动的性能优化。

### SoC / interconnect

- 将 CPU instruction/data path 和 DMA 封装为 native-to-AXI4 master，统一接入 AXI4 crossbar。
- 构建 AXI4-Lite control island 与 AXI-to-APB 路径，接入 DMA、UART、Timer、GPIO、SPI、QSPI、I2C、PMU。
- 对 fabric 的 multi-outstanding、ID routing、cross-ID read OoO 保持受限实现与清晰边界：CPU/DMA 仍只使用 local ID 0，不宣称商业级互连。
- 定义 CPU/DMA 非一致性共享内存的软件 cache maintenance/ownership 边界。

### Debug、验证与实现

- JTAG debug module、UART 观测和 PMU 计数器用于定位 CPU 运行、总线与存储瓶颈。
- SystemVerilog/Verilog 专项 TB 覆盖 branch predictor、D-Cache、AXI RAM path、AXI/APB、DMA 和外设。
- 为 APB、AXI4、AXI4-Lite、UART、I2C、SPI 建立独立 DUT harness，便于接入商用或自研 VIP。
- 完成 ZU15EG BRAM/UART、CPU/DMA DDR4 bring-up 脚本；以 ILA、mailbox、冷启动和恢复校验构建板测证据。
- 建立 28 nm DC CPU profile：标准单元/SRAM macro 约束、setup/hold 报告、面积与 vectorless power estimate；明确 pre-layout 与 signoff 的边界。

## 简历表述示例

> 设计并验证 RV32IM 单发射五级流水 SoC：实现 I/D Cache、BTB/BHT 分支预测、PMU、JTAG/debug、AXI4/AXI4-Lite/APB 互连与 DMA；构建模块级 TB/VIP harness、ZU15EG CPU/DMA DDR4 bring-up 及 28 nm DC PPA/STA 入口，形成 RTL—仿真—FPGA—综合的可复现验证闭环。

## 面试时应明确的边界

- 不支持 RV32F/D、乱序执行、superscalar、MMU 或多核硬件一致性。
- AXI 不是完整商业 fabric：写数据 interleaving 未实现，CPU/DMA adapter 未暴露多 local ID。
- 28 nm 结果为授权库下的 pre-layout 综合/STA 基线，不是 P&R 或 silicon signoff。
- 本公开版不包含任何外部参考加速器 RTL 或其验证结论。
