open_hw_manager
connect_hw_server
set targets [get_hw_targets]
puts "HW_TARGET_COUNT=[llength $targets]"
foreach target $targets {
    puts "HW_TARGET=$target"
}
if {[llength $targets] == 0} {
    puts "ERROR: no hardware targets found"
    exit 2
}
open_hw_target [lindex $targets 0]
set devices [get_hw_devices]
puts "HW_DEVICE_COUNT=[llength $devices]"
foreach dev $devices {
    puts "HW_DEVICE=$dev PART=[get_property PART $dev]"
}
if {[llength $devices] == 0} {
    puts "ERROR: no hardware devices found"
    exit 3
}
close_hw_target
disconnect_hw_server
exit 0
