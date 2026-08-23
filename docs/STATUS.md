# Project Status

## Implemented RTL

- RV32IM single-issue five-stage CPU with I/D Cache, prefetch queue, store queue, BTB/2-bit BHT, PMU, and JTAG debug blocks.
- CPU instruction/data and DMA native request paths connected to AXI4 memory slaves and the AXI4-Lite/APB control plane.
- UART, timer, GPIO, SPI, QSPI, I2C, and PMU register blocks on the low-speed control path.
- Standalone DUT harnesses prepared for APB, AXI4, AXI4-Lite, UART, I2C, and SPI VIP integration.

## Fresh evidence on the current public source

- `ID_JALR_FORWARDING_TB_PASS`.
- `jalr_forwarding` bare-metal SoC test: `TEST_PASS`, 675 cycles, 161 instructions.
- `simple` bare-metal SoC smoke: `TEST_PASS`, 3250 cycles, 2010 instructions.
- 28 nm SS, 5 ns JALR timing-cone A/B documented in [validation/jalr_timing_optimization.md](validation/jalr_timing_optimization.md).

## Boundaries

- The AXI crossbar supports one global outstanding transaction only. AXI IDs, multiple outstanding transactions, OoO responses, and write-data interleaving are not implemented.
- The public repository does not include external reference accelerator content.
- Existing ZU15EG BRAM/UART and DDR4 smoke records are historical. The current public commit needs a fresh FPGA build and board run before they can be accepted again.
- The DC flow is pre-layout. A matched min library, SRAM macro binding, CTS, physical parasitics, and signoff checks are outside the current result.

## Next engineering work

1. Run the full ISA, AXI/APB, DMA, D-Cache, CoreMark, and FreeRTOS regressions from the current commit.
2. Rebuild the CPU/DMA ZU15EG image and repeat board smoke with archived UART/ILA evidence.
3. Establish SRAM-aware full-core ASIC synthesis before making full-CPU PPA comparisons.
