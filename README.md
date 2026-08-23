# LumenRV32

LumenRV32 is a synthesizable, single-core RISC-V SoC project centred on a **single-issue, five-stage RV32IM CPU**. It is intended as a compact engineering project: the design includes microarchitecture, an AXI memory path, debug and performance observability, focused verification, FPGA implementation scripts, and a reproducible ASIC synthesis entry point.

The public repository contains the CPU/DMA edition only. It deliberately excludes external reference accelerator RTL, models, software, and verification collateral.

## Highlights

- Five-stage RV32IM pipeline: IF / ID / EX / MEM / WB.
- EX/MEM/WB forwarding, load-use interlock, branch redirect and flush.
- I-Cache, D-Cache, prefetch queue, two-entry store queue, BTB and 2-bit BHT.
- CPU instruction/data and DMA paths connected through native-to-AXI4 adapters.
- AXI4-Lite control island and AXI-to-APB path for DMA, UART, timer, GPIO, SPI, QSPI, I2C, and PMU registers.
- PMU event counters and JTAG debug RTL with a bidirectional asynchronous DMI handshake.
- Focused SystemVerilog/Verilog testbenches and source-only bare-metal examples.

## Architecture

```text
                  +-----------------------------+
                  |      RV32IM CPU core         |
                  | IF ID EX MEM WB, I/D Cache   |
                  +-----------------------------+
                       | instruction / data
                native-to-AXI4 adapters
                       |
DMA AXI4 master -------+------ AXI4 crossbar ----- ROM / RAM / external memory
                       |
                       +------ AXI4-Lite control island
                                    |
                               AXI-to-APB
                                    |
                    UART / timer / GPIO / SPI / QSPI / I2C / PMU
```

## Important scope limits

- The CPU is RV32IM. It is not RV32F/D, superscalar, out-of-order, MMU-enabled, or cache-coherent multicore.
- The current AXI crossbar permits **one global outstanding transaction**. It does not implement AXI ID routing, multi-outstanding traffic, out-of-order responses, or write-data interleaving.
- Board bring-up records are historical evidence for earlier accepted images. Any RTL change requires a new build and board validation; historical results are not automatically inherited.
- ASIC results are pre-layout estimates. They are not P&R, CTS, parasitic, hold-signoff, or silicon claims.

## Getting started

```powershell
git status --short --branch
powershell -ExecutionPolicy Bypass -File .\tools\run_branch_predictor_tb.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_id_jalr_forwarding_tb.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_sw_example.ps1 -ExampleName simple
```

See [docs/README.md](docs/README.md) for architecture, verification, implementation, and resume-facing notes.

The current CPU-focused ZU15EG profile has a fresh 100 MHz post-route result; see
[the implementation record](docs/validation/zu15eg_cpu_profile_100mhz.md). Board execution is a
separate acceptance step.

## Attribution

This repository retains required upstream Apache-2.0 notices in `LICENSE` and `NOTICE`. Do not remove third-party attribution from inherited files.
