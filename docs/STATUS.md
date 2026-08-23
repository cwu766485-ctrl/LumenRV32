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
- ZU15EG CPU-focused profile at 100 MHz: post-route WNS `+1.163 ns`, TNS `0`, WHS `+0.012 ns`, THS `0`; `19,183` LUT, `15,324` registers, `16` BRAM tiles, and `4` DSPs. The implementation record is [here](validation/zu15eg_cpu_profile_100mhz.md).

## Boundaries

- The AXI crossbar supports one global outstanding transaction only. AXI IDs, multiple outstanding transactions, OoO responses, and write-data interleaving are not implemented.
- The public repository does not include external reference accelerator content.
- Existing ZU15EG BRAM/UART and DDR4 smoke records are historical. A fresh CPU-focused FPGA build now exists, but the current public commit still needs a board run before board execution can be accepted.
- The DC flow is pre-layout. A matched min library, SRAM macro binding, CTS, physical parasitics, and signoff checks are outside the current result.

## Next engineering work

1. Run the full ISA, AXI/APB, DMA, D-Cache, CoreMark, and FreeRTOS regressions from the current commit.
2. Run the new CPU-focused ZU15EG bitstream on the board and archive JTAG/UART evidence; then rebuild the CPU/DMA image and repeat DDR4 smoke.
3. Establish SRAM-aware full-core ASIC synthesis before making full-CPU PPA comparisons.
