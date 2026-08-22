# Re-customize the vendor MIG XCI through the Vivado IP engine and generate it in build/.
# This is intentionally isolated from the reference project.

set repo_root [file normalize [file join [file dirname [info script]] ..]]
set source_xci [file join $repo_root docs hardware zu15eg 15eg_demo 1.mem_test prj mem_test mem_test.srcs sources_1 bd design_1 ip design_1_ddr4_0_0 design_1_ddr4_0_0.xci]
set work_dir [file join $repo_root build zu15eg_ddr4_lowrate_ip]
file delete -force $work_dir
file mkdir $work_dir
set copied_xci [file join $work_dir ddr4_lowrate.xci]
file copy -force $source_xci $copied_xci

create_project -force zu15eg_ddr4_lowrate_ip $work_dir -part xczu15eg-ffvb1156-2-i
read_ip $copied_xci
set ip [get_ips ddr4_lowrate]
upgrade_ip $ip

# Apply through the IP customizer, not the BD-cell override used by the rejected experiment.
set_property -dict [list \
    CONFIG.C0.DDR4_MemoryPart {MT40A1G16RC-062E} \
    CONFIG.C0.DDR4_InputClockPeriod {5000} \
    CONFIG.C0.DDR4_TimePeriod {1250}] $ip
generate_target all $ip

set report [open [file join $work_dir lowrate_ip_report.txt] w]
puts $report "VIVADO=[version -short]"
foreach p {CONFIG.C0.DDR4_MemoryPart CONFIG.C0.DDR4_InputClockPeriod CONFIG.C0.DDR4_TimePeriod CONFIG.C0.DDR4_CasLatency CONFIG.C0.DDR4_CasWriteLatency} {
    puts $report "$p=[get_property $p $ip]"
}
puts $report "IP_STATUS=[get_property STATUS $ip]"
close $report
puts "ZU15EG_DDR4_LOWRATE_IP=PASS"
puts "ZU15EG_DDR4_LOWRATE_REPORT=[file join $work_dir lowrate_ip_report.txt]"
close_project
exit
