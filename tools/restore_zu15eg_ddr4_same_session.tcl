# Restore the controlled PL-DDR window from a text backup in the same XSCT
# session as PS initialization, then verify every restored word.
if {$argc != 7} {
    error "usage: restore_zu15eg_ddr4_same_session.tcl <fsbl.elf> <design.xsa> <psu_init.tcl> <pmufw.elf> <init-report.txt> <data.txt> <restore-report.txt>"
}

set init_argv [list [lindex $argv 0] [lindex $argv 1] [lindex $argv 2] [lindex $argv 3] [lindex $argv 4] 1 0]
set data_path [file normalize [lindex $argv 5]]
set restore_report_path [file normalize [lindex $argv 6]]
set base 0x430000000
set words 1024

set data_file [open $data_path r]
set lines [split [string trim [read $data_file]] "\n"]
close $data_file
if {[llength $lines] != $words} {
    error "Expected $words backup words, received [llength $lines]"
}

set ::zu15eg_keep_connected 1
set argv $init_argv
set argc [llength $argv]
source [file join [file dirname [info script]] init_zu15eg_ps_for_pl_ddr4.tcl]

if {[llength [targets -nocase -filter {name =~ "*A53*#0"}]] == 0} {
    disconnect
    error "A53#0 target was not found after PS initialization"
}
targets -set -nocase -filter {name =~ "*A53*#0"}
configparams force-mem-access 1

for {set i 0} {$i < $words} {incr i} {
    set word [string trim [lindex $lines $i]]
    if {![regexp {^[0-9A-Fa-f]{8}$} $word]} {
        disconnect
        error "Invalid backup word at index $i: $word"
    }
    mwr [expr {$base + 4 * $i}] "0x$word"
}

set values [mrd -value $base $words]
set mismatches 0
set first_index -1
set first_expected 0
set first_actual 0
for {set i 0} {$i < $words} {incr i} {
    set expected_hex [string toupper [string trim [lindex $lines $i]]]
    scan $expected_hex %x expected
    set actual [lindex $values $i]
    # Tcl scan produces signed 32-bit integers for words with bit31 set;
    # compare canonical hexadecimal strings rather than signed numerics.
    set actual_hex [format "%08X" $actual]
    if {$actual_hex ne $expected_hex} {
        incr mismatches
        if {$first_index < 0} {
            set first_index $i
            set first_expected $expected
            set first_actual $actual
        }
    }
}

set report [open $restore_report_path w]
puts $report [format "BASE=0x%09llX" $base]
puts $report "WORDS=$words"
puts $report "MISMATCHES=$mismatches"
puts $report [format "FIRST_INDEX=0x%08X" $first_index]
puts $report [format "FIRST_EXPECTED=0x%08X" $first_expected]
puts $report [format "FIRST_ACTUAL=0x%08X" $first_actual]
if {$mismatches == 0} {
    puts $report "ZU15EG_DDR4_WINDOW_RESTORE=PASS"
} else {
    puts $report "ZU15EG_DDR4_WINDOW_RESTORE=FAIL"
}
close $report
disconnect

if {$mismatches != 0} {
    error "DDR4 restore verification failed with $mismatches mismatches"
}
