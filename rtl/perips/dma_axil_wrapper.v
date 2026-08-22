`timescale 1 ns / 1 ps

/*
SPDX-License-Identifier: Apache-2.0

Project-specific implementation for heterogeneous_soc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

`include "../core/defines.v"

// AXI4-Lite configuration wrapper for the existing DMA engine.
//
// The DMA data mover is intentionally unchanged: it still issues native memory
// master requests through mem_* ports.  This wrapper only replaces the legacy
// APB-style register access with a standard AXI4-Lite slave interface.
module dma_axil_wrapper(

    input wire clk,
    input wire rst,

    input wire[`MemAddrBus] s_axi_awaddr,
    input wire s_axi_awvalid,
    output reg s_axi_awready,
    input wire[`MemBus] s_axi_wdata,
    input wire[3:0] s_axi_wstrb,
    input wire s_axi_wvalid,
    output reg s_axi_wready,
    output reg[1:0] s_axi_bresp,
    output reg s_axi_bvalid,
    input wire s_axi_bready,

    input wire[`MemAddrBus] s_axi_araddr,
    input wire s_axi_arvalid,
    output reg s_axi_arready,
    output reg[`MemBus] s_axi_rdata,
    output reg[1:0] s_axi_rresp,
    output reg s_axi_rvalid,
    input wire s_axi_rready,

    output wire[`MemAddrBus] mem_addr_o,
    output wire[`MemBus] mem_data_o,
    output wire[`MemMaskBus] mem_wmask_o,
    output wire mem_req_o,
    output wire mem_we_o,
    input wire[`MemBus] mem_data_i,
    input wire mem_ready_i,

    output wire busy_o,
    output wire done_o,
    output wire error_o,
    output wire irq_o

    );

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_W_APPLY = 3'd1;
    localparam [2:0] ST_W_RESP = 3'd2;
    localparam [2:0] ST_R_RESP = 3'd3;

    reg[2:0] state_r;
    reg aw_seen_r;
    reg w_seen_r;
    reg[`MemAddrBus] awaddr_r;
    reg[`MemBus] wdata_r;
    reg[3:0] wstrb_r;
    reg[`MemAddrBus] dma_addr_r;
    reg[`MemBus] dma_wdata_r;
    reg dma_we_r;
    wire[`MemBus] dma_rdata;

    function [`MemBus] apply_strb;
        input [`MemBus] prior;
        input [`MemBus] next;
        input [3:0] strb;
        begin
            apply_strb = prior;
            if (strb[0]) apply_strb[7:0] = next[7:0];
            if (strb[1]) apply_strb[15:8] = next[15:8];
            if (strb[2]) apply_strb[23:16] = next[23:16];
            if (strb[3]) apply_strb[31:24] = next[31:24];
        end
    endfunction

    dma u_dma(
        .clk(clk),
        .rst(rst),
        .we_i(dma_we_r),
        .addr_i(dma_addr_r),
        .data_i(dma_wdata_r),
        .data_o(dma_rdata),
        .mem_addr_o(mem_addr_o),
        .mem_data_o(mem_data_o),
        .mem_wmask_o(mem_wmask_o),
        .mem_req_o(mem_req_o),
        .mem_we_o(mem_we_o),
        .mem_data_i(mem_data_i),
        .mem_ready_i(mem_ready_i),
        .busy_o(busy_o),
        .done_o(done_o),
        .error_o(error_o),
        .irq_o(irq_o)
    );

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state_r <= ST_IDLE;
            aw_seen_r <= 1'b0;
            w_seen_r <= 1'b0;
            awaddr_r <= `ZeroWord;
            wdata_r <= `ZeroWord;
            wstrb_r <= 4'h0;
            dma_addr_r <= `ZeroWord;
            dma_wdata_r <= `ZeroWord;
            dma_we_r <= 1'b0;
            s_axi_awready <= 1'b1;
            s_axi_wready <= 1'b1;
            s_axi_bresp <= 2'b00;
            s_axi_bvalid <= 1'b0;
            s_axi_arready <= 1'b1;
            s_axi_rdata <= `ZeroWord;
            s_axi_rresp <= 2'b00;
            s_axi_rvalid <= 1'b0;
        end else begin
            dma_we_r <= 1'b0;

            case (state_r)
                ST_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready <= 1'b1;
                    s_axi_arready <= 1'b1;

                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                    end
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                    end

                    if (s_axi_awvalid && s_axi_awready) begin
                        awaddr_r <= s_axi_awaddr;
                        aw_seen_r <= 1'b1;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        wdata_r <= s_axi_wdata;
                        wstrb_r <= s_axi_wstrb;
                        w_seen_r <= 1'b1;
                    end

                    if (s_axi_arvalid && s_axi_arready &&
                        !(aw_seen_r || w_seen_r || s_axi_awvalid || s_axi_wvalid)) begin
                        dma_addr_r <= s_axi_araddr;
                        s_axi_awready <= 1'b0;
                        s_axi_wready <= 1'b0;
                        s_axi_arready <= 1'b0;
                        state_r <= ST_R_RESP;
                    end else if ((aw_seen_r || (s_axi_awvalid && s_axi_awready)) &&
                                 (w_seen_r || (s_axi_wvalid && s_axi_wready))) begin
                        dma_addr_r <= (s_axi_awvalid && s_axi_awready) ? s_axi_awaddr : awaddr_r;
                        if (s_axi_wvalid && s_axi_wready) begin
                            wdata_r <= s_axi_wdata;
                            wstrb_r <= s_axi_wstrb;
                        end
                        aw_seen_r <= 1'b0;
                        w_seen_r <= 1'b0;
                        s_axi_awready <= 1'b0;
                        s_axi_wready <= 1'b0;
                        s_axi_arready <= 1'b0;
                        state_r <= ST_W_APPLY;
                    end
                end
                ST_W_APPLY: begin
                    dma_wdata_r <= apply_strb(dma_rdata, wdata_r, wstrb_r);
                    dma_we_r <= 1'b1;
                    s_axi_bresp <= 2'b00;
                    s_axi_bvalid <= 1'b1;
                    state_r <= ST_W_RESP;
                end
                ST_W_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        s_axi_awready <= 1'b1;
                        s_axi_wready <= 1'b1;
                        s_axi_arready <= 1'b1;
                        state_r <= ST_IDLE;
                    end
                end
                ST_R_RESP: begin
                    if (!s_axi_rvalid) begin
                        s_axi_rdata <= dma_rdata;
                        s_axi_rresp <= 2'b00;
                        s_axi_rvalid <= 1'b1;
                    end else if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        s_axi_awready <= 1'b1;
                        s_axi_wready <= 1'b1;
                        s_axi_arready <= 1'b1;
                        state_r <= ST_IDLE;
                    end
                end
                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
