# Resume Notes

## Suggested project title

**LumenRV32 — RV32IM CPU Microarchitecture, Verification, and PPA Optimization**

## Resume-ready bullets

- Designed and implemented synthesizable RTL for a single-issue five-stage RV32IM pipeline (IF/ID/EX/MEM/WB), with EX/MEM/WB forwarding, load-use interlock, branch redirect/flush, I/D Cache, prefetch queue, BTB/2-bit BHT, store queue, and PMU event counters.
- Integrated the CPU memory subsystem as I/D Cache → native-to-AXI4 adapters → AXI4 fabric, separating pipeline/cache microarchitecture from AXI4-Lite/APB control logic and peripheral register paths.
- Built a reusable SystemVerilog UVM environment around the CPU native-memory boundary (agent, sequence/driver, monitor, scoreboard, coverage, SVA, and regression scripts); XSim and VCS passed directed smoke and pipeline-hazard tests covering forwarding, load-use interlock, and JAL/JALR redirect with 0 UVM errors/fatals.
- Implemented a custom ZU15EG USER2 JTAG/DMI transport with a bidirectional four-phase CDC handshake and reset synchronization; closed 100 MHz post-route timing (WNS +1.527 ns, TNS 0, WHS +0.015 ns; 20.6K LUT / 16.0K FF / 16 BRAM / 4 DSP) and board-tested DMSTATUS read, halt, abstract GPR read, and resume over the configuration cable.
- Resolved an EX-to-JALR timing bottleneck using a one-cycle interlock and MEM/WB late forwarding; directed RTL/bare-metal tests passed, while a 28 nm pre-layout Design Compiler timing-cone A/B at the same 5 ns constraint removed an 80-level, 4.90 ns feedback path and replaced it with a 0.09 ns registered path (+4.77 ns setup slack).

## How to tailor this for the current DE/DV role

For the current CPU DE/DV opening, use all five bullets in this order. Do not claim ARM ownership: this is a RISC-V project that demonstrates transferable CPU-subsystem design and verification skills.

## Claim boundaries

- The UVM work is a directed, reusable CPU verification foundation. It is not random instruction generation, ISS/DPI-C differential verification, coverage closure, or UVM sign-off.
- The USER2 path is a custom DMI transport and board-tested debug sequence, not a complete RISC-V Debug Specification implementation. Static CDC/RDC sign-off is not complete.
- The 28 nm result is a pre-layout, setup-only timing-cone experiment. It is not full-core PPA, APR/CTS, extracted-parasitic STA, hold sign-off, or silicon evidence.
- The 100 MHz FPGA number is a CPU-focused profile, not full-SoC DDR4 performance. The public AXI fabric supports one global outstanding transaction and does not provide AXI ID routing, multi-outstanding traffic, or out-of-order responses.

## Interview preparation anchors

Be prepared to explain the following concrete files and flows:

- Pipeline and hazards: `rtl/core/riscv_cpu_core.v`, `rtl/core/id.v`, `rtl/core/ctrl.v`, `rtl/core/ex.v`.
- Cache-to-AXI boundary: `rtl/core/icache.v`, `rtl/core/dcache.v`, and the native-to-AXI adapters under `rtl/interconnect/`.
- JTAG CDC: `rtl/debug/jtag_dm.v`, `rtl/debug/jtag_user2_dmi_transport.v`, and `docs/validation/jtag_dmi_cdc.md`.
- UVM evidence: `verify/uvm_cpu/`, `tools/run_cpu_uvm_smoke.ps1`, and `tools/run_cpu_interview_regression.ps1`.
- Timing story: `docs/validation/jalr_timing_optimization.md` and the DC scripts under `tools/asic/`.
