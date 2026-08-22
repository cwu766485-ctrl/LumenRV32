# Temporary PL configuration over the ZynqMP PS TAP.  This does not touch QSPI.
if {$argc != 1} {
    error "usage: program_zu15eg_xsct.tcl <bitstream>"
}
set bitstream [file normalize [lindex $argv 0]]
if {![file exists $bitstream]} {
    error "bitstream not found: $bitstream"
}
connect -url tcp:127.0.0.1:3121
set ps_taps [targets -filter {name =~ "PS TAP"}]
if {[llength $ps_taps] == 0} {
    disconnect
    error "PS TAP target was not found"
}
targets -set [lindex $ps_taps 0]
fpga -file $bitstream
puts "ZU15EG_XSCT_PROGRAM=PASS BITSTREAM=$bitstream"
disconnect
