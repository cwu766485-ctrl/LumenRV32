# PMU Register Map

Base address: `0x2000_4000`

The PMU sits behind the standardized `AXI4 -> APB` peripheral aperture:

- `0x2000_0000`: Timer
- `0x2000_1000`: UART
- `0x2000_2000`: GPIO
- `0x2000_3000`: SPI
- `0x2000_4000`: PMU
- `0x2000_5000`: DMA registers
- `0x2000_6000`: NPU registers
- `0x2000_7000`: QSPI
- `0x2000_8000`: I2C

| Offset | Name | Description |
| --- | --- | --- |
| `0x00` | `PMU_CTRL` | Write bit0=`1` to clear all PMU counters and simulation scratch registers |
| `0x04` | `PMU_CYCLE_LO` | Cycle counter low 32 bits |
| `0x08` | `PMU_CYCLE_HI` | Cycle counter high 32 bits |
| `0x0c` | `PMU_INST_LO` | Non-bubble execute-stage instruction count low 32 bits |
| `0x10` | `PMU_INST_HI` | Non-bubble execute-stage instruction count high 32 bits |
| `0x14` | `PMU_JUMP_LO` | Branch/jump redirect count low 32 bits |
| `0x18` | `PMU_JUMP_HI` | Branch/jump redirect count high 32 bits |
| `0x1c` | `PMU_LOAD_LO` | Load instruction count low 32 bits |
| `0x20` | `PMU_LOAD_HI` | Load instruction count high 32 bits |
| `0x24` | `PMU_STORE_LO` | Store instruction count low 32 bits |
| `0x28` | `PMU_STORE_HI` | Store instruction count high 32 bits |
| `0x2c` | `PMU_HOLD_LO` | Pipeline hold-cycle count low 32 bits |
| `0x30` | `PMU_HOLD_HI` | Pipeline hold-cycle count high 32 bits |
| `0x34` | `PMU_INT_LO` | Trap-entry count low 32 bits |
| `0x38` | `PMU_INT_HI` | Trap-entry count high 32 bits |
| `0x3c` | `PMU_DIV_WAIT_LO` | Divider busy-cycle count low 32 bits |
| `0x40` | `PMU_DIV_WAIT_HI` | Divider busy-cycle count high 32 bits |
| `0x44` | `PMU_SIM_DONE` | Simulation-only completion marker used by testbench fast-exit flows |
| `0x48` | `PMU_SIM_TICKS_LO` | Simulation-only benchmark tick low 32 bits |
| `0x4c` | `PMU_SIM_TICKS_HI` | Simulation-only benchmark tick high 32 bits |
| `0x50` | `PMU_ICACHE_HIT` | I-Cache hit event count, low 32 bits |
| `0x54` | `PMU_ICACHE_MISS` | I-Cache miss/line-fill start event count, low 32 bits |
| `0x58` | `PMU_DCACHE_LOAD_HIT` | D-Cache load hit event count, low 32 bits |
| `0x5c` | `PMU_DCACHE_LOAD_MISS` | D-Cache load miss/line-fill start event count, low 32 bits |
| `0x60` | `PMU_DCACHE_STORE_HIT` | D-Cache store hit accepted into store queue, low 32 bits |
| `0x64` | `PMU_DCACHE_STORE_MISS` | D-Cache store miss / no-write-allocate backend write completion, low 32 bits |
| `0x68` | `PMU_BRANCH_REDIRECT` | EX-stage jump/branch/trap redirect count, low 32 bits |
| `0x6c` | `PMU_BRANCH_FLUSH` | Frontend/ID flush count caused by redirect/prediction correction, low 32 bits |
| `0x70` | `PMU_PREFETCH_OCC_SUM` | Sum of frontend prefetch queue occupancy sampled once per cycle |
| `0x74` | `PMU_PREFETCH_FULL` | Cycles where prefetch queue is full |
| `0x78` | `PMU_PREFETCH_STALL` | Cycles where prefetch queue prevents accepting another frontend item |
| `0x7c` | `PMU_BRANCH_PRED_HIT` | Branch prediction hit/resolution match count |
| `0x80` | `PMU_BRANCH_PRED_MISS` | Branch prediction miss/resolution mismatch count |
| `0x84` | `PMU_DCACHE_LOAD_MISS_STALL` | Cycles where a load waits for D-Cache miss refill |
| `0x88` | `PMU_DCACHE_STORE_WAIT` | Cycles where a store waits because it cannot be accepted immediately |
| `0x8c` | `PMU_ID_CONTENTION` | Cycles where instruction and data native requests are both active |
| `0x90` | `PMU_STORE_BUFFER_ENQUEUE` | D-Cache store queue enqueue count |
| `0x94` | `PMU_STORE_BUFFER_FULL_STALL` | Cycles where a store is blocked by a full store queue |
| `0x98` | `PMU_STORE_BUFFER_DRAIN` | Cycles where the store queue is non-empty and draining to backend |
| `0x9c` | `PMU_FETCH_BUS_WAIT` | Cycles where CPU I-side request is waiting for AXI/native response |
| `0xa0` | `PMU_DATA_BUS_WAIT` | Cycles where CPU D-side request is waiting for AXI/native response |

Notes:

- `PMU_INST` counts non-bubble instructions entering the execute stage.
- `PMU_JUMP` counts branch and jump redirects, including `mret`.
- `PMU_INT` counts trap-entry events only; trap return is not included.
- `PMU_DIV_WAIT` counts cycles where the divider stays busy.
- `PMU_SIM_*` registers are for regression and benchmark bring-up; software does not need them in normal hardware runs.
- Counters from `0x50` onward are currently exposed as low 32-bit event counters. They are intended for relative profiling across short simulation/CoreMark windows.
- `PMU_FETCH_BUS_WAIT` and `PMU_DATA_BUS_WAIT` observe the CPU I-side/D-side native request interfaces after the AXI4 migration. They are the software-visible equivalent of the older testbench-only fetch/data bus wait counters.
