# Build CPU + AXI + PMU + JTAG USER2 profile for ZU15EG.
if {$argc != 4} { error "usage: build_zu15eg_cpu_jtag_user2.tcl <repo-root> <out-dir> <jobs> <cpu-clock-div>" }
set repo_root [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
set jobs [lindex $argv 2]
set cpu_clock_div [lindex $argv 3]
set project_dir [file join $out_dir vivado]
set top_name zu15eg_cpu_jtag_user2_top
if {$cpu_clock_div ni {1 2 3 4 5 6 7 8}} { error "cpu-clock-div must be an integer from 1 to 8" }

file mkdir $out_dir
create_project -force $top_name $project_dir -part xczu15eg-ffvb1156-2-i
set rtl_files [list]
foreach dir [list \
    [file join $repo_root rtl core] \
    [file join $repo_root rtl interconnect] \
    [file join $repo_root rtl perips] \
    [file join $repo_root rtl debug] \
    [file join $repo_root rtl utils]] {
    foreach file [lsort [glob -nocomplain -directory $dir *.v]] { lappend rtl_files $file }
}
lappend rtl_files \
    [file join $repo_root rtl soc heterogeneous_soc_top.v] \
    [file join $repo_root rtl soc cpu_axi_debug_profile_top.v] \
    [file join $repo_root fpga zu15eg_cpu_jtag_user2_top.v]
add_files -norecurse $rtl_files
add_files -fileset constrs_1 -norecurse [file join $repo_root fpga zu15eg_cpu_profile.xdc]
set_property verilog_define [list SOC_CPU_AXI_DEBUG_PROFILE SOC_DDR_BOARD_MINIMAL \
    "FPGA_CPU_CLK_DIV=$cpu_clock_div"] [get_filesets sources_1]
set_property top $top_name [get_filesets sources_1]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
set status [get_property STATUS [get_runs impl_1]]
if {![string match "*write_bitstream Complete*" $status]} { error "Implementation failed: $status" }
open_run impl_1
set run_dir [get_property DIRECTORY [get_runs impl_1]]
file copy -force [file join $run_dir ${top_name}.bit] [file join $out_dir ${top_name}.bit]
report_timing_summary -file [file join $out_dir timing.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
report_drc -file [file join $out_dir drc.rpt]
puts "ZU15EG_CPU_JTAG_USER2_BUILD=PASS"
