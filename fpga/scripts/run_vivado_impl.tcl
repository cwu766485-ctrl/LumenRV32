set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir .. ..]]
if {[info exists ::env(TINYRISCV_VIVADO_OUT_DIR)]} {
    set out_dir [file normalize $::env(TINYRISCV_VIVADO_OUT_DIR)]
} else {
    set out_dir [file normalize [file join $root_dir build vivado_impl]]
}
if {[info exists ::env(TINYRISCV_VIVADO_PART)]} {
    set part_name $::env(TINYRISCV_VIVADO_PART)
} else {
    set part_name xc7a35tftg256-1
}
if {[info exists ::env(TINYRISCV_VIVADO_XDC)]} {
    set xdc_file [file normalize $::env(TINYRISCV_VIVADO_XDC)]
} else {
    set xdc_file [file join $root_dir fpga constrs tinyriscv.xdc]
}
if {[info exists ::env(TINYRISCV_VIVADO_TOP)]} {
    set top_name $::env(TINYRISCV_VIVADO_TOP)
} else {
    set top_name heterogeneous_soc_top
}

file mkdir $out_dir

create_project -in_memory -part $part_name
set_property target_language Verilog [current_project]
if {[info exists ::env(TINYRISCV_VIVADO_DEFINES)]} {
    set vivado_defines [list]
    foreach define [split $::env(TINYRISCV_VIVADO_DEFINES) ",;"] {
        set define [string trim $define]
        if {$define ne ""} {
            lappend vivado_defines $define
        }
    }
    if {[llength $vivado_defines] != 0} {
        set_property verilog_define $vivado_defines [current_fileset]
    }
}

set rtl_files [list \
    [file join $root_dir rtl core clint.v] \
    [file join $root_dir rtl core csr_reg.v] \
    [file join $root_dir rtl core ctrl.v] \
    [file join $root_dir rtl core cache_ram_1r1w.v] \
    [file join $root_dir rtl core branch_predictor.v] \
    [file join $root_dir rtl core div.v] \
    [file join $root_dir rtl core ex.v] \
    [file join $root_dir rtl core ex_mem.v] \
    [file join $root_dir rtl core dcache.v] \
    [file join $root_dir rtl core icache.v] \
    [file join $root_dir rtl core id.v] \
    [file join $root_dir rtl core id_ex.v] \
    [file join $root_dir rtl core ifetch.v] \
    [file join $root_dir rtl core if_id.v] \
    [file join $root_dir rtl core mem.v] \
    [file join $root_dir rtl core mem_wb.v] \
    [file join $root_dir rtl core pc_reg.v] \
    [file join $root_dir rtl core regs.v] \
    [file join $root_dir rtl core riscv_cpu_core.v] \
    [file join $root_dir rtl interconnect native_to_axi4_master.v] \
    [file join $root_dir rtl interconnect axi4_crossbar.v] \
    [file join $root_dir rtl interconnect axi4_to_native_slave.v] \
    [file join $root_dir rtl interconnect axi4_to_apb_bridge.v] \
    [file join $root_dir rtl perips axi_lite_bridge.v] \
    [file join $root_dir rtl perips axi_lite_apb_bridge.v] \
    [file join $root_dir rtl perips apb_perips.v] \
    [file join $root_dir rtl perips ram.v] \
    [file join $root_dir rtl perips rom.v] \
    [file join $root_dir rtl perips timer.v] \
    [file join $root_dir rtl perips uart.v] \
    [file join $root_dir rtl perips gpio.v] \
    [file join $root_dir rtl perips i2c_master.v] \
    [file join $root_dir rtl perips spi.v] \
    [file join $root_dir rtl perips qspi.v] \
    [file join $root_dir rtl perips pmu.v] \
    [file join $root_dir rtl perips dma.v] \
    [file join $root_dir rtl perips external_memory_wrapper.v] \
    [file join $root_dir rtl perips axi4_extmem_bridge.v] \
    [file join $root_dir rtl perips axi4_mem_model.v] \
    [file join $root_dir rtl debug jtag_dm.v] \
    [file join $root_dir rtl debug jtag_driver.v] \
    [file join $root_dir rtl debug jtag_top.v] \
    [file join $root_dir rtl debug uart_debug.v] \
    [file join $root_dir rtl soc heterogeneous_soc_top.v] \
    [file join $root_dir fpga qspi tinyriscv_qspi_boot_top.v] \
    [file join $root_dir rtl utils full_handshake_rx.v] \
    [file join $root_dir rtl utils full_handshake_tx.v] \
    [file join $root_dir rtl utils gen_buf.v] \
    [file join $root_dir rtl utils gen_dff.v] \
]

read_verilog -sv $rtl_files
read_xdc $xdc_file

