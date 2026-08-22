# Build a minimal ZU15EG project-RTL image: RV32IM + BRAM + UART only.
if {$argc != 5} {
    error "usage: build_zu15eg_riscv_bram_uart.tcl <repo-root> <out-dir> <inst.data> <jobs> <cpu-clock-div>"
}
set repo_root [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
set inst_data [file normalize [lindex $argv 2]]
set jobs [lindex $argv 3]
set cpu_clock_div [lindex $argv 4]
set project_dir [file join $out_dir vivado]
set top_name zu15eg_riscv_bram_uart_top
if {![file exists $inst_data]} { error "Missing ROM init file: $inst_data" }
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
    foreach file [lsort [glob -nocomplain -directory $dir *.v]] {
        lappend rtl_files $file
    }
}
lappend rtl_files [file join $repo_root rtl soc heterogeneous_soc_top.v]
lappend rtl_files [file join $repo_root fpga zu15eg_riscv_bram_uart_top.v]
add_files -norecurse $rtl_files
add_files -fileset constrs_1 -norecurse [file join $repo_root fpga zu15eg_riscv_bram_uart.xdc]
set inst_data_define [string map {\\ /} $inst_data]
set_property verilog_define [list SOC_DDR_BOARD_MINIMAL \
    "FPGA_CPU_CLK_DIV=$cpu_clock_div" "FPGA_ROM_INIT=\"$inst_data_define\""] [get_filesets sources_1]
set_property top $top_name [get_filesets sources_1]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
set status [get_property STATUS [get_runs impl_1]]
if {![string match "*write_bitstream Complete*" $status]} { error "Implementation failed: $status" }
set run_dir [get_property DIRECTORY [get_runs impl_1]]
foreach file [list \
    [file join $run_dir ${top_name}.bit] \
    [file join $out_dir ${top_name}.bit]] { }
file copy -force [file join $run_dir ${top_name}.bit] [file join $out_dir ${top_name}.bit]
report_timing_summary -file [file join $out_dir timing.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
report_drc -file [file join $out_dir drc.rpt]
puts "ZU15EG_RISCV_BRAM_UART_BUILD=PASS"
puts "ZU15EG_RISCV_BRAM_UART_CPU_CLOCK_DIV=$cpu_clock_div"
puts "ZU15EG_RISCV_BRAM_UART_BIT=[file join $out_dir ${top_name}.bit]"
