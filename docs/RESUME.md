# Resume Notes

## Suggested project title

**LumenRV32 — RV32IM CPU Microarchitecture and SoC Memory Path**

## Suggested bullets

- Designed and implemented synthesizable RTL for a single-issue five-stage RV32IM pipeline (IF/ID/EX/MEM/WB), including EX/MEM/WB forwarding, load-use interlock, branch redirect/flush, I/D Cache, prefetch queue, and BTB/2-bit BHT prediction.
- Built the CPU memory subsystem as I/D Cache → native-to-AXI4 adapters → AXI4 fabric, separating core/cache microarchitecture from downstream protocol logic while retaining AXI4-Lite/APB control paths.
- Added PMU counters for cycle, instruction, cache, branch, fetch, data-wait, and store-queue events; integrated JTAG debug with a bidirectional four-phase DMI CDC handshake and per-domain reset release.
- Refactored the EX-to-JALR forwarding feedback with a one-cycle interlock and MEM/WB late forwarding; directed RTL and bare-metal SoC tests passed, and a 28 nm SS / 5 ns DC timing-cone experiment removed the original 80-level, 4.90 ns feedback path.
- Implemented the CPU-focused XCZU15EG profile at 100 MHz post-route: WNS +1.163 ns, TNS 0, WHS +0.012 ns, THS 0; the build used 19,183 LUT, 15,324 registers, 16 BRAM tiles, and 4 DSPs.

## Claim boundaries

The JALR result is a focused pre-layout timing-cone experiment, not a full-core Fmax, physical-signoff, or silicon claim. The FPGA number predates the JTAG CDC hardening and is not board execution evidence. The DMI CDC has directed asynchronous-clock simulation coverage, not CDC-tool sign-off or board validation. The public AXI fabric permits one global outstanding transaction only. Use current-commit evidence for any CoreMark or board metric.
