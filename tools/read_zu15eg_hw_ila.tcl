if {$argc != 2} {
    error "usage: read_zu15eg_hw_ila.tcl <probes.ltx> <report.txt>"
}
set probes [file normalize [lindex $argv 0]]
set report_path [file normalize [lindex $argv 1]]
open_hw_manager
connect_hw_server -allow_non_jtag
set report [open $report_path w]
set found 0
foreach target [get_hw_targets] {
    if {[catch {open_hw_target $target}]} { continue }
    foreach device [get_hw_devices] {
        if {![string match "xczu15*" [get_property PART $device]]} { continue }
        current_hw_device $device
        set_property PROBES.FILE $probes $device
        refresh_hw_device $device
        foreach ila [get_hw_ilas -of_objects $device] {
            incr found
            puts $report "ILA=$ila"
            foreach probe [get_hw_probes -of_objects $ila] {
                puts $report "PROBE=[get_property NAME $probe]"
            }
        }
    }
}
puts $report "ILA_COUNT=$found"
close $report
close_hw_manager
if {$found == 0} { error "No ILA found on xczu15; bitstream may not be configured" }
