# Inspect the supplied vendor DDR4 post-route checkpoint without modifying it.
# Usage: vivado -mode batch -source tools/inspect_zu15eg_memtest_dcp.tcl

set repo_root [file normalize [file join [file dirname [info script]] ..]]
set dcp [file join $repo_root docs hardware zu15eg 15eg_demo 1.mem_test prj mem_test mem_test.runs impl_1 design_1_wrapper_routed.dcp]
set out_dir [file join $repo_root build zu15eg_memtest_dcp_inspect]
file mkdir $out_dir

if {![file exists $dcp]} {
    error "Missing routed checkpoint: $dcp"
}

open_checkpoint $dcp
set report [open [file join $out_dir nets.txt] w]
puts $report "CHECKPOINT=$dcp"
foreach pattern {
    *ddr4_0*c0_init_calib_complete*
    *ddr4_0*c0_ddr4_ui_clk*
    *ddr4_0*c0_ddr4_aresetn*
    *rst_ps8_0_99M*peripheral_reset*
    *rst_ddr4_0_333M*peripheral_aresetn*
    *pl_resetn0*
} {
    puts $report "PATTERN=$pattern"
    foreach net [get_nets -hier -quiet $pattern] {
        puts $report "NET=[get_property NAME $net]"
    }
}
close $report
puts "ZU15EG_MEMTEST_DCP_INSPECT=[file join $out_dir nets.txt]"
close_project
exit
