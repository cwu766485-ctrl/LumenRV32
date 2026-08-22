# Resume implementation from the synthesis checkpoint left by
# build_zu15eg_soc_ddr4.ps1 -SynthesisOnly.
# Arguments: <copied_project_dir> <out_dir> <jobs>

if {$argc != 3} {
    error "Usage: resume_zu15eg_soc_ddr4_impl.tcl <project_dir> <out_dir> <jobs>"
}

set project_dir [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
set jobs [lindex $argv 2]
set xpr [file join $project_dir mem_test.xpr]
set top_name zu15eg_heterogeneous_soc_ddr4_top

if {![file exists $xpr]} { error "Missing synthesized project: $xpr" }
file mkdir $out_dir
open_project $xpr

set synth_status [get_property STATUS [get_runs synth_1]]
if {![string match "*synth_design Complete*" $synth_status]} {
    error "Synthesis checkpoint is not complete: $synth_status"
}

reset_run impl_1
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
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file join $out_dir post_route_hierarchical_utilization.rpt]
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
