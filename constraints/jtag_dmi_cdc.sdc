# JTAG DMI CDC constraint template.
# Use this only in a top level that exposes an active external jtag_TCK port.
# The CPU-focused FPGA profile ties jtag_TCK low, so do not source this file there.
# The concrete ZU15EG raw-JTAG profile is fpga/zu15eg_cpu_jtag_raw_base.xdc.

# Example only: replace core_clk with the actual root clock in another top.
# create_clock -name jtag_tck -period 20.000 [get_ports jtag_TCK]
# set_clock_groups -asynchronous \
#     -group [get_clocks -include_generated_clocks core_clk] \
#     -group [get_clocks jtag_tck]

# Do not synchronize every bit of the DMI request/response bundle. The
# four-phase handshake holds source data stable until acknowledgement. After
# synthesis, add datapath-only/max-delay bundle checks using real instance names
# if the implementation flow supports them; do not blanket-false-path the CDC.
