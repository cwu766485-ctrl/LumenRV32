# CoreMark Performance Record

## Purpose

This document records the CoreMark history of this repository in one place:

- what the original/high-score baseline looked like
- what the current SoC baseline measures today
- why the current score is lower
- what must be optimized if the CPU core should again compete on pure CoreMark

The important distinction is that the project has shifted from a small teaching
CPU baseline into an engineering-oriented SoC. CoreMark is still useful, but it
now measures the cost of the full fetch/data/cache/interconnect path, not only
the arithmetic pipeline.

## Historical Baseline

The best known pre-5-stage/high-score baseline was:

| Metric | Historical pre-5-stage best |
| --- | ---: |
| CoreMark/MHz | `2.3686` |
| CoreMark ticks | `422198` |
| PMU cycle | `442742` |
| PMU inst | `301697` |
| PMU hold | `109784` |

This version had a much lighter memory/interconnect path. It is the right
reference when discussing raw CPU efficiency, but it did not include the current
level of SoC integration, wait-state closure, cache path, DMA, QSPI, DDR/MIG,
and accelerator subsystem.

## Current AXI4 + APB BTB/BHT Baseline

The current development baseline is `feature/zu15eg-soc` with the AXI4 + APB
interconnect, static backward branch prediction, a four-entry frontend
prefetch queue, corrected EX/MEM backpressure handling, a strictly ordered
two-entry D-Cache write-through store queue, and a **32-entry** BTB with 2-bit
saturating BHT for conditional branches.

> Historical-artifact status (2026-08-21): the previously recorded binary in
> `tests/example/coremark/artifacts/axi_prefetch_baseline/` was intentionally
> removed with generated ELF/BIN/dump artifacts. Therefore
> `run_coremark_axi_prefetch_baseline.ps1` is no longer executable evidence and
> the historical table below is archival only. Use
> `tools/run_coremark_cpu_perf.ps1` for a current-source, SHA-256-printed,
> isolated **one-iteration RTL performance window**. It is not a formal
> CoreMark/MHz submission because `SIMULATION_FAST_EXIT` exits before
> CoreMark's required >=10-second reporting interval.

### Current-source short-window A/B (2026-08-21)

The same rebuilt RV32IM image (`ITERATIONS=1`, `SIMULATION_FAST_EXIT`) was run
with identical XSim memory settings. This executes the CoreMark list, matrix,
and state-machine workloads and uses PMU completion only to end simulation.

| BTB/BHT entries | Result | CoreMark ticks | PMU cycle | BP hit / miss |
| ---: | --- | ---: | ---: | --- |
| 16 | `TEST_PASS` | `421998` | `452392` | `47733 / 9540` |
| 32 (default) | `TEST_PASS` | `420732` | `451188` | `49273 / 8000` |

The 32-entry configuration reduces this controlled window by `0.30%`. The
gain is deliberately described as small: it validates the anti-aliasing
change, but does not justify an unqualified "CoreMark/MHz improvement" claim.

| Metric | Prefetch | 1-entry SQ | 1-entry SQ + BTB/BHT | 2-entry SQ + BTB/BHT |
| --- | ---: | ---: | ---: | ---: |
| CoreMark ticks | `370376` | `329113` | `319805` | `313419` |
| Approx. CoreMark/MHz | `2.7000` | `3.0385` | `3.1269` | `3.1906` |
| PMU cycle | `401989` | `358892` | `349320` | `342897` |
| PMU hold | `122713` | `79614` | `75366` | `68944` |
| Branch predictor hit / miss | `57619` / `11721` | `27370` / `10638` | `31874` / `6134` | `31519` / `6123` |
| D-Cache store wait | `72010` | `28371` | `28371` | `21741` |
| SQ enqueue / full stall / drain | N/A | `12420` / `19381` / `75493` | same | `12420` / `12582` / `75767` |

The cache-hit store queue reduces CoreMark ticks by `11.14%` and lowers the
quantified store-wait counter by `60.60%`. It is intentionally conservative:
store misses, uncached accesses, and line fills remain blocking; a buffered
write owns the backend until its handshake completes; cache-hit loads can still
read the local data RAM while the buffered write drains.

The BTB/BHT stage reduces ticks by a further `2.83%` versus the one-entry queue
baseline (`13.65%` total versus the prefetch reference) and reduces branch
prediction misses by `42.34%`. Validation completed: standalone store-path
scoreboard PASS, dedicated BTB/BHT TB PASS, full RV32UI ISA `39/39 PASS`, and
versioned CoreMark workload PASS. Expanding the queue to two entries reduces
ticks by another `2.00%` and full-queue stalls by `35.08%`; total improvement is
`15.38%` versus the versioned prefetch reference. This is an RTL simulation
baseline, not a post-route or board-level performance signoff.

