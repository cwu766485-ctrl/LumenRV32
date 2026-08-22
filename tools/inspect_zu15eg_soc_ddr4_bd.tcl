# Inspect the vendor DDR4 block design after temporarily adding a second
# SmartConnect slave interface.  The copied project under build/ may be
# modified; the supplied hardware project is never opened by this script.
#
# Usage:
#   vivado -mode batch -source tools/inspect_zu15eg_soc_ddr4_bd.tcl \
#     -tclargs <copied_project_dir> <report_file>

if {$argc != 2} {
    error "Usage: inspect_zu15eg_soc_ddr4_bd.tcl <project_dir> <report_file>"
}

set project_dir [file normalize [lindex $argv 0]]
set report_file [file normalize [lindex $argv 1]]
set xpr [file join $project_dir mem_test.xpr]

if {![file exists $xpr]} {
    error "Missing copied project: $xpr"
}

open_project $xpr
set bd [lindex [get_files -quiet *design_1.bd] 0]
if {$bd eq ""} {
    error "Could not locate design_1.bd"
}
open_bd_design $bd

set smc [get_bd_cells -quiet axi_smc]
if {[llength $smc] != 1} {
    error "Could not locate axi_smc"
}
set_property CONFIG.NUM_SI 2 $smc

make_bd_intf_pins_external [get_bd_intf_pins axi_smc/S01_AXI]
set soc_axi [get_bd_intf_ports -quiet S01_AXI_0]
if {[llength $soc_axi] != 1} {
    error "Could not externalize axi_smc/S01_AXI"
}
set_property name SOC_AXI $soc_axi
set_property -dict [list \
    CONFIG.ADDR_WIDTH 32 \
    CONFIG.DATA_WIDTH 32 \
    CONFIG.ID_WIDTH 1 \
    CONFIG.HAS_BURST 1 \
    CONFIG.MAX_BURST_LENGTH 256 \
    CONFIG.NUM_READ_OUTSTANDING 1 \
    CONFIG.NUM_WRITE_OUTSTANDING 1] $soc_axi

set soc_clk [create_bd_port -dir O -type clk soc_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] $soc_clk
set_property CONFIG.ASSOCIATED_BUSIF SOC_AXI $soc_clk
set soc_resetn [create_bd_port -dir O -type rst soc_resetn]
connect_bd_net [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] $soc_resetn
set_property CONFIG.ASSOCIATED_RESET soc_resetn $soc_clk

assign_bd_address -offset 0x00000000 -range 0x100000000 \
    -target_address_space [get_bd_addr_spaces SOC_AXI] \
    [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
validate_bd_design
save_bd_design
generate_target all $bd
set generated_wrapper [lindex [make_wrapper -files $bd -top -force] 0]

set fh [open $report_file w]
puts $fh "SMARTCONNECT_PROPERTIES"
foreach prop [lsort [list_property $smc]] {
    if {[string match "CONFIG.*" $prop]} {
        set value [get_property $prop $smc]
        if {$value ne ""} {
            puts $fh "$prop=$value"
        }
    }
}

puts $fh "\nINTERFACE_PINS"
foreach pin [lsort [get_bd_intf_pins -quiet axi_smc/*]] {
    puts $fh "$pin MODE=[get_property MODE $pin] VLNV=[get_property VLNV $pin]"
}

puts $fh "\nSCALAR_PINS"
foreach pin [lsort [get_bd_pins -quiet axi_smc/*]] {
    puts $fh "$pin DIR=[get_property DIR $pin] TYPE=[get_property TYPE $pin]"
}

puts $fh "\nADDRESS_SPACES"
foreach space [lsort [get_bd_addr_spaces -quiet]] {
    puts $fh "$space"
}

puts $fh "\nEXTERNAL_INTERFACE_PROPERTIES"
foreach prop [lsort [list_property $soc_axi]] {
    if {[string match "CONFIG.*" $prop]} {
        set value [get_property $prop $soc_axi]
        if {$value ne ""} {
            puts $fh "$prop=$value"
        }
    }
}

puts $fh "\nADDRESS_SEGMENTS"
foreach seg [lsort [get_bd_addr_segs -quiet]] {
    puts $fh "$seg OFFSET=[get_property OFFSET $seg] RANGE=[get_property RANGE $seg]"
}
puts $fh "\nGENERATED_WRAPPER=$generated_wrapper"
close $fh

close_project
puts "ZU15EG_SOC_DDR4_BD_INSPECT=PASS REPORT=$report_file"
exit
