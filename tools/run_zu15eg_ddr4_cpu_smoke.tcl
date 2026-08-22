if {$argc != 2} {
    error "usage: run_zu15eg_ddr4_cpu_smoke.tcl <smoke.elf> <report.txt>"
}

set elf [file normalize [lindex $argv 0]]
set report_path [file normalize [lindex $argv 1]]
if {![file exists $elf]} {
    error "smoke ELF not found: $elf"
}

connect -url tcp:127.0.0.1:3121
set a53s [targets -nocase -filter {name =~ "*A53*#0"}]
if {[llength $a53s] == 0} {
    disconnect
    error "A53#0 target was not found"
}
targets -set [lindex $a53s 0]
configparams force-mem-access 1
rst -processor
dow $elf
set done_bp [bpadd -addr &smoke_done]
con -block -timeout 30
bpremove $done_bp

set magic [mrd -value 0xFFFE0000]
set state [mrd -value 0xFFFE0004]
set words [mrd -value 0xFFFE0008]
set passes [mrd -value 0xFFFE000C]
set fail_index [mrd -value 0xFFFE0010]
set expected [mrd -value 0xFFFE0014]
set actual [mrd -value 0xFFFE0018]
set restore_index [mrd -value 0xFFFE001C]
set restore_expected [mrd -value 0xFFFE0020]
set restore_actual [mrd -value 0xFFFE0024]
set checksum_before [mrd -value 0xFFFE0028]
set checksum_after [mrd -value 0xFFFE002C]

set report [open $report_path w]
puts $report [format "MAGIC=0x%08X" $magic]
puts $report [format "STATE=0x%08X" $state]
puts $report [format "WORDS=%u" $words]
puts $report [format "PATTERN_PASSES=%u" $passes]
puts $report [format "FAIL_INDEX=0x%08X" $fail_index]
puts $report [format "EXPECTED=0x%08X" $expected]
puts $report [format "ACTUAL=0x%08X" $actual]
puts $report [format "RESTORE_FAIL_INDEX=0x%08X" $restore_index]
puts $report [format "RESTORE_EXPECTED=0x%08X" $restore_expected]
puts $report [format "RESTORE_ACTUAL=0x%08X" $restore_actual]
puts $report [format "CHECKSUM_BEFORE=0x%08X" $checksum_before]
puts $report [format "CHECKSUM_AFTER=0x%08X" $checksum_after]

set passed [expr {
    $magic == 0x44524434 &&
    $state == 0x50415353 &&
    $words == 1024 &&
    $passes == 4 &&
    $restore_index == 0xFFFFFFFF &&
    $checksum_before == $checksum_after
}]
set result [expr {$passed ? "PASS" : "FAIL"}]
puts $report "ZU15EG_DDR4_CPU_SMOKE=$result"
close $report
disconnect

if {!$passed} {
    error "controlled DDR4 CPU smoke reported failure"
}
