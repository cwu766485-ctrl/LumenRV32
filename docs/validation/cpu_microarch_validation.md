# CPU Microarchitecture Validation

## Scope

This note consolidates the core-side validation history that still matters for
the current repository baseline:

- standard `IF / ID / EX / MEM / WB` 5-stage pipeline
- wait-state-aware shared `ROM / RAM` handshake closure
- `I-Cache` front-end line-fill correctness under slow memory
- practical `D-Cache` integration and performance impact

It replaces the earlier stage-by-stage notes that were useful during the
upgrade process but are no longer the best way to describe the current core.

## Current Core Shape

- ISA: `RV32IM`
- pipeline: standard 5-stage `IF / ID / EX / MEM / WB`
- front-end: `ifetch + I-Cache`
- data side: direct-mapped `D-Cache`
- current shared-memory contract:
  - one outstanding request per slave
  - request payload held stable while waiting
  - `ready_o` means response data is valid in the same cycle

## Signed Functional Closure

### FreeRTOS Timer0 / Context-switch Smoke

- FreeRTOS V10.3.1 simple blinky demo is built explicitly for `rv32im` and
  uses Timer0 as the 1 kHz scheduler tick source.
- Fresh XSim evidence on 2026-08-21: `TEST_PASS` at `776570 ns`, with
  `PMU interrupt = 34`. This covers startup, timer interrupt entry, FreeRTOS
  context save/restore, scheduling, and the queue sender/receiver handoff.
- Reproduction: `tools/run_freertos_tick_context_smoke.ps1`.
- Scope boundary: it is an XSim smoke, not a board-level RTOS signoff.

### 1. 5-Stage Baseline

- legacy ISA generated regression: `47/47 PASS`
- representative XSim SoC smoke:
  - `rv32ui-p-add`: PASS
  - `rv32ui-p-addi`: PASS
  - `rv32ui-p-lw`: PASS

The earlier apparent `rv32ui-p-addi` failure after the 5-stage conversion was a
testbench timing issue, not an architectural bug. The pass branch had already
been taken, but the bench checked the final register too early for the new
writeback latency.

### 2. Wait-State + I-Cache Closure

Historical root cause before the AXI migration:

- `ROM / RAM` asserted `ready_o` and changed `data_o` on the same cycle
- the former RIB path accepted the new `ready` pulse while still observing stale data
- `I-Cache` line fill could therefore build shifted lines under wait-state memory

The closure principle remains in the current RTL: response payload is stable at
the consuming handshake. The old RIB implementation has been removed; current
ROM/RAM traffic reaches the cache through `native_to_axi4_master`,
`axi4_crossbar` and `axi4_to_native_slave`.

The historical fix was completed in:

- `rtl/core/rib.v`
- `rtl/perips/rom.v`
- `rtl/perips/ram.v`

Representative signed slow-memory smoke with `RomWaitCycles=2` and
`RamWaitCycles=2`:

- `rv32ui-p-beq`: PASS
- `rv32ui-p-jal`: PASS
- `rv32ui-p-sw`: PASS
- `rv32ui-p-lw`: PASS
- `rv32ui-p-lb`: PASS

### 3. Current D-Cache Baseline

Current `D-Cache` is intentionally simple but real:

- direct-mapped
- `4-word` cache line
- write-through
- no-write-allocate
- cacheable on memory space only
- peripheral traffic bypasses

Current signed checks:

- legacy ISA generated regression: `47/47 PASS`
- `rv32ui-p-addi` with `wait=2`: PASS
- `rv32ui-p-lw` with `wait=2`: PASS
- wait-state CoreMark now completes instead of timing out

## Performance Snapshot

| Metric | Historical pre-5-stage best | 5-stage no D-Cache | Current 5-stage + D-Cache (`wait=0`) | Current 5-stage + D-Cache (`wait=2`) |
| --- | ---: | ---: | ---: | ---: |
| CoreMark/MHz | `2.3686` | `0.8817` | `0.9317` | `0.6784` |
| CoreMark ticks | `422198` | `1134214` | `1073337` | `1474033` |
| PMU cycle | `442742` | `1183092` | `1120639` | `1538911` |
| PMU inst | `301697` | `301695` | `301695` | `301695` |
| PMU hold | `109784` | `881396` | `818943` | `1237215` |

Current `D-Cache` delta against the signed 5-stage no-cache baseline:

| Metric | Without D-Cache | With D-Cache (`wait=0`) | Delta |
| --- | ---: | ---: | ---: |
| CoreMark/MHz | `0.8817` | `0.9317` | `+5.7%` |
| PMU cycle | `1183092` | `1120639` | `-5.3%` |
| PMU hold | `881396` | `818943` | `-7.1%` |
| Data bus req | `154981` | `45548` | `-70.6%` |
| Data bus wait | `79569` | `24244` | `-69.5%` |

## Historical Note

An earlier decode-side `load-use` stall experiment regressed this core badly and
was intentionally not kept as the long-term direction. The current repository
baseline follows the corrected zero-wait/shared-memory semantics instead of that
regressed branch.

## Current Boundary

- The core-side path is functionally signed with `I-Cache`, `D-Cache`, and
  slow-memory handshake closure.
- The cache policy is still deliberately small and conservative.
- DMA coherence is still not solved in hardware; cached DMA-heavy workloads
  remain a future refinement area.
