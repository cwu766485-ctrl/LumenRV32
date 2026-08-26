if {$argc != 1} {
    error "usage: program_zu15eg_bitstream.tcl <bitstream>"
}

set bitstream [file normalize [lindex $argv 0]]
if {![file exists $bitstream]} {
    error "bitstream not found: $bitstream"
}

open_hw_manager
connect_hw_server -allow_non_jtag

set programmed 0
foreach target [get_hw_targets] {
    catch {set_property PARAM.FREQUENCY 1000000 $target}
    if {[catch {open_hw_target $target}]} {
        continue
    }
    foreach device [get_hw_devices] {
        if {[string match "xczu15*" [get_property PART $device]]} {
            current_hw_device $device
            # An unconfigured ZU device can block indefinitely in an explicit
            # pre-program refresh. PROGRAM.FILE/program_hw_devices does not
            # require a pre-refresh, so assign the image directly and leave
            # the optional state refresh to a subsequent read-only probe.
            set_property PROGRAM.FILE $bitstream $device
            program_hw_devices $device
            puts "ZU15EG_PROGRAMMED device=$device bitstream=$bitstream"
            set programmed 1
            break
        }
    }
    if {$programmed} { break }
}

close_hw_manager
if {!$programmed} {
    error "xczu15 device not found or target could not be opened"
}
