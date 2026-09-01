`timescale 1 ns / 1 ps

// Focused structural-analysis top for the raw JTAG DMI transport.
//
// This is intentionally not a functional SoC or FPGA top.  It retains the
// real TCK-domain driver, CPU-domain debug module, four-phase CDC channels,
// and reset synchronizers while tying off architectural debug targets.  It
// makes CDC/RDC iterations fast and isolates JTAG findings from the large
// cache/memory model.  Full-SoC cdc/rdc remains a separate, slower profile.
module jtag_dmi_static_top (
    input wire clk,
    input wire rst,
    input wire jtag_TCK,
    input wire jtag_TMS,
    input wire jtag_TDI,
    output wire jtag_TDO,
    output wire debug_activity_o
);
    wire reg_we_unused;
    wire[4:0] reg_addr_unused;
    wire[31:0] reg_wdata_unused;
    wire mem_we_unused;
    wire[31:0] mem_addr_unused;
    wire[31:0] mem_wdata_unused;
    wire op_req_unused;
    wire halt_req_unused;
    wire reset_req_unused;
    wire dm_resp_idle_unused;

    jtag_top #(
        .DMI_ADDR_BITS(6),
        .DMI_DATA_BITS(32),
        .DMI_OP_BITS(2)
    ) u_jtag_top (
        .clk(clk),
        .jtag_rst_n(rst),
        .jtag_pin_TCK(jtag_TCK),
        .jtag_pin_TMS(jtag_TMS),
        .jtag_pin_TDI(jtag_TDI),
        .jtag_pin_TDO(jtag_TDO),
        .reg_we_o(reg_we_unused),
        .reg_addr_o(reg_addr_unused),
        .reg_wdata_o(reg_wdata_unused),
        .reg_rdata_i(32'b0),
        .mem_we_o(mem_we_unused),
        .mem_addr_o(mem_addr_unused),
        .mem_wdata_o(mem_wdata_unused),
        .mem_rdata_i(32'b0),
        .op_req_o(op_req_unused),
        .halt_req_o(halt_req_unused),
        .reset_req_o(reset_req_unused),
        .dm_resp_idle_o(dm_resp_idle_unused)
    );

    // Keep debug outputs observable to lint without creating a functional
    // sink. This port is only present in the static-analysis wrapper.
    assign debug_activity_o = reg_we_unused ^ reg_addr_unused[0] ^
                              reg_wdata_unused[0] ^ mem_we_unused ^
                              mem_addr_unused[0] ^ mem_wdata_unused[0] ^
                              op_req_unused ^ halt_req_unused ^ reset_req_unused ^
                              dm_resp_idle_unused;
endmodule
