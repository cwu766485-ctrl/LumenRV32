create_clock -name PL_REFCLK_200M -period 5.000 [get_ports pl_ref_clk_p]
set_property -dict {PACKAGE_PIN AL5 IOSTANDARD LVDS} [get_ports pl_ref_clk_n]
set_property -dict {PACKAGE_PIN AL6 IOSTANDARD LVDS} [get_ports pl_ref_clk_p]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports status_led]
