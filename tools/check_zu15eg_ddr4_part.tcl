# Query whether the installed Vivado DDR4 IP accepts the board schematic part.
# Run in batch mode; all generated project data stays under build/.

set repo_root [file normalize [file join [file dirname [info script]] ..]]
set work_dir [file join $repo_root build zu15eg_ddr4_part_check]
file delete -force $work_dir
create_project -force zu15eg_ddr4_part_check $work_dir -part xczu15eg-ffvb1156-2-i
create_ip -name ddr4 -vendor xilinx.com -library ip -module_name ddr4_part_probe

set ip [get_ips ddr4_part_probe]
set report [open [file join $work_dir ddr4_part_check.txt] w]
puts $report "VIVADO_VERSION=[version -short]"
puts $report "DEFAULT_PART=[get_property CONFIG.C0.DDR4_MemoryPart $ip]"

foreach part {MT40A1G16KD-062E MT40A1G16KD-062E:E MT40A1G16RC-062E} {
    set result PASS
    if {[catch {set_property -dict [list CONFIG.C0.DDR4_MemoryPart $part] $ip} err]} {
        set result "REJECTED: $err"
    }
    puts $report "PART=$part RESULT=$result CURRENT=[get_property CONFIG.C0.DDR4_MemoryPart $ip]"
}
set_property -dict [list CONFIG.C0.DDR4_MemoryPart MT40A1G16RC-062E] $ip
foreach period {750 1000 1250} {
    set result PASS
    if {[catch {set_property -dict [list CONFIG.C0.DDR4_TimePeriod $period] $ip} err]} {
        set result "REJECTED: $err"
    }
    puts $report "DDR_CLOCK_PS=$period RESULT=$result CURRENT=[get_property CONFIG.C0.DDR4_TimePeriod $ip]"
}
close $report
puts "ZU15EG_DDR4_PART_CHECK=[file join $work_dir ddr4_part_check.txt]"
close_project
exit
