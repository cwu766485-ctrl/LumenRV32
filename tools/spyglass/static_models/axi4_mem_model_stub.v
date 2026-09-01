`timescale 1 ns / 1 ps

// Structural-only replacement for rtl/perips/axi4_mem_model.v.
//
// The functional model contains a 64K-word behavioural memory and is needed
// by simulation.  CDC/RDC analyze clock/reset topology, not memory contents;
// elaborating that array makes the static run slow without adding crossing
// coverage.  The runner uses this port-compatible stub only for cdc/rdc.
// It must never be used by simulation, synthesis, FPGA, or ASIC flows.
module axi4_mem_model #(
    parameter DEPTH_WORDS = 65536,
    parameter WAIT_CYCLES = 4
)(
    input wire clk,
    input wire rst,

    input wire[3:0] s_axi_awid,
    input wire[31:0] s_axi_awaddr,
    input wire[7:0] s_axi_awlen,
    input wire[2:0] s_axi_awsize,
    input wire[1:0] s_axi_awburst,
    input wire s_axi_awvalid,
    output wire s_axi_awready,

    input wire[31:0] s_axi_wdata,
    input wire[3:0] s_axi_wstrb,
    input wire s_axi_wlast,
    input wire s_axi_wvalid,
    output wire s_axi_wready,

    output wire[3:0] s_axi_bid,
    output wire[1:0] s_axi_bresp,
    output wire s_axi_bvalid,
    input wire s_axi_bready,

    input wire[3:0] s_axi_arid,
    input wire[31:0] s_axi_araddr,
    input wire[7:0] s_axi_arlen,
    input wire[2:0] s_axi_arsize,
    input wire[1:0] s_axi_arburst,
    input wire s_axi_arvalid,
    output wire s_axi_arready,

    output wire[3:0] s_axi_rid,
    output wire[31:0] s_axi_rdata,
    output wire[1:0] s_axi_rresp,
    output wire s_axi_rlast,
    output wire s_axi_rvalid,
    input wire s_axi_rready
);
    assign s_axi_awready = 1'b0;
    assign s_axi_wready  = 1'b0;
    assign s_axi_bid     = 4'b0;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = 1'b0;
    assign s_axi_arready = 1'b0;
    assign s_axi_rid     = 4'b0;
    assign s_axi_rdata   = 32'b0;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rlast   = 1'b0;
    assign s_axi_rvalid  = 1'b0;
endmodule
