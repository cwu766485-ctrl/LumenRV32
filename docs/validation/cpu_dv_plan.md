# CPU 面试边界 DV 计划

## 目标与边界

本计划覆盖 LumenRV32 的面试级 CPU 集成边界：五级 `RV32IM` 流水线、I/D Cache 到 AXI 数据通路、PMU 相关可观测性，以及 USER2 自定义 JTAG/DMI 调试链路。它不是完整 ARM 或 RISC-V Debug Spec 的 sign-off 计划。

本轮追求的是可复现的定向验证、可检查的协议属性和可扩展的回归入口；覆盖率收敛及第三方工具 sign-off 必须以新鲜报告为准。

## 验证矩阵

| 主题 | 主要测试/检查 | 关键检查点 | 状态 |
| --- | --- | --- | --- |
| JTAG DMI CDC | `jtag_dmi_cdc_tb` | 40-bit payload 完整性、每请求恰好一次递交/响应、req/ack 空闲返回 | 已有专项 TB |
| USER2 DMI transport | `jtag_user2_transport_tb` | DMI 请求、保持式 response、连续事务 | 已有专项 TB |
| JALR 旁路优化 | `id_jalr_forwarding_tb` | JALR 只取 MEM/WB late forwarding；普通 ALU 保留 EX bypass | 已有专项 TB |
| 分支预测 | `branch_predictor_tb` | BTB/BHT 更新与预测命中/失败路径 | 已有专项 TB |
| D-Cache store path | `dcache_store_path_tb` | store queue、cache/memory 可见性 | 已有专项 TB |
| CPU AXI memory path | `axi4_cpu_ram_path_tb` | I/D native-to-AXI、读写握手、backpressure | 已有专项 TB |
| ISA 架构正确性 | `run_isa_regression.ps1` | RV32UI 指令程序最终 signature | 依赖 RISC-V GCC/二进制工件 |

## JTAG CDC checker 与覆盖点

`jtag_dmi_cdc_tb` 已作为双时钟 data-integrity scoreboard：CPU 域检查请求顺序和 payload，TCK 域检查 response 顺序和 payload，并检查双向 channel 回到 idle。每次 CDC 修改都应至少跑该 TB 及 USER2 transport TB。

后续 functional coverage 的最小 bins：

- DMI op：NOP、read、write；
- debug 状态：running、halted、resume；
- response：success、busy、error；
- CDC：TCK 快于/慢于 CPU、随机 release phase、连续事务、back-to-back response；
- reset：TCK 域先稳定、CPU 域先稳定、两域同时稳定。

未引入完整 class/UVM agent 前，采用可参数化 SV TB + scoreboard + SVA 的轻量路径；接口稳定后可以将 driver、monitor、scoreboard 包装为 UVM agent。

## Pipeline 定向测试与属性

每次修改 ID/EX、旁路、stall 或 redirect，至少覆盖：

- EX/MEM/WB forwarding 优先级；
- `load-use` interlock 的单 bubble；
- branch taken/not-taken redirect 与 flush；
- JAL/JALR target、JALR 的 EX 相关 interlock；
- I/D Cache miss 与 AXI ready/valid backpressure。

建议属性：x0 恒为 0；无效流水级不产生 reg/memory side effect；同一 DMI request 不会执行两次；未完成 response 不可被覆盖。属性结果应写入回归摘要。

## 回归与签收规则

入口：`tools/run_cpu_interview_regression.ps1`。XSim 使用共享工作目录，脚本严格串行执行。任何子测试非零退出或缺少 PASS token 都算失败。

ISA 工件缺失、SpyGlass 未加载、coverage 未采集必须显示为 `NOT_RUN` 或 `BLOCKED`，不可替换为历史 PASS。

## 已知边界

- USER2 是自定义 DMI transport，不是完整 RISC-V Debug Spec。
- 本计划尚未做完整随机指令发生器、差分 ISS 或 coverage closure。
- SpyGlass CDC/RDC/Lint 的正式结果取决于本机已授权的 SpyGlass 环境与库/约束配置。
