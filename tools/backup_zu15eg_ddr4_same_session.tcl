# Run PS initialization and the read-only DDR window backup in one XSCT
# session.  This avoids reconnecting through an A53 EDITR context after FSBL.
if {$argc != 7} {
    error "usage: backup_zu15eg_ddr4_same_session.tcl <fsbl.elf> <design.xsa> <psu_init.tcl> <pmufw.elf> <init-report.txt> <data.txt> <backup-report.txt>"
}
# The caller must reset PS before configuring the PL MIG image.  Do not issue
# another system reset here, because it can clear that volatile PL image.
set init_argv [list [lindex $argv 0] [lindex $argv 1] [lindex $argv 2] [lindex $argv 3] [lindex $argv 4] 1 0]
set data_path [file normalize [lindex $argv 5]]
set backup_report_path [file normalize [lindex $argv 6]]
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
set base 0x430000000
set words 1024
set values [mrd -value $base $words]
if {[llength $values] != $words} {
    disconnect
    error "Expected $words words, received [llength $values]"
}
set data [open $data_path w]
foreach value $values {
    puts $data [format "%08X" $value]
}
close $data
set backup_report [open $backup_report_path w]
puts $backup_report [format "BASE=0x%09llX" $base]
puts $backup_report "WORDS=$words"
puts $backup_report "ZU15EG_DDR4_WINDOW_BACKUP=PASS"
close $backup_report
disconnect
