# Generic 50 MHz timing constraint for cross-device synthesis / implementation.
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports {clk}]
