# LumenRV32 Specification

## CPU

- ISA: RV32IM, little-endian, single issue, in-order.
- Pipeline: IF, ID, EX, MEM, WB.
- Data hazards: EX/MEM/WB forwarding and load-use interlock.
- Control hazards: EX-stage redirect/flush, BTB and 2-bit BHT prediction, frontend prefetch queue.
- Memory hierarchy: I-Cache and D-Cache; D-Cache is direct-mapped, write-through, and no-write-allocate.
- Performance observability: PMU counters for cycles, retired instructions, cache events, branch events, fetch/data wait, and store-queue events.

## Memory and control fabric

- CPU I-cache, CPU D-cache, and DMA initiate native requests through `native_to_axi4_master` adapters.
- ROM, RAM, external memory, and the AXI4-Lite control island are AXI4 slaves.
- DMA registers are mapped at `0x2000_5000`; other low-speed registers use the AXI-to-APB path.
- AXI limitation: one global outstanding transaction. There are no AXI IDs, multiple outstanding transactions, out-of-order responses, or write-data interleaving.

## Debug and implementation

- JTAG debug logic supports debug transport and CPU halt/reset integration.
- UART provides software-visible output during bare-metal smoke tests.
- `tools/asic/run_dc_cpu.sh` runs local, licensed 28 nm DC synthesis. The PDK and generated reports remain local and must not be committed.
- ZU15EG implementation scripts are available, but a changed commit must be rebuilt and revalidated before board claims are made.

## Non-goals

RV32F/D, superscalar execution, out-of-order execution, MMU, hardware cache coherence, AXI QoS, AXI ID/OoO routing, and ASIC signoff are outside this project scope.
