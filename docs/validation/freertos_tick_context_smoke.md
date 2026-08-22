# FreeRTOS tick / context-switch smoke

## 目标

验证 RV32IM CPU 在当前 SoC 中可完成最小 FreeRTOS 运行链路：C 运行时初始化、
Timer0 tick、中断入口、任务上下文保存/恢复、调度，以及队列发送/接收。

## 构建约束

CPU 仅实现 `RV32IM`，不支持 `C`（compressed）扩展。因此必须由 Makefile 的
`RISCV_ARCH=rv32im` 传递 `-march=rv32im -mabi=ilp32`。不得以命令行 `CFLAGS=...`
覆盖 `common.mk`，否则 GCC 的默认目标可能生成 RVC 指令，CPU 会以 32-bit 步长误取指。

`SIMULATION=1` 会让 queue sender 的延时降为 20 ticks，并在 receiver 收到正确数据后
写入 TB 完成标志。

## 入口

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_freertos_tick_context_smoke.ps1
```

脚本先以 `SIMULATION=1` 重建，再在隔离 XSim 目录执行 1 ms 窗口。它要求：

- `TEST_PASS`；
- `PMU interrupt` 非零；
- 没有 timeout。

## 新鲜结果（2026-08-21）

| 项目 | 结果 |
| --- | --- |
| RV32IM 编译 | PASS，命令行含 `-march=rv32im -mabi=ilp32` |
| XSim queue demo | `TEST_PASS` |
| 仿真完成时间 | `776570 ns` |
| PMU interrupt | `34` |

该结果证明最小双任务队列 demo 的运行，不等同于 FreeRTOS 全量兼容性、实时性或板级验收。
后续若移植到板卡，还需独立验收 timer 时钟频率、UART 日志和中断线电平。
