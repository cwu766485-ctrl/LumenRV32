# Run the controlled A53 DDR4 smoke in the same XSCT session that performs
# ZynqMP PS/FSBL initialization.  Reconnecting before `dow` can leave the
# A53 EDITR context unavailable on this board.
if {$argc != 7} {
    error "usage: run_zu15eg_ddr4_cpu_smoke_same_session.tcl <fsbl.elf> <design.xsa> <psu_init.tcl> <pmufw.elf> <init-report.txt> <smoke.elf> <board-report.txt>"
}
# The caller has already reset PS before configuring the PL MIG image.  Keep
# that image resident while performing PS/FSBL initialization.
set init_argv [list [lindex $argv 0] [lindex $argv 1] [lindex $argv 2] [lindex $argv 3] [lindex $argv 4] 1 0]
set elf [file normalize [lindex $argv 5]]
# init_zu15eg_ps_for_pl_ddr4.tcl also uses report_path.  Keep the caller's
# result path in a distinct variable so sourcing the init helper cannot
# redirect the smoke evidence into the init report.
set board_report_path [file normalize [lindex $argv 6]]
set ::zu15eg_keep_connected 1
set argv $init_argv
set argc [llength $argv]
source [file join [file dirname [info script]] init_zu15eg_ps_for_pl_ddr4.tcl]

targets -set -nocase -filter {name =~ "*A53*#0"}
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

set report [open $board_report_path w]
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
