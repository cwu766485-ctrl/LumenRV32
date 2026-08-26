# USER2 DMI client for the ZU15EG CPU-focused debug profile.
#
# This script uses XSDB's raw JTAG sequence API.  It selects the Xilinx
# BSCANE2 USER2 instruction (0x03) then sends/receives the project's 40-bit
# DMI bundle: {address[5:0], data[31:0], op[1:0]}, LSB first on the wire.
#
# Modes:
#   dmstatus : read-only DMSTATUS transport check
#   dmcontrol: read-only DMSTATUS -> DMCONTROL sequencing check
#   recover  : reset USER2 transport (releases debug halt), then DMSTATUS
#   full     : dmstatus -> halt -> abstract x5 read -> resume
#
# No reset, system-bus write, memory write, or Flash operation is implemented.
if {$argc != 1} {
    error "usage: zu15eg_user2_dmi.tcl <dmstatus|full>"
}
set mode [lindex $argv 0]
if {$mode ni {dmstatus dmcontrol recover full}} {
    error "mode must be dmstatus, dmcontrol, recover or full"
}

set DMI_BITS 40
# Zynq UltraScale+ packages USER2 in the 12-bit JTAG instruction space.
# XSDB's shipped ZynqMP SVF helper derives it as (0x24 << 6) | 0x03.
set USER2_IR 0x903
set DMSTATUS 0x11
set DMCONTROL 0x10
set COMMAND 0x17
set DATA0 0x04
set OP_NOP 0
set OP_READ 1
set OP_WRITE 2

proc dmi_bundle {addr data op} {
    return [expr {(wide($addr) << 34) | (wide($data) << 2) | $op}]
}

# XSDB's -integer input path is convenient for address-only reads, but an
# implementation-specific integer-width conversion can truncate a 40-bit DMI
# payload containing bit 31 of data (for example DMCONTROL.haltreq). Build
# the wire image explicitly instead: -bits shifts the first text bit first.
proc dmi_bits {addr data op} {
    set result {}
    for {set bit 0} {$bit < 2} {incr bit} {
        append result [expr {($op >> $bit) & 1}]
    }
    for {set bit 0} {$bit < 32} {incr bit} {
        append result [expr {(wide($data) >> $bit) & 1}]
    }
    for {set bit 0} {$bit < 6} {incr bit} {
        append result [expr {($addr >> $bit) & 1}]
    }
    return $result
}

proc dmi_addr {bundle} { return [expr {($bundle >> 34) & 0x3f}] }
proc dmi_data {bundle} { return [expr {($bundle >> 2) & 0xffffffff}] }
proc dmi_op {bundle} { return [expr {$bundle & 0x3}] }

connect
set props [jtag targets -target-properties]
set target {}
foreach candidate $props {
    if {[dict exists $candidate name] && [string match "xczu15*" [dict get $candidate name]]} {
        set target $candidate
        break
    }
}
if {$target eq ""} {
    error "xczu15 JTAG target was not found"
}
jtag targets [dict get $target node_id]
if {![dict exists $target irlen]} {
    error "selected FPGA target has no JTAG IR length"
}
set irlen [dict get $target irlen]
puts "USER2_TARGET=[dict get $target name] IRLEN=$irlen"

# Select USER2 once at session start. Do not return to TAP RESET for each DMI
# operation: BSCANE2 exposes TAP RESET to the USER2 transport and would reset
# jtag_dm, erasing a just-accepted halt request before it could be observed.
proc user2_dmi_init {irlen} {
    global USER2_IR
    set seq [jtag sequence]
    $seq state RESET 5
    $seq irshift -integer -state IDLE $irlen $USER2_IR
    $seq state IDLE 20
    $seq run
    $seq delete
}

# Submit one DMI request, then use NOP scans to capture its asynchronous
# response.  The USER2 transport explicitly ignores NOP at UPDATE_DR, so the
# response scans cannot enqueue a second DMI transaction.
proc user2_dmi_exchange {irlen request_bits request address} {
    global DMI_BITS USER2_IR
    puts [format "USER2_DMI_SUBMIT request=0x%010X expected_addr=0x%02X" $request $address]
    # Keep the request and NOP captures in one physical XSDB sequence.  On
    # this cable, splitting a sequence can expose a DR shift-register residue
    # rather than a new CAPTURE_DR value.  NOP is filtered in the USER2
    # transport, so these follow-up scans cannot create DMI work.
    set seq [jtag sequence]
    $seq state IDLE 0
    # Keep USER2 selected for every real request without entering TAP RESET.
    # Some XSDB cable backends restore the outer TAP instruction at sequence
    # boundaries; RESET would clear the transport, whereas this IR scan only
    # makes the following DR scan visible to BSCANE2 USER2.
    $seq irshift -integer -state IDLE $irlen $USER2_IR
    $seq drshift -bits -capture -state IDLE $DMI_BITS $request_bits
    for {set try 1} {$try <= 16} {incr try} {
        $seq delay 2000
        $seq drshift -bits -capture -state IDLE $DMI_BITS [string repeat 0 $DMI_BITS]
    }
    set captures [$seq run -integer]
    $seq delete
    set try 0
    foreach response [lrange $captures 1 end] {
        incr try
        puts [format "USER2_DMI_POLL try=%d response=0x%010X rsp_addr=0x%02X op=0x%X" \
              $try $response [dmi_addr $response] [dmi_op $response]]
        if {[dmi_addr $response] == $address && [dmi_op $response] == 0} {
            # The remaining NOP scans already run before this function can
            # return. Add IDLE clocks (no CAPTURE/UPDATE) so both legs of the
            # response CDC can finish their ack-low phase before the caller
            # starts a new DMI request.
            set settle [jtag sequence]
            $settle state IDLE 10000
            $settle run
            $settle delete
            return $response
        }
    }
    error [format "DMI response timeout/busy for address 0x%02X" $address]
}

