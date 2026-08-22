# Back up or restore the 4 KiB PL DDR window used by the SoC smoke.
# PS view: 0x4_3000_0000; SoC view: 0x3000_0000.

if {$argc != 4} {
    error "usage: manage_zu15eg_ddr4_window.tcl <backup|restore> <data.txt> <report.txt> <design.xsa>"
}
set mode [lindex $argv 0]
set data_path [file normalize [lindex $argv 1]]
set report_path [file normalize [lindex $argv 2]]
set xsa [file normalize [lindex $argv 3]]
set base 0x430000000
set words 1024

connect -url tcp:127.0.0.1:3121
set roots [targets -filter {level == 0}]
if {[llength $roots] == 0} {
    disconnect
    error "XSCT root target was not found"
}
targets -set [lindex $roots 0]
loadhw -hw $xsa -mem-ranges [list {0x80000000 0xbfffffff} {0x400000000 0x5ffffffff} {0x1000000000 0x7fffffffff}] -regs
set psus [targets -nocase -filter {name =~ "PSU"}]
if {[llength $psus] == 0} {
    disconnect
    error "PSU target was not found"
}
# Use the DAP-backed PSU target rather than A53 instruction injection.  The
# latter may expose EDITR-not-ready after a fresh XSCT reconnect although PS
# memory access itself is valid.
targets -set [lindex $psus 0]
configparams force-mem-access 1

set report [open $report_path w]
puts $report [format "BASE=0x%09llX" $base]
puts $report "WORDS=$words"

if {$mode eq "backup"} {
    set values [mrd -value $base $words]
    if {[llength $values] != $words} {
        close $report
        disconnect
        error "Expected $words words, received [llength $values]"
    }
    set data [open $data_path w]
    foreach value $values {
        puts $data [format "%08X" $value]
    }
    close $data
    puts $report "ZU15EG_DDR4_WINDOW_BACKUP=PASS"
} elseif {$mode eq "restore"} {
    if {![file exists $data_path]} {
        close $report
        disconnect
        error "Backup data not found: $data_path"
    }
    set data [open $data_path r]
    set values [list]
    while {[gets $data line] >= 0} {
        set line [string trim $line]
        if {$line eq ""} { continue }
        if {[scan $line %x value] != 1} {
            close $data
            close $report
            disconnect
            error "Invalid backup word: $line"
        }
        lappend values $value
    }
    close $data
    if {[llength $values] != $words} {
        close $report
        disconnect
        error "Backup contains [llength $values] words, expected $words"
    }
    for {set i 0} {$i < $words} {incr i} {
        mwr [expr {$base + $i * 4}] [lindex $values $i]
    }
    set verify [mrd -value $base $words]
    set fail_index -1
    for {set i 0} {$i < $words} {incr i} {
        # XSCT may return a word as a signed Tcl integer while scan %x creates
        # an unsigned/bignum value.  Compare the same 32-bit bit pattern.
        set expected [expr {[lindex $values $i] & 0xffffffff}]
        set actual [expr {[lindex $verify $i] & 0xffffffff}]
        if {$actual != $expected} {
            set fail_index $i
            break
        }
    }
    puts $report "RESTORE_FAIL_INDEX=$fail_index"
    if {$fail_index >= 0} {
        puts $report [format "EXPECTED=0x%08X" $expected]
        puts $report [format "ACTUAL=0x%08X" $actual]
        puts $report "ZU15EG_DDR4_WINDOW_RESTORE=FAIL"
        close $report
        disconnect
        error "DDR4 window restore verification failed"
    }
    puts $report "ZU15EG_DDR4_WINDOW_RESTORE=PASS"
} else {
    close $report
    disconnect
    error "Unsupported mode: $mode"
}

close $report
disconnect
