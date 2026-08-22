# 28 nm PDK 与 Design Compiler 本地使用指南

## 目的与安全边界

本项目仅通过本机环境变量引用受限 28 nm standard-cell 与 SRAM macro timing library，
用于 CPU 或 CPU-focused profile 的综合与 pre-layout STA。任何 PDK、`.db/.lib`、LEF、
模型卡、许可证、实际目录路径和生成数据库均不得进入 Git 或公开仓库。

本指南不替代 PDK 发布说明或签核流程；在没有匹配的 min/hold corner、物理实现、CTS、
IR/EM、DRC/LVS 和项目授权检查前，DC 结果不能称为 ASIC signoff。

## 本机准备

在 Linux Bash 中设置本机变量。以下值是占位符，必须替换为自己获准使用的库文件；不要
将实际值保存到仓库或截图中。

```bash
export ASIC28_MAX_LIB='<28nm setup/max-corner standard-cell .db>'
export ASIC28_MIN_LIB='<28nm hold/min-corner standard-cell .db>'
export ASIC28_SRAM_MAX_LIB='<matching SRAM setup/max-corner .db>'
export ASIC28_SRAM_MIN_LIB='<matching SRAM hold/min-corner .db>'
export ASIC28_CLK_NS=5.000
```

同一轮 run 中 standard-cell 与 SRAM macro 必须来自兼容的发布版本，且 PVT/电压/温度
定义一致。只提供 `MAX_LIB` 时只能报告 setup/area，不得签收 hold。

## 运行 CPU-only flow

在仓库根目录、普通 Bash prompt 执行：

```bash
bash tools/asic/run_dc_cpu.sh
```

该脚本自行启动 `dc_shell` 并生成 `build/asic28_cpu/` 下的 QoR、area、setup、hold 和
constraints 报告。不要在 `dc_shell>` 内输入 Bash 的 `export` 或 `bash` 命令。

CPU/AXI/PMU/JTAG focused profile 使用：

```bash
bash tools/asic/run_dc_cpu_profile.sh
```

## 结果解读与提交规则

- 先检查 `check_design`、library link、macro binding 与 unconstrained paths。
- setup 与 hold 均无违例才可称“pre-layout timing closed”；这仍不等同 physical/signoff。
- CPU cache 若未绑定 SRAM macro，其面积和时序不具有 ASIC macro 实现代表性。
- 只提交脚本、约束模板和匿名化报告摘要；`build/`、工具数据库和库路径均保持忽略。

本项目当前已知的 28 nm 结果、PVT 假设与 hold 边界见
[`validation/dc_28nm_cpu_flow.md`](validation/dc_28nm_cpu_flow.md)。
