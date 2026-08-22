if {$argc != 7} {
    error "usage: init_zu15eg_ps_for_pl_ddr4.tcl <fsbl.elf> <design.xsa> <psu_init.tcl> <pmufw.elf> <report.txt> <skip_system_reset> <reset_only>"
}
set fsbl [file normalize [lindex $argv 0]]
set xsa [file normalize [lindex $argv 1]]
set psu_init [file normalize [lindex $argv 2]]
set pmufw [file normalize [lindex $argv 3]]
set report_path [file normalize [lindex $argv 4]]
set skip_system_reset [lindex $argv 5]
set reset_only [lindex $argv 6]
set report [open $report_path w]

connect -url tcp:127.0.0.1:3121
set roots [targets -filter {level == 0}]
puts $report "ROOT_TARGETS=$roots"
set apus [targets -nocase -filter {name =~ "APU*"}]
puts $report "APU_TARGETS=$apus"
if {[llength $roots] == 0 || [llength $apus] == 0} {
    close $report
    error "Required XSCT root/APU target was not found"
}
targets -set [lindex $apus 0]
if {!$skip_system_reset} {
    rst -system
    after 3000
    puts $report "ZU15EG_SYSTEM_RESET=PASS"
}
if {$reset_only} {
    puts $report "ZU15EG_RESET_ONLY=PASS"
    close $report
    disconnect
    exit
}

# A bare FSBL download is insufficient after a cold power-on: PMU firmware
# and the exported PS initialization sequence must run before A53 memory
# accesses and DDR window backup are considered valid.
# Some JTAG servers expose only the PMU management node, not the executable
# MicroBlaze PMU context.  Download PMUFW only when that executable context is
# present; the latter case is handled by the board boot path and recorded as
# skipped rather than being mislabeled as a PMUFW PASS.
set pmu_cpus [targets -nocase -filter {name =~ "*MicroBlaze PMU*"}]
if {[llength $pmu_cpus] > 0} {
    targets -set [lindex $pmu_cpus 0]
    dow $pmufw
    con
    after 500
    puts $report "ZU15EG_PMUFW_INIT=PASS"
} else {
    puts $report "ZU15EG_PMUFW_INIT=SKIPPED_NO_MICROBLAZE_TARGET"
}

set psus [targets -nocase -filter {name =~ "PSU"}]
if {[llength $psus] == 0} {
    close $report
    error "PSU target was not found"
}
targets -set [lindex $psus 0]
source $psu_init
psu_init
psu_ps_pl_isolation_removal
puts $report "ZU15EG_PSU_INIT=PASS"

# `loadhw` must be associated with the APU target so that XSCT installs the
# exported PL DDR address ranges for the following A53 debug accesses.
targets -set -nocase -filter {name =~ "APU*"}
loadhw -hw $xsa -mem-ranges [list {0x80000000 0xbfffffff} {0x400000000 0x5ffffffff} {0x1000000000 0x7fffffffff}] -regs
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor
dow $fsbl
set fsbl_bp [bpadd -addr &XFsbl_Exit]
con -block -timeout 60
bpremove $fsbl_bp
catch {stop}
after 100
if {[catch {mrd -value 0xff5e0200} debug_access_error]} {
    close $report
    error "A53 debug access was not ready after FSBL: $debug_access_error"
}
puts $report "ZU15EG_A53_DEBUG_ACCESS=PASS"
puts $report "ZU15EG_PS_FSBL_INIT=PASS"
close $report
if {![info exists ::zu15eg_keep_connected] || !$::zu15eg_keep_connected} {
    disconnect
}
