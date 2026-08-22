open_hw_manager
connect_hw_server -allow_non_jtag

set report_path [file normalize [file join [pwd] build zu15eg_jtag_probe.txt]]
set report_file [open $report_path w]

set target_count 0
set device_count 0
foreach target [get_hw_targets] {
    incr target_count
    puts "ZU15EG_JTAG_TARGET=$target"
    puts $report_file "ZU15EG_JTAG_TARGET=$target"
    catch {set_property PARAM.FREQUENCY 1000000 $target}
    if {[catch {open_hw_target $target} open_error]} {
        puts "ZU15EG_JTAG_OPEN_ERROR=$open_error"
    }
}

foreach device [get_hw_devices] {
    incr device_count
    current_hw_device $device
    refresh_hw_device -update_hw_probes false $device
    puts "ZU15EG_JTAG_DEVICE=$device PART=[get_property PART $device]"
    puts $report_file "ZU15EG_JTAG_DEVICE=$device PART=[get_property PART $device]"
}

puts "ZU15EG_JTAG_SUMMARY targets=$target_count devices=$device_count"
puts $report_file "ZU15EG_JTAG_SUMMARY targets=$target_count devices=$device_count"
close $report_file
if {$device_count == 0} {
    error "No FPGA device detected in the JTAG chain"
}
close_hw_manager
