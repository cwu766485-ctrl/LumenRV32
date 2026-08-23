# LumenRV32

这是一个可综合、可验证的单核 RISC-V SoC 工程。公开版以 `RV32IM` 五级顺序流水 CPU 为中心，包含 I-Cache、D-Cache、BTB/2-bit BHT、prefetch queue、store queue、PMU、JTAG/debug、AXI4/AXI4-Lite/APB 互连、DMA 与 UART/I2C/SPI/QSPI/GPIO/Timer 等外设。

当前公开分支：`main`。

## 架构

```text
RV32IM CPU I/D --- AXI4 adapters ---+
DMA AXI4 master ---------------------+--> AXI4 crossbar
                                           |--> ROM / RAM / DDR4 / EXTMEM
                                           |--> AXI4-Lite control island
                                                  |--> DMA registers
                                                  |--> AXI-to-APB peripherals
```

- CPU：RV32IM、单发射五级流水，带旁路、load-use stall、分支预测、I/D Cache 与 PMU。
- AXI：CPU I/D 与 DMA 通过 native-to-AXI4 adapter 接入 crossbar；当前 fabric 只有一个全局 outstanding transaction，不支持 AXI ID、多 outstanding、乱序返回或 write-data interleaving。
- 控制面：`0x2000_5000` 是 DMA AXI4-Lite；其余低速寄存器经 AXI-to-APB 到 UART、Timer、GPIO、SPI、QSPI、I2C、PMU。
- 板级：ZU15EG 的 BRAM/UART 和 DDR4 CPU/DMA smoke 有历史验收记录；任何 RTL 修改后必须重新构建并复验，不可复用旧结论。

## 公开版边界

本公开版不包含外部参考加速器 RTL、其 wrapper、软件用例、工具或验证结果。`reference_project/` 仅为本地忽略的参考目录，不会进入 Git。

本仓库保留 TinyRISCV 上游 Apache-2.0 文件的版权头、`LICENSE` 和 `NOTICE`；不要删除这些第三方归属。

## 常用入口

```powershell
git status --short --branch
powershell -ExecutionPolicy Bypass -File .\tools\run_axi4_cpu_ram_path_tb.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_branch_predictor_tb.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_dma_full_regression.ps1
```

详细规格和当前验证状态见 [docs/STATUS.md](docs/STATUS.md)、[docs/SPEC.md](docs/SPEC.md) 与 [docs/modules/README.md](docs/modules/README.md)。
