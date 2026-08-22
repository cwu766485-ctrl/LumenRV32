# Build the ZU15EG heterogeneous SoC + low-rate DDR4 MIG board image.
# Arguments:
#   <copied_project_dir> <out_dir> <repo_root> <inst_data> <ddr_clock_ps> <jobs> <synthesis_only>

if {$argc != 7} {
    error "Usage: build_zu15eg_soc_ddr4.tcl <project_dir> <out_dir> <repo_root> <inst_data> <ddr_clock_ps> <jobs> <synthesis_only>"
}

set project_dir [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
set repo_root [file normalize [lindex $argv 2]]
set inst_data [file normalize [lindex $argv 3]]
set ddr_clock_ps [lindex $argv 4]
set jobs [lindex $argv 5]
set synthesis_only [lindex $argv 6]
set xpr [file join $project_dir mem_test.xpr]
set top_name zu15eg_heterogeneous_soc_ddr4_top

if {![file exists $xpr]} { error "Missing copied project: $xpr" }
if {![file exists $inst_data]} { error "Missing ROM init file: $inst_data" }
file mkdir $out_dir

proc connect_pin_once {source sink} {
    set current [get_bd_nets -quiet -of_objects $sink]
    if {[llength $current] == 1} {
        disconnect_bd_net $current $sink
    }
    connect_bd_net $source $sink
}

open_project $xpr
upgrade_ip [get_ips]
set bd [lindex [get_files -quiet *design_1.bd] 0]
if {$bd eq ""} { error "Could not locate design_1.bd" }
open_bd_design $bd

set mig [get_bd_cells -quiet ddr4_0]
set smc [get_bd_cells -quiet axi_smc]
set ila [get_bd_cells -quiet ila_0]
if {[llength $mig] != 1 || [llength $smc] != 1 || [llength $ila] != 1} {
    error "Missing ddr4_0, axi_smc or ila_0"
}

# Full low-rate IP Customizer solution for MT40A1G16RC-062E.
set_property -dict [list \
    CONFIG.C0.DDR4_MemoryPart MT40A1G16RC-062E \
    CONFIG.C0.DDR4_InputClockPeriod 5000 \
    CONFIG.C0.DDR4_TimePeriod $ddr_clock_ps \
    CONFIG.C0.DDR4_CasLatency 11 \
    CONFIG.C0.DDR4_CasWriteLatency 11 \
    CONFIG.C0.DDR4_CLKFBOUT_MULT 7 \
    CONFIG.C0.DDR4_DIVCLK_DIVIDE 1 \
    CONFIG.C0.DDR4_CLKOUT0_DIVIDE 7] $mig

# Add the 32-bit SoC master beside the 128-bit PS HPM master.  The SoC runs
# from a /4 fabric clock, so cross it explicitly into the vendor 100 MHz
# SmartConnect input domain.
set_property CONFIG.NUM_SI 2 $smc
set soc_cdc [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 soc_axi_clock_converter]
connect_bd_intf_net [get_bd_intf_pins soc_axi_clock_converter/M_AXI] \
    [get_bd_intf_pins axi_smc/S01_AXI]
set intf_ports_before [get_bd_intf_ports -quiet]
make_bd_intf_pins_external [get_bd_intf_pins soc_axi_clock_converter/S_AXI]
set soc_axi [list]
foreach intf_port [get_bd_intf_ports -quiet] {
    if {[lsearch -exact $intf_ports_before $intf_port] < 0} {
        lappend soc_axi $intf_port
    }
}
if {[llength $soc_axi] != 1} { error "Could not externalize the SoC AXI interface" }
set_property name SOC_AXI $soc_axi
set_property -dict [list \
    CONFIG.ADDR_WIDTH 32 \
    CONFIG.DATA_WIDTH 32 \
    CONFIG.ID_WIDTH 4 \
    CONFIG.HAS_BURST 1 \
    CONFIG.MAX_BURST_LENGTH 256 \
    CONFIG.NUM_READ_OUTSTANDING 4 \
    CONFIG.NUM_WRITE_OUTSTANDING 4] $soc_axi

set soc_clk [create_bd_port -dir O -type clk soc_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] $soc_clk
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
    [get_bd_pins soc_axi_clock_converter/m_axi_aclk]

set soc_resetn [create_bd_port -dir O -type rst soc_resetn]
connect_bd_net [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] $soc_resetn
connect_bd_net [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] \
    [get_bd_pins soc_axi_clock_converter/m_axi_aresetn]

set soc_axi_clk [create_bd_port -dir I -type clk soc_axi_clk]
set_property CONFIG.FREQ_HZ 25000000 $soc_axi_clk
set_property CONFIG.ASSOCIATED_BUSIF SOC_AXI $soc_axi_clk
connect_bd_net $soc_axi_clk [get_bd_pins soc_axi_clock_converter/s_axi_aclk]
connect_bd_net [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] \
    [get_bd_pins soc_axi_clock_converter/s_axi_aresetn]

set calib_done [create_bd_port -dir O calib_done]
connect_bd_net [get_bd_pins ddr4_0/c0_init_calib_complete] $calib_done

# Six ILA probes: calibration/reset state plus the SoC terminal signature.
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES 6 \
    CONFIG.C_PROBE0_WIDTH 1 \
    CONFIG.C_PROBE1_WIDTH 1 \
    CONFIG.C_PROBE2_WIDTH 1 \
    CONFIG.C_PROBE3_WIDTH 1 \
    CONFIG.C_PROBE4_WIDTH 1 \
    CONFIG.C_PROBE5_WIDTH 1] $ila