### Cache RAM Implementation Tradeoff

The default cache data RAM stays zero-wait LUTRAM. A validated optional
`CacheUseBlockRam` mode converts I/D-cache data RAM reads to synchronous BRAM
and saves LUT (`53,894 -> 51,028`) in the retired FPGA experiment at the cost of three additional BRAM
tiles (`16 -> 19`). It is not the performance baseline: one-cycle BRAM hit
latency changes the same CoreMark workload from `313419` to `746902` ticks.
该结果是已退役通用 FPGA 试验的历史数据，仅保留用于理解 LUTRAM/BRAM 的取舍。

## Historical Baselines

The current signed baseline is `5-stage + I-Cache + D-Cache + SoC interconnect`.

### AXI4 + APB Migration Baseline

After replacing the product RIB interconnect with the initial AXI4 + APB
baseline, the single-global-outstanding crossbar and single-beat adapters made
the original 16-line I-Cache a severe front-end bottleneck.

| AXI4 configuration | Result | CoreMark ticks | CoreMark/MHz | PMU cycle | PMU inst | PMU hold | Fetch wait |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 16-line I-Cache, 64-line D-Cache | `PASS` | `1,860,553` | `0.5375` | `1,942,516` | `301,695` | `1,640,820` | `943,290` |
| 64-line I-Cache, 64-line D-Cache | `PASS` | `990,144` | `1.0099` | `1,038,337` | `301,695` | `736,641` | `211,590` |
| 128-line I-Cache, 64-line D-Cache | `PASS` | `839,655` | `1.1910` | `887,748` | `301,695` | `586,052` | `88,462` |
| 256-line I-Cache, 64-line D-Cache | `PASS` | `812,156` | `1.2313` | `860,249` | `301,695` | `558,553` | `66,126` |
| 256-line I-Cache + AXI burst refill | `PASS` | `769,580` | `1.2994` | `814,325` | `301,695` | `512,629` | `26,056` |

The 256-line I-Cache reduces CoreMark ticks by `56.35%` and improves
CoreMark/MHz by about `2.29x`, so it is the selected default for the ZU15EG
performance branch. Increasing D-Cache capacity did not improve this workload
and is not adopted.

AXI burst refill sends one `AR` request with `ARLEN=3` for each four-word
cache line instead of submitting four independent single-beat reads. Relative
to the 256-line single-beat baseline, this reduces ticks by another `5.24%`
and fetch wait by `60.60%`. The remaining hold time is now dominated by
pipeline control and data-side traffic rather than instruction line-fill
address handshakes.

| Scenario | Result | CoreMark ticks | CoreMark @ 50 MHz | CoreMark/MHz | PMU cycle | PMU inst | PMU hold |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `RomWaitCycles=0`, `RamWaitCycles=0` | `PASS` | `1073337` | `46.5837` | `0.9317` | `1120639` | `301695` | `818943` |
| `RomWaitCycles=2`, `RamWaitCycles=2` | `PASS` | `1474033` | `33.9205` | `0.6784` | `1538911` | `301695` | `1237215` |

The current D-Cache does improve the 5-stage no-cache baseline:

| Metric | 5-stage no D-Cache | Current 5-stage + D-Cache | Delta |
| --- | ---: | ---: | ---: |
| CoreMark/MHz (`wait=0`) | `0.8817` | `0.9317` | `+5.7%` |
| CoreMark ticks (`wait=0`) | `1134214` | `1073337` | `-5.4%` |
| PMU cycle (`wait=0`) | `1183092` | `1120639` | `-5.3%` |
| PMU hold (`wait=0`) | `881396` | `818943` | `-7.1%` |

So the current cache is directionally useful, but the whole current CPU path is
still much slower than the historical lightweight baseline.

## Why Current CoreMark Is Lower

The score reduction is mainly caused by control and memory-path bubbles, not by
wrong execution.

| Metric | Historical best | Current wait=0 | Change |
| --- | ---: | ---: | ---: |
| CoreMark/MHz | `2.3686` | `0.9317` | `-60.7%` |
| CoreMark ticks | `422198` | `1073337` | `+154.2%` |
| PMU cycle | `442742` | `1120639` | `+153.1%` |
| PMU hold | `109784` | `818943` | `+646.0%` |
| PMU inst | `301697` | `301695` | roughly unchanged |

Interpretation:

- instruction count is essentially unchanged, so the compiler/program workload
  is comparable
- cycle count and hold count increased sharply, so the problem is stalls and
  interconnect/cache/fetch/data wait, not functional correctness
- the current SoC prioritizes correctness under wait-state memory, APB/AXI
  integration, DDR window access, QSPI, DMA, and accelerator closure
