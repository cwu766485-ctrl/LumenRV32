if {$argc != 7} {
    error "usage: run_zu15eg_qspi_read_id.tcl <fsbl.elf> <design.xsa> <psu_init.tcl> <pmufw.elf> <init-report.txt> <read-id.elf> <report.txt>"
}
# A prior manual-start transaction can leave the QSPI controller stateful.
# Start this dedicated read-only acceptance from a fresh PS state; this does
# reset PL configuration, but does not write the Flash device.
set init_argv [list [lindex $argv 0] [lindex $argv 1] [lindex $argv 2] [lindex $argv 3] [lindex $argv 4] 0 0]
set elf [file normalize [lindex $argv 5]]
set board_report_path [file normalize [lindex $argv 6]]
set ::zu15eg_keep_connected 1
set argv $init_argv
set argc [llength $argv]
source [file join [file dirname [info script]] init_zu15eg_ps_for_pl_ddr4.tcl]

targets -set -nocase -filter {name =~ "*A53*#0"}
configparams force-mem-access 1
rst -processor
dow $elf
set done_bp [bpadd -addr &qspi_read_id_done]
con -block -timeout 15
bpremove $done_bp

set magic [mrd -value 0xFFFE0000]
set state [mrd -value 0xFFFE0004]
set driver_status [mrd -value 0xFFFE0008]
set flash_id [mrd -value 0xFFFE000C]
set passed [expr {$magic == 0x51535049 && $state == 0x50415353 && $driver_status == 0 && $flash_id != 0 && $flash_id != 0xFFFFFF}]
set report [open $board_report_path w]
puts $report [format "MAGIC=0x%08X" $magic]
puts $report [format "STATE=0x%08X" $state]
puts $report [format "DRIVER_STATUS=0x%08X" $driver_status]
puts $report [format "FLASH_JEDEC_ID=0x%06X" $flash_id]
puts $report "QSPI_OPERATION=READ_JEDEC_ID_ONLY"
set result [expr {$passed ? "PASS" : "FAIL"}]
puts $report "ZU15EG_PS_QSPI_READ_ID=$result"
close $report
disconnect
if {!$passed} { error "ZU15EG PS QSPI read-ID reported failure" }