connect_pin_once [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins ila_0/clk]
connect_pin_once [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins ila_0/probe1]
connect_pin_once [get_bd_pins ddr4_0/c0_ddr4_aresetn] [get_bd_pins ila_0/probe2]
connect_pin_once [get_bd_pins ddr4_0/sys_rst] [get_bd_pins ila_0/probe3]
set soc_over_i [create_bd_port -dir I soc_over_i]
set soc_succ_i [create_bd_port -dir I soc_succ_i]
connect_bd_net $soc_over_i [get_bd_pins ila_0/probe4]
connect_bd_net $soc_succ_i [get_bd_pins ila_0/probe5]

assign_bd_address -offset 0x00000000 -range 0x100000000 \
    -target_address_space [get_bd_addr_spaces SOC_AXI] \
    [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
validate_bd_design
save_bd_design
generate_target all $bd
set wrapper [lindex [make_wrapper -files $bd -top -force] 0]
if {$wrapper eq "" || ![file exists $wrapper]} { error "Failed to generate BD wrapper" }
add_files -norecurse $wrapper

set rtl_files [list]
foreach dir [list \
    [file join $repo_root rtl core] \
    [file join $repo_root rtl interconnect] \
    [file join $repo_root rtl perips] \
    [file join $repo_root rtl debug] \
    [file join $repo_root rtl utils]] {
    foreach file [lsort [glob -nocomplain -directory $dir *.v]] {
        lappend rtl_files $file
    }
}

lappend rtl_files [file join $repo_root rtl soc heterogeneous_soc_top.v]
lappend rtl_files [file join $repo_root fpga ddr zu15eg_heterogeneous_soc_ddr4_top.v]

add_files -norecurse $rtl_files
set inst_data_define [string map {\\ /} $inst_data]
set_property verilog_define [list \
    SOC_EXTMEM_AXI_PORTS \
    SOC_DDR_BOARD_MINIMAL \
    "FPGA_ROM_INIT=\"$inst_data_define\""] [get_filesets sources_1]
set_property top $top_name [get_filesets sources_1]
update_compile_order -fileset sources_1

reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
if {![string match "*synth_design Complete*" $synth_status]} {
    error "Synthesis did not complete: $synth_status"
}

open_run synth_1
report_utilization -file [file join $out_dir post_synth_utilization.rpt]
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file join $out_dir post_synth_hierarchical_utilization.rpt]
close_design

puts "ZU15EG_SOC_DDR4_SYNTHESIS=PASS"
puts "ZU15EG_SOC_DDR4_SYNTH_UTIL=[file join $out_dir post_synth_utilization.rpt]"
puts "ZU15EG_SOC_DDR4_SYNTH_HIER_UTIL=[file join $out_dir post_synth_hierarchical_utilization.rpt]"
if {$synthesis_only} {
    close_project
    exit
}

launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
if {![string match "*write_bitstream Complete*" $status]} {
    error "Implementation did not complete write_bitstream: $status"
}

set run_dir [get_property DIRECTORY [get_runs impl_1]]
set bit [file join $run_dir ${top_name}.bit]
set ltx [file join $run_dir ${top_name}.ltx]
if {![file exists $bit] || ![file exists $ltx]} {
    error "Expected bit/LTX were not generated: BIT=$bit LTX=$ltx"
}

open_run impl_1
report_utilization -file [file join $out_dir post_route_utilization.rpt]
report_timing_summary -delay_type max -max_paths 20 \
    -file [file join $out_dir post_route_timing.rpt]
report_drc -file [file join $out_dir post_route_drc.rpt]

set setup_path [lindex [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]
set hold_path [lindex [get_timing_paths -delay_type min -max_paths 1 -nworst 1] 0]
if {$setup_path eq "" || $hold_path eq ""} {
    error "Could not obtain post-route setup/hold timing paths"
}
set wns [get_property SLACK $setup_path]
set whs [get_property SLACK $hold_path]
puts "ZU15EG_SOC_DDR4_WNS=$wns"
puts "ZU15EG_SOC_DDR4_WHS=$whs"
if {$wns < 0.0 || $whs < 0.0} {
    error "Post-route timing is not closed: WNS=$wns WHS=$whs"
}

file copy -force $bit [file join $out_dir ${top_name}.bit]
file copy -force $ltx [file join $out_dir ${top_name}.ltx]

puts "ZU15EG_SOC_DDR4_BUILD=PASS"
puts "ZU15EG_SOC_DDR4_BIT=[file join $out_dir ${top_name}.bit]"
puts "ZU15EG_SOC_DDR4_LTX=[file join $out_dir ${top_name}.ltx]"
close_project
exit
