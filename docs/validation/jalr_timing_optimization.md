# JALR Forwarding Timing Optimization

## Motivation

The original implementation allowed an EX result to feed the target-base operand of the immediately following `JALR` through the ID forwarding network. In the 28 nm setup experiment this created a long feedback cone from an EX producer register to the `id_ex` JALR target register.

The change trades one cycle of latency for that specific dependency pattern in exchange for a shorter, registered target-data path. It is intentionally narrow: normal ALU and branch consumers retain EX forwarding.

## RTL change

- `rtl/core/id.v` selects the JALR base from MEM/WB forwarding or the register file, rather than the EX forwarding mux.
- `rtl/core/riscv_cpu_core.v` detects a non-load EX producer whose destination matches `JALR.rs1` and inserts one bubble.
- Existing load-use handling remains responsible for load dependencies.

For an ALU instruction immediately followed by a dependent `JALR`, the JALR is accepted after the producer value is available through the later forwarding path. This is a timing/IPC trade-off, not a zero-cost optimization.

## Functional checks

| Check | Result |
| --- | --- |
| `tools/run_id_jalr_forwarding_tb.ps1` | `ID_JALR_FORWARDING_TB_PASS` |
| `tests/example/jalr_forwarding` on the SoC testbench | `TEST_PASS`, 675 cycles / 161 instructions |
| `simple` bare-metal smoke | `TEST_PASS`, 3250 cycles / 2010 instructions |

The directed test covers JALR MEM forwarding, WB forwarding, register-file fallback, and retention of EX forwarding for a non-JALR ALU consumer.

## 28 nm Design Compiler experiment

The A/B uses `rtl/soc/jalr_timing_cone_top.v`. It instantiates the real `ex`, `id`, and `id_ex` modules, but excludes caches and the rest of the SoC. The harness is therefore suitable for the targeted feedback-path comparison only; its cell area is not full-CPU area.

Both runs used the same local 28 nm SS setup library and a 5.000 ns clock constraint. Only the setup/max library was used. A locally available FF/min library had incompatible cell naming, so this experiment intentionally makes **no hold claim**.

| Version | Path | Logic levels | Arrival | Setup slack |
| --- | --- | ---: | ---: | ---: |
| Baseline | `producer_op2_r_reg[0]` → `u_id_ex/op1_jump_reg[31]` | 80 | 4.90 ns | +0.00 ns |
| Optimized | direct EX → JALR capture path | removed | — | — |
| Optimized | `late_data_r_reg[31]` → `u_id_ex/op1_jump_reg[31]` | 0 | 0.09 ns | +4.77 ns |

This demonstrates removal of the targeted combinational feedback cone. It does **not** establish a new full-CPU Fmax, full-core PPA improvement, post-layout timing closure, or silicon performance.

## Reproduction

Run in a Linux shell after loading the local licensed DC environment, not inside a `dc_shell>` prompt:

```bash
export ASIC28_MAX_LIB='<local 28nm SS setup .db>'
export ASIC28_TOP=jalr_timing_cone_top
export ASIC28_CLK_NS=5.000
export ASIC28_OUT_DIR=build/asic28_jalr_cone
bash tools/asic/run_dc_cpu.sh
```

To reproduce the baseline, check out the parent commit and run the same command. Compare `jalr_ex_to_idex.rpt` and `jalr_late_to_idex.rpt`. PDK files, `.db` libraries, and generated DC reports are local-only artifacts.
