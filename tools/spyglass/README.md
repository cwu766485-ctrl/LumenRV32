# SpyGlass CPU 静态检查入口

本目录提供 LumenRV32 CPU 面试边界的 SpyGlass project 和启动命令。执行前必须在 Rocky/WSL shell 中加载公司或学校提供的 SpyGlass 环境；本仓库不携带 SpyGlass、工艺库或许可证。

```bash
source /path/to/spyglass/setup.sh
cd /mnt/e/workspace/chip/cpu/lumen-rv32
tools/spyglass/run_cpu_static_checks.sh lint
tools/spyglass/run_cpu_static_checks.sh cdc
tools/spyglass/run_cpu_static_checks.sh rdc
```

若 `command -v spyglass` 为空，先运行你本地 EDA 环境的 setup 脚本；不要在 `dc_shell` 内执行 Bash 命令。

每轮结果存放于 `build/spyglass_cpu/`，该目录被 Git 忽略。只有 `ERROR` 为 0 且所有 waiver 可追溯时，才可在文档中标记对应检查通过。

当前范围是 `cpu_axi_debug_profile_top`。BSCAN USER2 的 TCK 与 `clk` 是异步时钟；CDC 约束与 waiver 应围绕 toggle handshake，而不是将所有跨域路径粗暴 false-path。
