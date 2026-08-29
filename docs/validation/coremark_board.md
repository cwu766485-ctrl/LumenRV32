# ZU15EG CoreMark 板级验收

## 目的与命名边界

本流程用于获得 LumenRV32 在 ZU15EG BRAM + UART profile 上的可复现 CoreMark/MHz 数据。它使用上游 CoreMark 源码的 `PERFORMANCE_RUN`，不定义 `SIMULATION_FAST_EXIT`，并要求程序自身通过 CRC/正确性检查和不少于十秒的计时检查。

通过本流程后可称为“基于 CoreMark 1.0 的板级结果”或“CoreMark/MHz 板级测量值”。除非按 EEMBC 的许可、提交和审核流程完成认证，不能称为“EEMBC certified score”。

## 固定配置

| 项目 | 配置 |
| --- | --- |
| FPGA | `xczu15eg-ffvb1156-2-i` |
| profile | `zu15eg_riscv_bram_uart_top`，BRAM + UART |
| 参考时钟 / CPU 时钟 | 200 MHz / 50 MHz（`CpuClockDiv=4`） |
| 串口 | 115200 8N1 |
| ROM | 8192 words，32 KiB |
| CoreMark iterations | 2000，预期时间超过 10 秒 |

`core_portme.c` 的 `CPU_FREQ_HZ=50000000` 与该固定 FPGA 配置对应。若改变 `CpuClockDiv`，必须同步改变软件频率定义和 UART 分频，并重新验收；不得将 50 MHz 的结果挪用于其他频率。

## 构建与板测

在 Windows PowerShell、仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_zu15eg_coremark.ps1 -Iterations 2000 -CpuClockDiv 4 -RomWords 8192 -Jobs 4
```

将生成的 `build/zu15eg_coremark/zu15eg_riscv_bram_uart_top.bit` 易失烧写到板卡。烧写前先打开串口采集，避免遗漏启动打印：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\capture_zu15eg_coremark.ps1 -Ports COM9,COM10,COM11 -CpuClockMHz 50 -TimeoutSeconds 480
```

按实际串口枚举情况缩小 `Ports`。原始 UART 文本存入 `build/zu15eg_coremark/uart_capture/`，属于生成物，不提交 Git。
ZU15EG 经 USB-JTAG 下载的时间可能超过三分钟，因此采集窗口必须覆盖下载时间、CoreMark 执行时间和少量枚举余量；`480` 秒是当前板测的安全值。

## PASS 条件与分数计算

UART 必须同时出现：

```text
Correct operation validated.
Iterations/Sec   : <score_per_second>
```

部分 CoreMark port 会将第二行打印为 `CoreMark 1.0 : <score_per_second>`；
它与 `Iterations/Sec` 表示相同的每秒 iteration 结果，采集脚本同时接受两种格式。

且不得出现：

```text
ERROR! Must execute for at least 10 secs
```

脚本输出 `ZU15EG_COREMARK_UART=PASS` 后，按下式记录分数：

```text
CoreMark/MHz = score_per_second / 50
```

验收记录还必须保留本次 bitstream、CoreMark binary 的 SHA-256、UART 原文、时钟配置和 Git commit。当前尚未取得上述板级 UART PASS，因此仓库中没有可对外声明的正式 CoreMark/MHz 数字。

## 与 RTL fast window 的区别

2026-08-27 的 XSim 短窗口使用 `SIMULATION_FAST_EXIT`，得到 `PMU inst / cycle` 约 `0.705` 的 PMU 特征值。它用于比较同一 RTL 的局部改动和定位停顿来源，不是 CoreMark 规范要求的正式计时，也不用于计算或宣传 CoreMark/MHz。

## 2026-08-28 构建记录

正式 release image 已生成，尚未完成板级 UART 验收：

| 项目 | 值 |
| --- | --- |
| CoreMark binary SHA-256 | `518379152677955BDF17B1BEDA4936E973EE3DE3B6BCF5DFFAD85CCAF53F7556` |
| bitstream SHA-256 | `A3BA1F39EF2C82F70457F3B47B369C028BB909D3D604F8BBC28590FB7EE47554` |
| FPGA post-route | WNS `+8.941 ns`，TNS `0`，WHS `+0.005 ns`，THS `0` |
| FPGA resources | 22,667 CLB LUT，16,615 registers，16 BRAM tiles，4 DSPs |
| DRC | 0 errors；DSP pipeline 建议为 warnings，不阻断本次 50 MHz 测试 |

本机于同日的 JTAG 探测未发现硬件 target，因此此表只证明 image build 与 implementation 完成；不代表板上 CoreMark 通过。

## 2026-08-28 板级验收结果

板卡重新枚举后，`xczu15_0` 经 USB-JTAG 易失配置；UART 位于 FTDI `COM10`。
原始 UART 输出包含 `Correct operation validated.`，没有最短执行时间错误，并报告：

```text
Total ticks      : 853262752
Total time (secs): 17
Iterations/Sec   : 117
Iterations       : 2000
```

因此本固定 50 MHz BRAM + UART profile 的结果为：

```text
CoreMark/MHz = 117 / 50 = 2.34
```

这是可复现的板级 CoreMark 1.0 performance-run 结果，不是 EEMBC certified score。