- raw CoreMark now suffers because the common CPU path still pays conservative
  handshake and shared-memory penalties

## Current Engineering Value

The current CoreMark number should not be used alone to describe the project.

What the current version proves:

- the CPU is functionally stable on representative ISA and CoreMark workloads
- wait-state memory no longer breaks instruction/data correctness
- D-Cache reduces data-side traffic versus the 5-stage no-cache baseline
- the same SoC now includes APB/AXI peripherals, DMA, QSPI, DDR/MIG board
  window closure, PMU observability, and MAC/NPU workload acceleration

What it does not yet prove:

- this is not yet a high-CoreMark CPU microarchitecture
- the current fetch/data path is not yet optimized for one-instruction-per-cycle
  local-memory execution
- branch penalty and shared-memory hold cost are still performance bottlenecks

## Improvement Plan

If the goal is to exceed the historical CoreMark baseline, the next work should
be a dedicated CPU-performance branch. Adding more peripherals will not solve
this score.

### 1. Build A PMU Breakdown

Required fixed table for every CoreMark run:

| Item | Required metric |
| --- | --- |
| total cycles | `PMU cycle` |
| retired instructions | `PMU inst` |
| global hold | `PMU hold` |
| fetch pressure | fetch request / fetch wait |
| data pressure | data request / data wait |
| branch cost | branch count / branch flush cycles, if available |
| cache behavior | I-Cache hit/miss and D-Cache hit/miss, if available |

Without this table, CoreMark optimization becomes guessing.

### 2. Add A Fast Local-Memory Path

Target:

- CoreMark instruction and data working set should run from zero-wait local
  memory or tightly-coupled memory
- instruction fetch and data access should avoid the conservative SoC-wide
  RIB/APB/EXTMEM path when the address is local SRAM

Expected value:

- directly attacks `PMU hold`
- gives a fair CPU-core benchmark path separate from DDR/QSPI/peripheral traffic

### 3. Make I-Cache Hit Path Cheaper

Target:

- I-Cache hit should deliver an instruction every cycle in the common case
- line-fill wait should not introduce extra bubbles after the line is valid
- shared ROM/RAM wait-state closure should remain correct

Expected value:

- reduces fetch wait and global hold
- likely the highest-value front-end change for CoreMark

### 4. Reduce Load/Store Penalty

Target:

- D-Cache hit path should be one-cycle or close to one-cycle
- load-use stall should only appear when data is truly unavailable
- write-through/no-write-allocate policy can remain, but hit latency should not
  be dominated by generic bus wait

Expected value:

- improves matrix/list portions of CoreMark
- also helps RTOS and application workloads

### 5. Reduce Branch Penalty

Possible options:

- move branch decision earlier where practical
- add simple static prediction for backward branches
- add a very small branch target buffer only if timing remains controlled

Expected value:

- improves CoreMark control-heavy sections
- should be kept small to avoid hurting implementation timing

### 6. Preserve SoC Mode Separately

Do not remove the conservative SoC path. Keep two performance modes:

| Mode | Purpose |
| --- | --- |
| local fast path | raw CPU/CoreMark/RTOS performance |
| full SoC path | DDR/QSPI/DMA/NPU/peripheral correctness |

This lets the project claim both:

- strong SoC integration and board bring-up
- competitive CPU local-memory performance

## Practical Target

The current AXI4 + APB prefetch baseline already exceeds the historical raw
CPU result in RTL simulation. The next targets must therefore preserve the
same workload and validation scope rather than compare unrelated old numbers.

| Stage | Target |
| --- | --- |
| stability | retain `>2.5 CoreMark/MHz` after full ISA and subsystem regression |
| data-side | reduce `Data wait` below `60000` with a verified D-Cache miss/store path |
| stretch | exceed `3.0 CoreMark/MHz` under the same CoreMark binary and simulation configuration |

The current opportunity is data-side latency: `Data wait=73858` remains much
larger than fetch wait. Future score gains should come from a verified
critical-word-first/early-restart D-Cache path, ordered store buffering, and
only then a small dynamic branch predictor.

## Resume / Interview Framing

Do not frame the current CoreMark as the main achievement.

Correct framing:

- historical raw CPU baseline reached `2.3686 CoreMark/MHz`
- current AXI4 + APB RTL baseline reaches `2.7000 CoreMark/MHz` after static
  branch prediction and a four-entry frontend prefetch queue
- this result is a simulation baseline, not a post-route or board-level
  performance claim
- PMU analysis identifies `Data wait=73858` as the next dominant cost; the
  next optimization direction is D-Cache miss/store latency and ordering

This is more defensible than pretending the current CPU is already a
high-CoreMark core.
