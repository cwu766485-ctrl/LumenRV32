# AGENTS.md

## 项目目标

本仓库实现并验证一个以 `RV32IM` 单核五级流水 CPU、DMA 和标准互连/外设为核心的 SoC。工作目标是形成可复现、可验证、可解释的数字 IC / FPGA 工程，而不是仅堆叠 RTL 模块。

当前主线为 `feature/zu15eg-soc`。提交前先确认分支和工作区；不要覆盖或回退已有用户改动。

## 技术栈

- RTL：Verilog HDL；测试平台：SystemVerilog。
- 软件：RISC-V bare-metal C、少量汇编；参考/scoreboard：C、Python。
- 工具脚本：Vivado Tcl、PowerShell、Python；工具：Vivado/XSim、RISC-V GCC、Git。
- 协议：RV32IM、AXI4、AXI4-Lite、APB；DDR/MIG 板级路径仅通过 vendor IP/已签收 wrapper 接入。

## 当前架构事实

- CPU 为顺序、单发射、五级流水，带 I-Cache、D-Cache、BTB/2-bit BHT、prefetch queue、2-entry store queue 和 PMU。
- 主数据面是 AXI4：CPU I/D、DMA 为 master；ROM、RAM、DDR/EXTMEM、AXI control island 为 slave。
- 控制面：`0x2000_5000` 为 DMA AXI4-Lite；其余低速寄存器经 AXI-to-APB 到 UART、Timer、GPIO、SPI、QSPI、I2C、PMU 等。
- 当前 crossbar 只有单个全局 outstanding transaction，不支持 AXI ID、多 outstanding 或乱序返回。不得称为商业级高并发 AXI fabric。
- 公开版不包含外部参考加速器 RTL、模型、软件或验证工件；不得将历史记录写为当前公开能力。

## 代码与验证规则

- RTL 必须可综合；避免组合环、隐式 latch、多驱动和未说明的 CDC。
- 更改寄存器、内存映射、descriptor 或 artifact 格式时，同步修改 RTL、C 头文件/用例、Python 工具、scoreboard 和文档。
- 先跑最小专项 TB，再跑相关回归。XSim 共享工作目录时串行执行，避免并发污染。
- 只能依据新鲜日志写 PASS；超时、未运行和历史结果必须分别标注。
- 不以削弱 test/golden 的方式掩盖问题。生成的 ELF/BIN/dump、Vivado `build/`、波形、日志不得提交。
- 不提交 license、密码、token、私钥、服务器地址或受限硬件资料。远程访问使用本机 SSH config/密钥或密码管理器，仓库只记录别名。

## 当前阻塞与下一步

1. 串行重跑 RV32 ISA、AXI/APB、DMA、D-Cache 与 CoreMark，冻结命令、SHA-256、PMU、结果和 commit。
2. 冻结后再启动 ZU15EG 板级移植；先完成 CPU/DMA 的时钟、复位、存储和最小板级 smoke。
3. 多核前先升级 AXI fabric 的 ID/multi-outstanding 验证。双核先采用软件管理 cache，再研究受限 coherent window；不得把未实现的机制称为 ACE/CHI。
4. 多核前先升级 AXI fabric 的 ID/multi-outstanding 验证。双核先采用软件管理 cache，再研究受限 coherent window；不得把未实现的机制称为 ACE/CHI。

## 常用入口

```powershell
git status --short --branch
powershell -ExecutionPolicy Bypass -File .\tools\run_sw_example.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_dma_full_regression.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_dma_full_regression.ps1
```

使用脚本参数前先查看对应脚本的 `param` 块。不要凭记忆拼接路径或假设 snapshot 名称。

## 工作流与记录

1. 先读相关 RTL、TB、软件、脚本和文档，说明本次问题与边界。
2. 做最小可验证改动，保留可回退路径。
3. 记录实际命令、日志、PASS/FAIL/未运行与已知限制。
4. 每次涉及 tracked 文件的实质修改，按本机时间更新 `docs/update_log.md`；复杂功能同步更新对应 `docs/modules/` 或 `docs/validation/` 页面。
5. 提交前执行 `git diff --check`，只 stage 源码、测试、工具和文档。

交接报告固定包含：目标、改动、验证、结果、边界、下一步。文档和报告使用中文；模块名、信号名、命令及标准术语保持英文。
