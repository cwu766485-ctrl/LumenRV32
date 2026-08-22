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

// Single-outstanding AXI-Lite slave to APB master bridge with optional response delay.
module axi_lite_apb_bridge(

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

    output reg[`MemAddrBus] paddr_o,
    output reg psel_o,
    output reg penable_o,
    output reg pwrite_o,
    output reg[`MemBus] pwdata_o,
    output reg[3:0] pstrb_o,
    input wire[`MemBus] prdata_i,
    input wire pready_i,
    input wire pslverr_i,

    input wire[3:0] wait_cycles_i

    );

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_W_SETUP = 3'd1;
    localparam [2:0] ST_W_ACCESS = 3'd2;
    localparam [2:0] ST_W_RESP = 3'd3;
    localparam [2:0] ST_R_SETUP = 3'd4;
    localparam [2:0] ST_R_ACCESS = 3'd5;
    localparam [2:0] ST_R_RESP = 3'd6;

    reg[2:0] state_r;
    reg aw_seen_r;
    reg w_seen_r;
    reg[`MemAddrBus] awaddr_r;
    reg[`MemBus] wdata_r;
    reg[3:0] wstrb_r;
    reg[`MemAddrBus] araddr_r;
    reg[3:0] wait_count_r;

    wire wait_done = (wait_count_r == wait_cycles_i);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state_r <= ST_IDLE;
            aw_seen_r <= 1'b0;
            w_seen_r <= 1'b0;
            awaddr_r <= `ZeroWord;
            wdata_r <= `ZeroWord;
            wstrb_r <= 4'b0;
            araddr_r <= `ZeroWord;
            wait_count_r <= 4'h0;
            s_axi_awready <= 1'b1;
            s_axi_wready <= 1'b1;
            s_axi_bresp <= 2'b00;
            s_axi_bvalid <= 1'b0;
            s_axi_arready <= 1'b1;
            s_axi_rdata <= `ZeroWord;
            s_axi_rresp <= 2'b00;
            s_axi_rvalid <= 1'b0;
            paddr_o <= `ZeroWord;
            psel_o <= 1'b0;
            penable_o <= 1'b0;
            pwrite_o <= 1'b0;
            pwdata_o <= `ZeroWord;
            pstrb_o <= 4'b0;
        end else begin
            case (state_r)
                ST_IDLE: begin
                    psel_o <= 1'b0;
                    penable_o <= 1'b0;
                    pwrite_o <= 1'b0;
                    wait_count_r <= 4'h0;
                    s_axi_awready <= 1'b1;
                    s_axi_wready <= 1'b1;
                    s_axi_arready <= 1'b1;

                    if (s_axi_bvalid == 1'b1 && s_axi_bready == 1'b1) begin
                        s_axi_bvalid <= 1'b0;
                    end
                    if (s_axi_rvalid == 1'b1 && s_axi_rready == 1'b1) begin
                        s_axi_rvalid <= 1'b0;
                    end

                    if (s_axi_awvalid == 1'b1 && s_axi_awready == 1'b1) begin
                        awaddr_r <= s_axi_awaddr;
                        aw_seen_r <= 1'b1;
                    end
                    if (s_axi_wvalid == 1'b1 && s_axi_wready == 1'b1) begin
                        wdata_r <= s_axi_wdata;
                        wstrb_r <= s_axi_wstrb;
                        w_seen_r <= 1'b1;
                    end
                    if (s_axi_arvalid == 1'b1 && s_axi_arready == 1'b1 && !(aw_seen_r == 1'b1 || w_seen_r == 1'b1 || s_axi_awvalid == 1'b1 || s_axi_wvalid == 1'b1)) begin
                        araddr_r <= s_axi_araddr;
                        s_axi_arready <= 1'b0;
                        s_axi_awready <= 1'b0;
                        s_axi_wready <= 1'b0;
                        state_r <= ST_R_SETUP;
                    end else if ((aw_seen_r == 1'b1 || (s_axi_awvalid == 1'b1 && s_axi_awready == 1'b1)) &&
                                 (w_seen_r == 1'b1 || (s_axi_wvalid == 1'b1 && s_axi_wready == 1'b1))) begin
                        if (s_axi_awvalid == 1'b1 && s_axi_awready == 1'b1) begin
                            awaddr_r <= s_axi_awaddr;
                        end
                        if (s_axi_wvalid == 1'b1 && s_axi_wready == 1'b1) begin
                            wdata_r <= s_axi_wdata;
                            wstrb_r <= s_axi_wstrb;
                        end
                        aw_seen_r <= 1'b0;
                        w_seen_r <= 1'b0;
                        s_axi_awready <= 1'b0;
                        s_axi_wready <= 1'b0;
                        s_axi_arready <= 1'b0;
                        state_r <= ST_W_SETUP;
                    end
                end
                ST_W_SETUP: begin
                    paddr_o <= awaddr_r;
                    pwrite_o <= 1'b1;
                    pwdata_o <= wdata_r;
                    pstrb_o <= wstrb_r;
                    psel_o <= 1'b1;
                    penable_o <= 1'b0;
                    wait_count_r <= 4'h0;
                    state_r <= ST_W_ACCESS;
                end
                ST_W_ACCESS: begin
                    psel_o <= 1'b1;
                    if (penable_o == 1'b0) begin
                        penable_o <= 1'b1;
                        wait_count_r <= 4'h0;
                    end else begin
                        penable_o <= 1'b1;
                        if (!wait_done) begin
                            wait_count_r <= wait_count_r + 1'b1;
                        end else if (pready_i == 1'b1) begin
                            psel_o <= 1'b0;
                            penable_o <= 1'b0;
                            s_axi_bresp <= {1'b0, pslverr_i};
                            s_axi_bvalid <= 1'b1;
                            state_r <= ST_W_RESP;
                        end
                    end
                end
                ST_W_RESP: begin
                    if (s_axi_bvalid == 1'b1 && s_axi_bready == 1'b1) begin
                        s_axi_bvalid <= 1'b0;
                        s_axi_awready <= 1'b1;
                        s_axi_wready <= 1'b1;
                        s_axi_arready <= 1'b1;
                        state_r <= ST_IDLE;
                    end
                end
                ST_R_SETUP: begin
                    paddr_o <= araddr_r;
                    pwrite_o <= 1'b0;
                    pwdata_o <= `ZeroWord;
                    pstrb_o <= 4'b0;
                    psel_o <= 1'b1;
                    penable_o <= 1'b0;
                    wait_count_r <= 4'h0;
                    state_r <= ST_R_ACCESS;
                end
                ST_R_ACCESS: begin
                    psel_o <= 1'b1;
                    if (penable_o == 1'b0) begin
                        penable_o <= 1'b1;
                        wait_count_r <= 4'h0;
                    end else begin
                        penable_o <= 1'b1;
                        if (!wait_done) begin
                            wait_count_r <= wait_count_r + 1'b1;
                        end else if (pready_i == 1'b1) begin
                            psel_o <= 1'b0;
                            penable_o <= 1'b0;
                            s_axi_rdata <= prdata_i;
                            s_axi_rresp <= {1'b0, pslverr_i};
                            s_axi_rvalid <= 1'b1;
                            state_r <= ST_R_RESP;
                        end
                    end
                end
                ST_R_RESP: begin
                    if (s_axi_rvalid == 1'b1 && s_axi_rready == 1'b1) begin
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