user2_dmi_init $irlen

proc dmi_read {irlen address} {
    global OP_READ
    set request [dmi_bundle $address 0 $OP_READ]
    set response [user2_dmi_exchange $irlen [dmi_bits $address 0 $OP_READ] $request $address]
    puts [format "USER2_DMI_READ_DECODE response=0x%010X rsp_addr=0x%02X data=0x%08X op=0x%X" \
          $response [dmi_addr $response] [dmi_data $response] [dmi_op $response]]
    return [dmi_data $response]
}

proc dmi_write {irlen address data} {
    global OP_WRITE
    set request [dmi_bundle $address $data $OP_WRITE]
    set request_bits [dmi_bits $address $data $OP_WRITE]
    puts [format "USER2_DMI_WRITE_BITS addr=0x%02X data=0x%08X bits=%s" \
          $address $data $request_bits]
    set response [user2_dmi_exchange $irlen $request_bits $request $address]
    puts [format "USER2_DMI_WRITE addr=0x%02X data=0x%08X response=0x%010X op=0x%X" \
          $address $data $response [dmi_op $response]]
}

# Run the final acceptance sequence as one continuous outer-TAP session.
# XSDB can restore the instruction at a sequence-object boundary; keeping all
# DR scans under one USER2 selection avoids that side effect.  Every request
# gets four NOP capture scans, which are filtered by the USER2 transport.  The
# resume request is scheduled unconditionally, so a response-check failure
# cannot leave the CPU halted.
proc user2_full_acceptance {irlen} {
    global DMI_BITS USER2_IR DMSTATUS DMCONTROL COMMAND DATA0 OP_READ OP_WRITE
    set actions [list \
        [list $DMSTATUS 0 $OP_READ] \
        [list $DMCONTROL 0x80010001 $OP_WRITE] \
        [list $DMSTATUS 0 $OP_READ] \
        [list $COMMAND 0x00001005 $OP_WRITE] \
        [list $DATA0 0 $OP_READ] \
        [list $DMCONTROL 0x40010001 $OP_WRITE] \
        [list $DMSTATUS 0 $OP_READ]]
    set seq [jtag sequence]
    $seq state RESET 5
    $seq irshift -integer -state IDLE $irlen $USER2_IR
    $seq state IDLE 20
    foreach action $actions {
        lassign $action address data op
        $seq drshift -bits -capture -state IDLE $DMI_BITS [dmi_bits $address $data $op]
        for {set drain 0} {$drain < 4} {incr drain} {
            $seq delay 2000
            $seq drshift -bits -capture -state IDLE $DMI_BITS [string repeat 0 $DMI_BITS]
        }
    }
    set captures [$seq run -integer]
    $seq delete

    set responses {}
    set action_index 0
    foreach action $actions {
        lassign $action address data op
        set start [expr {$action_index * 5 + 1}]
        set response -1
        foreach candidate [lrange $captures $start [expr {$start + 3}]] {
            if {[dmi_addr $candidate] == $address && [dmi_op $candidate] == 0} {
                set response $candidate
                break
            }
        }
        if {$response == -1} {
            error [format "full-sequence response missing for address 0x%02X" $address]
        }
        puts [format "USER2_FULL_RESPONSE addr=0x%02X data=0x%08X" \
              $address [dmi_data $response]]
        lappend responses [dmi_data $response]
        incr action_index
    }
    return $responses
}

if {$mode eq "full"} {
    set values [user2_full_acceptance $irlen]
    lassign $values initial_status halt_ack halted_status command_ack x5 resume_ack running_status
    puts [format "USER2_DMSTATUS=0x%08X" $initial_status]
    if {(($initial_status >> 8) & 0xf) != 0xc} {
        error [format "initial DMSTATUS is not ALLRUNNING/ANYRUNNING: 0x%08X" $initial_status]
    }
    if {(($halted_status >> 8) & 0xf) != 0x3} {
        error [format "halt did not produce ALLHALTED/ANYHALTED: 0x%08X" $halted_status]
    }
    puts [format "USER2_GPR_X5=0x%08X" $x5]
    if {(($running_status >> 8) & 0xf) != 0xc} {
        error [format "resume did not produce ALLRUNNING/ANYRUNNING: 0x%08X" $running_status]
    }
    puts "USER2_HALT_GPR_READ_RESUME_PASS"
    disconnect
    exit 0
}

set dmstatus [dmi_read $irlen $DMSTATUS]
puts [format "USER2_DMSTATUS=0x%08X" $dmstatus]
if {$mode eq "dmstatus"} {
    puts "USER2_DMSTATUS_PASS"
    disconnect
    exit 0
}
if {$mode eq "dmcontrol"} {
    set dmcontrol [dmi_read $irlen $DMCONTROL]
    puts [format "USER2_DMCONTROL=0x%08X" $dmcontrol]
    puts "USER2_READ_SEQUENCE_PASS"
    disconnect
    exit 0
}
if {$mode eq "recover"} {
    # user2_dmi_init has asserted/deasserted BSCANE2.RESET, resetting only
    # the DMI transport. jtag_dm reset deasserts dm_halt_req; it is not the
    # CPU reset request output and does not modify architectural state.
    if {(($dmstatus >> 8) & 0xf) != 0xc} {
        error [format "transport recovery did not release debug halt: 0x%08X" $dmstatus]
    }
    puts "USER2_RECOVER_RUNNING_PASS"
    disconnect
    exit 0
}
