# AXI Prefetch CoreMark Baseline Manifest

This directory contains the immutable CoreMark workload used for the current
AXI4 + APB prefetch performance baseline.

## Artifact identity

| File | SHA-256 |
| --- | --- |
| `coremark_axi_prefetch_iter1.elf` | `3FA01BF23FA3C61AE980247C64045DF11EDA750CBD9F9AB1A41931CC997AE725` |
| `coremark_axi_prefetch_iter1.bin` | `55852A312313CA5AA1EAEE291FF82783F6D775AA0B1DE3AE3450710C4DF56E7D` |
| `coremark_axi_prefetch_iter1.dump` | `3C459FE54A9310480AFF3F51FD8CEF3C3AD2E9AB7EAF7ED08E18B33DCFFFE931` |

The binary contains `seed4_volatile = 1`; this is the accepted one-workload
CoreMark simulation image. Its measured tick count is not equivalent to a
standard wall-clock CoreMark score without the documented SoC clock setting.

## PMU completion ABI

The APB PMU window starts at `0x2000_4000`.

| Register | Address | Meaning |
| --- | --- | --- |
| `SIM_DONE` | `0x2000_4044` | Software writes `1` after completing the workload. |
| `SIM_TICKS` | `0x2000_4048` | Software writes the low 32 bits of elapsed ticks. |
| `SIM_TICKSH` | `0x2000_404c` | Software writes the high 32 bits of elapsed ticks. |

The testbench waits for `SIM_DONE == 1`; it does not infer completion from a
general-purpose register.

## Reproduction contract

- RTL commit: `eca75763e779644619cfcfee000022d91ac9948d`
- Expected result: `TEST_PASS`, `CoreMark ticks = 370376`,
  `PMU cycle = 401989`.
- Command:

```powershell
./tools/run_coremark_axi_prefetch_baseline.ps1
```

The runner verifies the binary SHA-256 and uses an isolated simulation directory
under `build/`, so ISA or subsystem regressions cannot overwrite its `inst.data`.
