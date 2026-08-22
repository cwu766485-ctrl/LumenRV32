if {$argc != 5} {
    error "usage: capture_zu15eg_pl_ddr4_calib.tcl <bitstream> <probes.ltx> <out.csv> <skip_program> <immediate>"
}

set bitstream [file normalize [lindex $argv 0]]
set probes [file normalize [lindex $argv 1]]
set out_csv [file normalize [lindex $argv 2]]
set skip_program [lindex $argv 3]
set immediate [lindex $argv 4]
foreach required_file [list $bitstream $probes] {
    if {![file exists $required_file]} {
        error "file not found: $required_file"
    }
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
            set_property PROBES.FILE $probes $device
            if {!$skip_program} {
                set_property PROGRAM.FILE $bitstream $device
                program_hw_devices $device
            }
            refresh_hw_device $device
            set programmed 1
            break
        }
    }
    if {$programmed} { break }
}
if {!$programmed} {
    close_hw_manager
    error "xczu15 device not found or target could not be opened"
}

# Wait for the DDR4 controller to leave reset before arming the one-bit ILA.
after 10000
set ila [lindex [get_hw_ilas -of_objects $device] 0]
if {$ila eq ""} {
    close_hw_manager
    error "DDR4 ILA was not found"
}
puts "ZU15EG_DDR4_ILA=$ila"
puts "ZU15EG_DDR4_ILA_PROBES=[get_hw_probes -of_objects $ila]"
if {[catch {
    if {$immediate} {
        run_hw_ila -trigger_now $ila
    } else {
        set probe [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*init_calib_complete*"}] 0]
        if {$probe eq ""} {
            error "init_calib_complete probe was not found"
        }
        set_property CONTROL.TRIGGER_POSITION 1 $ila
        set_property TRIGGER_COMPARE_VALUE "eq1'b1" $probe
        run_hw_ila $ila
    }
    wait_on_hw_ila $ila
    set data [upload_hw_ila_data $ila]
    write_hw_ila_data -force -csv_file $out_csv $data
} capture_error capture_options]} {
    catch {close_hw_manager}
    return -options $capture_options $capture_error
}
puts "ZU15EG_PL_DDR4_CALIB_CAPTURE=$out_csv"
close_hw_manager
