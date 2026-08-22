# Builds a vendor-demo-derived, low-rate PL DDR4 calibration diagnostic image.
# Arguments: <copied_project_dir> <out_dir> <DDR clock period ps> <jobs>

if {$argc != 4} {
    error "Usage: build_zu15eg_ddr4_debug.tcl <project_dir> <out_dir> <ddr_clock_ps> <jobs>"
}
set project_dir [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
set ddr_clock_ps [lindex $argv 2]
set jobs [lindex $argv 3]
set xpr [file join $project_dir mem_test.xpr]

if {![file exists $xpr]} { error "Missing copied project: $xpr" }
file mkdir $out_dir
open_project $xpr

# This copy is deliberately upgraded in the installed Vivado; never modify the supplied 2022.1 project.
upgrade_ip [get_ips]
set bd [lindex [get_files -quiet *design_1.bd] 0]
if {$bd eq ""} { error "Could not locate design_1.bd" }
open_bd_design $bd

set mig [get_bd_cells -quiet ddr4_0]
set ila [get_bd_cells -quiet ila_0]
if {[llength $mig] != 1 || [llength $ila] != 1} { error "Missing ddr4_0 or ila_0 in block design" }

# Values below are taken from an isolated Vivado IP Customizer generation for this exact
# memory-part/input-clock combination at 1250 ps (CL/CWL/MMCM ratios included).
set_property -dict [list CONFIG.C0.DDR4_MemoryPart MT40A1G16RC-062E \
                         CONFIG.C0.DDR4_InputClockPeriod 5000 \
                         CONFIG.C0.DDR4_TimePeriod $ddr_clock_ps \
                         CONFIG.C0.DDR4_CasLatency 11 \
                         CONFIG.C0.DDR4_CasWriteLatency 11 \
                         CONFIG.C0.DDR4_CLKFBOUT_MULT 7 \
                         CONFIG.C0.DDR4_DIVCLK_DIVIDE 1 \
                         CONFIG.C0.DDR4_CLKOUT0_DIVIDE 7] $mig
set_property -dict [list CONFIG.C_NUM_OF_PROBES {4} \
                         CONFIG.C_PROBE0_WIDTH {1} \
                         CONFIG.C_PROBE1_WIDTH {1} \
                         CONFIG.C_PROBE2_WIDTH {1} \
                         CONFIG.C_PROBE3_WIDTH {1}] $ila

# Keep the diagnostic ILA independent of the MIG UI clock.  If the PHY never
# produces a usable UI clock, an ILA clocked from that same domain cannot tell
# whether reset or calibration is responsible.  PS pl_clk0 is initialized by
# the FSBL before capture and remains available while MIG is being diagnosed.
set ila_clk_pin [get_bd_pins ila_0/clk]
set ila_clk_net [get_bd_nets -quiet -of_objects $ila_clk_pin]
if {[llength $ila_clk_net] == 1} {
    disconnect_bd_net $ila_clk_net $ila_clk_pin
}
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] $ila_clk_pin

# probe0 already retains calibration-complete in the vendor design; the other
# probes distinguish a stuck reset from a failed training sequence.
connect_bd_net [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins ila_0/probe1]
connect_bd_net [get_bd_pins ddr4_0/c0_ddr4_aresetn] [get_bd_pins ila_0/probe2]
connect_bd_net [get_bd_pins ddr4_0/sys_rst] [get_bd_pins ila_0/probe3]
validate_bd_design
save_bd_design

generate_target all $bd
set wrapper [lindex [make_wrapper -files $bd -top] 0]
if {$wrapper eq "" || ![file exists $wrapper]} { error "Failed to generate design_1_wrapper.v" }
add_files -norecurse $wrapper
set_property top design_1_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
if {![string match "*write_bitstream Complete*" $status]} {
    error "Implementation did not complete write_bitstream: $status"
}

set bit [file join $project_dir mem_test.runs impl_1 design_1_wrapper.bit]
set ltx [file join $project_dir mem_test.runs impl_1 design_1_wrapper.ltx]
if {![file exists $bit] || ![file exists $ltx]} { error "Expected bit/LTX were not generated" }
file copy -force $bit [file join $out_dir design_1_wrapper.bit]
file copy -force $ltx [file join $out_dir design_1_wrapper.ltx]
puts "ZU15EG_DDR4_DEBUG_BUILD=PASS DDR_CLOCK_PS=$ddr_clock_ps"
puts "ZU15EG_DDR4_DEBUG_BIT=[file join $out_dir design_1_wrapper.bit]"
puts "ZU15EG_DDR4_DEBUG_LTX=[file join $out_dir design_1_wrapper.ltx]"
close_project
exit
