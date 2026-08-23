# Base constraints for the ZU15EG CPU profile with external raw JTAG.
# Supply PACKAGE_PIN and IOSTANDARD for the four JTAG ports in a separate XDC.
create_clock -name PL_REFCLK_200M -period 5.000 [get_ports pl_ref_clk_p]
set_property -dict {PACKAGE_PIN AL5 IOSTANDARD LVDS} [get_ports pl_ref_clk_n]
set_property -dict {PACKAGE_PIN AL6 IOSTANDARD LVDS} [get_ports pl_ref_clk_p]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports status_led]

# Initial board target: an external 50 MHz TCK. It remains asynchronous to cpu_clk.
create_clock -name JTAG_TCK -period 20.000 [get_ports jtag_TCK]
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks PL_REFCLK_200M] \
    -group [get_clocks JTAG_TCK]
