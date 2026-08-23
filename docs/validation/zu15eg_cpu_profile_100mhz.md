# ZU15EG CPU Profile: 100 MHz Post-Route Record

## Scope

This build targets `xczu15eg-ffvb1156-2-i` and contains the interview-focused CPU profile:
the RV32IM core, I/D Cache, native-to-AXI4 adapters, AXI memory path, PMU, and JTAG/debug
logic. It is not the complete SoC and does not make a DDR4 or board-execution claim.

The 200 MHz differential board reference clock is divided by two in the profile wrapper, giving a
100 MHz `cpu_clk`.

## Implementation result

The complete Vivado implementation reached `write_bitstream` successfully.

| Item | Result |
| --- | ---: |
| Setup WNS | +1.163 ns |
| Setup TNS | 0 ns |
| Hold WHS | +0.012 ns |
| Hold THS | 0 ns |
| CLB LUT | 19,183 |
| CLB registers | 15,324 |
| BRAM tiles | 16 |
| DSP | 4 |

The reported worst setup path runs from `u_dcache/req_active_reg` to an instruction-prefetch
queue clock-enable. Its implied data-path delay is about 8.837 ns under this implementation.

## Frequency decision

The current wrapper uses an integer divide of the 200 MHz reference clock, so it directly
provides 100 MHz or 200 MHz rather than 125/150/175 MHz. The measured 8.837 ns setup path is
approximately 113 MHz before margin. A 125 MHz target has an 8.000 ns period and is therefore
not expected to close; 200 MHz is farther away. No higher-frequency implementation was run.

An intermediate sweep would first require an MMCM-based wrapper and should be preceded by a
separate timing optimization of the actual FPGA worst path. The JALR timing-cone change is not
evidence that the full CPU profile can run at 200 MHz.

## Reproduction note

Use the profile builder with `-CpuClockDiv 2`. The builder now reopens `impl_1` after the run
completes before creating the final timing, utilization, and DRC reports. Generated reports and
bitstreams remain ignored build artifacts.
