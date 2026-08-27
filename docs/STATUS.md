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
- `JTAG_DMI_CDC_TB_PASS`: four 40-bit DMI requests and responses across 58.8 MHz TCK and 100 MHz CPU clocks, with asynchronous reset release. The implementation record is [here](validation/jtag_dmi_cdc.md).
- CPU UVM smoke passed on both Vivado XSim and Linux VCS UVM-1.2 with zero UVM errors/fatals; the scoped test matrix is [here](validation/test_matrix.md).
- ZU15EG USER2 DMI board validation completed for read-only `DMSTATUS`, halt, abstract GPR read, and resume. This is a custom USER2/DMI transport, not full RISC-V Debug Spec coverage.

## Boundaries

- The AXI crossbar supports one global outstanding transaction only. AXI IDs, multiple outstanding transactions, OoO responses, and write-data interleaving are not implemented.
- The public repository does not include external reference accelerator content.
- Existing ZU15EG BRAM/UART and DDR4 smoke records are historical. The USER2 DMI board test is separately accepted; CPU/DDR execution must still be rebuilt and rerun after a relevant RTL change before being claimed as current.
- The DC flow is pre-layout. A matched min library, SRAM macro binding, CTS, physical parasitics, and signoff checks are outside the current result.
- No CDC static-analysis tool sign-off has been run. Dynamic TCK board evidence is limited to the USER2 DMI transaction sequence above; full debug-spec, system-bus access, and reset/flash operations remain outside scope.

## Next engineering work

1. Run the full ISA, AXI/APB, DMA, D-Cache, CoreMark, and FreeRTOS regressions from the current commit.
2. Add the active-TCK constraints to a board top, rebuild the CPU-focused image, and archive JTAG/UART evidence; then rebuild the CPU/DMA image and repeat DDR4 smoke.
3. Establish SRAM-aware full-core ASIC synthesis before making full-CPU PPA comparisons.
