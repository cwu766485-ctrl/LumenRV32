# Resume Notes

## Suggested project title

**LumenRV32 — RV32IM CPU Microarchitecture and SoC Memory Path**

## Suggested bullets

- Designed and implemented synthesizable RTL for a single-issue five-stage RV32IM pipeline (IF/ID/EX/MEM/WB), including EX/MEM/WB forwarding, load-use interlock, branch redirect/flush, I/D Cache, prefetch queue, and BTB/2-bit BHT prediction.
- Built the CPU memory subsystem as I/D Cache → native-to-AXI4 adapters → AXI4 fabric, separating core/cache microarchitecture from downstream protocol logic while retaining AXI4-Lite/APB control paths.
- Added PMU counters for cycle, instruction, cache, branch, fetch, data-wait, and store-queue events; integrated JTAG debug for execution-state observability and board bring-up.
- Refactored the EX-to-JALR forwarding feedback with a one-cycle interlock and MEM/WB late forwarding; directed RTL and bare-metal SoC tests passed, and a 28 nm SS / 5 ns DC timing-cone experiment removed the original 80-level, 4.90 ns feedback path.

## Claim boundaries

The JALR result is a focused pre-layout timing-cone experiment, not a full-core Fmax, physical-signoff, or silicon claim. The public AXI fabric permits one global outstanding transaction only. Use current-commit evidence for any FPGA, CoreMark, or board metric.
