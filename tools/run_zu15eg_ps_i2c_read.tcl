if {$argc != 7} {
    error "usage: run_zu15eg_ps_i2c_read.tcl <fsbl.elf> <design.xsa> <psu_init.tcl> <pmufw.elf> <init-report.txt> <read.elf> <report.txt>"
}
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
set done_bp [bpadd -addr &ps_i2c_read_done]
con -block -timeout 15
bpremove $done_bp
set magic [mrd -value 0xFFFE0000]
set state [mrd -value 0xFFFE0004]
set stage [mrd -value 0xFFFE0008]
set driver_status [mrd -value 0xFFFE000C]
set eeprom_byte0 [mrd -value 0xFFFE0010]
set passed [expr {$magic == 0x49324331 && $state == 0x50415353 && $stage == 6 && $driver_status == 0}]
set result [expr {$passed ? "PASS" : "FAIL"}]
set report [open $board_report_path w]
puts $report [format "MAGIC=0x%08X" $magic]
puts $report [format "STATE=0x%08X" $state]
puts $report "STAGE=$stage"
puts $report [format "DRIVER_STATUS=0x%08X" $driver_status]
puts $report [format "EEPROM_BYTE0=0x%02X" $eeprom_byte0]
puts $report "I2C_OPERATION=PCA9548A_CH0_VOLATILE_SELECT_PLUS_M24C02_READ_ONLY"
puts $report "ZU15EG_PS_I2C_EEPROM_READ=$result"
close $report
disconnect
if {!$passed} { error "ZU15EG PS I2C read reported failure" }
