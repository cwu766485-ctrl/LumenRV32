`timescale 1 ns / 1 ps

`include "defines.v"

// Replaceable cache data RAM.
//
// Default implementation keeps the original cache behavior:
// - asynchronous read
// - synchronous write
//
// This wrapper is the boundary for later FPGA/ASIC memory replacement:
// - FPGA: replace this module body with BRAM/URAM inference or primitive/IP.
// - ASIC: replace this module body with a memory-compiler SRAM macro wrapper.
module cache_ram_1r1w #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter DEPTH = 256,
    // 0: asynchronous LUTRAM/ASIC-compatible read, preserving the legacy
    //    zero-wait cache-hit path.
    // 1: synchronous read that Vivado can infer as Xilinx block RAM.  Cache
    //    control must absorb the one-cycle read response latency.
    parameter READ_LATENCY = 0
)(
    input wire clk,
    input wire rst,

    input wire[ADDR_WIDTH - 1:0] raddr_i,
    output wire[DATA_WIDTH - 1:0] rdata_o,

    input wire we_i,
    input wire[ADDR_WIDTH - 1:0] waddr_i,
    input wire[DATA_WIDTH - 1:0] wdata_i
);

    generate
        if (READ_LATENCY == 0) begin : g_async_lutram
            (* ram_style = "distributed" *) reg[DATA_WIDTH - 1:0] mem[0:DEPTH - 1];

            assign rdata_o = mem[raddr_i];

            always @ (posedge clk) begin
                if (we_i == `WriteEnable) begin
                    mem[waddr_i] <= wdata_i;
                end
            end
        end else begin : g_sync_bram
            // Xilinx BRAM has a registered read port.  Keeping this branch in
            // generic RTL also makes the one-cycle latency explicit for ASIC
            // SRAM wrapper replacement.
            (* ram_style = "block" *) reg[DATA_WIDTH - 1:0] mem[0:DEPTH - 1];
            reg[DATA_WIDTH - 1:0] rdata_r;

            assign rdata_o = rdata_r;

            always @ (posedge clk) begin
                if (we_i == `WriteEnable) begin
                    mem[waddr_i] <= wdata_i;
                end
                rdata_r <= mem[raddr_i];
            end
        end
    endgenerate

endmodule