synth_design -top $top_name -part $part_name

proc one_net {pattern} {
    set nets [get_nets -hier -quiet $pattern]
    if {[llength $nets] == 0} {
        error "Debug net not found: $pattern"
    }
    return [lindex $nets 0]
}

proc bus_nets {pattern} {
    set nets [lsort -dictionary [get_nets -hier -quiet $pattern]]
    if {[llength $nets] == 0} {
        error "Debug bus not found: $pattern"
    }
    return $nets
}

proc connect_probe {probe_name nets} {
    set_property port_width [llength $nets] [get_debug_ports $probe_name]
    connect_debug_port $probe_name $nets
}

if {[info exists ::env(TINYRISCV_VIVADO_QSPI_DEBUG)] && $::env(TINYRISCV_VIVADO_QSPI_DEBUG) ne "0"} {
    create_debug_core u_ila_0 ila
    set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
    set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
    set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
    set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
    set_property C_INPUT_PIPE_STAGES 1 [get_debug_cores u_ila_0]

    connect_debug_port u_ila_0/clk [one_net *dbg_sys_clk*]
    for {set i 0} {$i < 24} {incr i} {
        create_debug_port u_ila_0 probe
    }

    connect_probe u_ila_0/probe0  [one_net *dbg_rst*]
    connect_probe u_ila_0/probe1  [bus_nets *dbg_heartbeat_msb*]
    connect_probe u_ila_0/probe2  [one_net *dbg_done*]
    connect_probe u_ila_0/probe3  [one_net *dbg_pass*]
    connect_probe u_ila_0/probe4  [one_net *dbg_fail*]
    connect_probe u_ila_0/probe5  [one_net *dbg_over*]
    connect_probe u_ila_0/probe6  [one_net *dbg_succ*]
    connect_probe u_ila_0/probe7  [bus_nets *dbg_status*]
    connect_probe u_ila_0/probe8  [one_net *dbg_qspi_seen_cs_low*]
    connect_probe u_ila_0/probe9  [one_net *dbg_qspi_seen_clk_toggle*]
    connect_probe u_ila_0/probe10 [one_net *dbg_qspi_cs_n*]
    connect_probe u_ila_0/probe11 [one_net *dbg_qspi_clk*]
    connect_probe u_ila_0/probe12 [bus_nets *dbg_qspi_rx0*]
    connect_probe u_ila_0/probe13 [bus_nets *dbg_qspi_rx1*]
    connect_probe u_ila_0/probe14 [bus_nets *dbg_qspi_rx2*]
    connect_probe u_ila_0/probe15 [bus_nets *dbg_qspi_rx_count*]
    connect_probe u_ila_0/probe16 [bus_nets *dbg_qspi_state*]
    connect_probe u_ila_0/probe17 [one_net *dbg_qspi_busy*]
    connect_probe u_ila_0/probe18 [one_net *dbg_qspi_done*]
    connect_probe u_ila_0/probe19 [one_net *dbg_qspi_error*]
    connect_probe u_ila_0/probe20 [bus_nets *dbg_qspi_cmd*]
    connect_probe u_ila_0/probe21 [bus_nets *dbg_qspi_len*]
    connect_probe u_ila_0/probe22 [one_net *dbg_qspi_mosi*]
    connect_probe u_ila_0/probe23 [one_net *dbg_qspi_miso*]
    connect_probe u_ila_0/probe24 [bus_nets *dbg_qspi_io_oe*]
}

write_checkpoint -force [file join $out_dir post_synth.dcp]
report_utilization -file [file join $out_dir post_synth_utilization.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $out_dir post_synth_timing.rpt]

opt_design
place_design
phys_opt_design
write_checkpoint -force [file join $out_dir post_place.dcp]
report_utilization -file [file join $out_dir post_place_utilization.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $out_dir post_place_timing.rpt]

route_design
write_checkpoint -force [file join $out_dir post_route.dcp]
report_utilization -file [file join $out_dir post_route_utilization.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $out_dir post_route_timing.rpt]
report_power -file [file join $out_dir post_route_power.rpt]
report_clock_utilization -file [file join $out_dir post_route_clock_utilization.rpt]
if {[info exists ::env(TINYRISCV_VIVADO_QSPI_DEBUG)] && $::env(TINYRISCV_VIVADO_QSPI_DEBUG) ne "0"} {
    write_debug_probes -force [file join $out_dir "${top_name}.ltx"]
}
if {![info exists ::env(TINYRISCV_VIVADO_SKIP_BITSTREAM)] || $::env(TINYRISCV_VIVADO_SKIP_BITSTREAM) eq "0"} {
    write_bitstream -force [file join $out_dir "${top_name}.bit"]
} else {
    puts "Skipping bitstream generation for generic implementation run"
}

close_project
