`timescale 1 ns / 1 ps

// Zynq UltraScale+ USER2 wrapper.  BSCANE2 attaches the project DMI transport
// to the board configuration JTAG cable; it does not require a separate
// FMC/PMOD four-wire connector.
module jtag_bscan2_user2 (
    input wire clk,
    input wire arst_n,
    output wire reg_we_o,
    output wire[4:0] reg_addr_o,
    output wire[31:0] reg_wdata_o,
    input wire[31:0] reg_rdata_i,
    output wire mem_we_o,
    output wire[31:0] mem_addr_o,
    output wire[31:0] mem_wdata_o,
    input wire[31:0] mem_rdata_i,
    output wire op_req_o,
    output wire halt_req_o,
    output wire reset_req_o
);
    wire capture;
    wire reset;
    wire sel;
    wire shift;
    wire tck;
    wire tdi;
    wire tms;
    wire update;
    wire tdo;
    wire transport_arst_n = arst_n & ~reset;

    BSCANE2 #(.JTAG_CHAIN(2)) u_bscan (
        .CAPTURE(capture), .DRCK(), .RESET(reset), .RUNTEST(), .SEL(sel),
        .SHIFT(shift), .TCK(tck), .TDI(tdi), .TMS(tms), .UPDATE(update),
        .TDO(tdo)
    );

    jtag_user2_dmi_transport u_transport (
        .clk(clk), .arst_n(transport_arst_n), .tck(tck), .sel_i(sel),
        .capture_i(capture), .shift_i(shift), .update_i(update), .tdi_i(tdi),
        .tdo_o(tdo), .reg_we_o(reg_we_o), .reg_addr_o(reg_addr_o),
        .reg_wdata_o(reg_wdata_o), .reg_rdata_i(reg_rdata_i),
        .mem_we_o(mem_we_o), .mem_addr_o(mem_addr_o),
        .mem_wdata_o(mem_wdata_o), .mem_rdata_i(mem_rdata_i),
        .op_req_o(op_req_o), .halt_req_o(halt_req_o), .reset_req_o(reset_req_o)
    );
endmodule
