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
    output reg s_axi_awready,

    input wire[31:0] s_axi_wdata,
    input wire[3:0] s_axi_wstrb,
    input wire s_axi_wlast,
    input wire s_axi_wvalid,
    output reg s_axi_wready,

    output reg[3:0] s_axi_bid,
    output reg[1:0] s_axi_bresp,
    output reg s_axi_bvalid,
    input wire s_axi_bready,

    input wire[3:0] s_axi_arid,
    input wire[31:0] s_axi_araddr,
    input wire[7:0] s_axi_arlen,
    input wire[2:0] s_axi_arsize,
    input wire[1:0] s_axi_arburst,
    input wire s_axi_arvalid,
    output reg s_axi_arready,

    output reg[3:0] s_axi_rid,
    output reg[31:0] s_axi_rdata,
    output reg[1:0] s_axi_rresp,
    output reg s_axi_rlast,
    output reg s_axi_rvalid,
    input wire s_axi_rready
);

    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1) begin
                value = value >> 1;
            end
            clog2 = i;
        end
    endfunction

    localparam ADDR_WORD_BITS = clog2(DEPTH_WORDS);
    localparam [1:0] W_IDLE = 2'd0;
    localparam [1:0] W_DATA = 2'd1;
    localparam [1:0] W_RESP = 2'd2;
    localparam [1:0] R_IDLE = 2'd0;
    localparam [1:0] R_WAIT = 2'd1;
    localparam [1:0] R_SEND = 2'd2;

    reg[31:0] mem[0:DEPTH_WORDS - 1];
    reg[1:0] w_state_r;
    reg[1:0] r_state_r;
    reg[31:0] w_addr_r;
    reg[31:0] r_addr_r;
    reg[7:0] w_beats_left_r;
    reg[7:0] r_beats_left_r;
    reg[7:0] wait_count_r;
    reg[3:0] w_id_r;
    reg[3:0] r_id_r;

    integer bi;
    integer init_i;
    wire[ADDR_WORD_BITS - 1:0] write_idx = w_addr_r[ADDR_WORD_BITS + 1:2];
    wire[ADDR_WORD_BITS - 1:0] read_idx = r_addr_r[ADDR_WORD_BITS + 1:2];

    initial begin
        for (init_i = 0; init_i < DEPTH_WORDS; init_i = init_i + 1) begin
            mem[init_i] = 32'h0000_0000;
        end
`ifdef ExtMemInitFile
        $readmemh(`ExtMemInitFile, mem);
`endif
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            s_axi_awready <= 1'b1;
            s_axi_wready <= 1'b0;
            s_axi_bresp <= 2'b00;
            s_axi_bid <= 4'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_arready <= 1'b1;
            s_axi_rdata <= `ZeroWord;
            s_axi_rid <= 4'b0;
            s_axi_rresp <= 2'b00;
            s_axi_rlast <= 1'b0;
            s_axi_rvalid <= 1'b0;
            w_state_r <= W_IDLE;
            r_state_r <= R_IDLE;
            w_addr_r <= `ZeroWord;
            r_addr_r <= `ZeroWord;
            w_beats_left_r <= 8'h0;
            r_beats_left_r <= 8'h0;
            wait_count_r <= 8'h0;
            w_id_r <= 4'b0;
            r_id_r <= 4'b0;
        end else begin
            if (s_axi_bvalid == 1'b1 && s_axi_bready == 1'b1) begin
                s_axi_bvalid <= 1'b0;
            end
            if (s_axi_rvalid == 1'b1 && s_axi_rready == 1'b1) begin
                s_axi_rvalid <= 1'b0;
                s_axi_rlast <= 1'b0;
            end

            case (w_state_r)
                W_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready <= 1'b0;
                    if (s_axi_awvalid == 1'b1 && s_axi_awready == 1'b1) begin
                        w_addr_r <= s_axi_awaddr;
                        w_id_r <= s_axi_awid;
                        w_beats_left_r <= s_axi_awlen + 8'd1;
                        s_axi_awready <= 1'b0;
                        s_axi_wready <= 1'b1;
                        w_state_r <= W_DATA;
                    end
                end
                W_DATA: begin
                    if (s_axi_wvalid == 1'b1 && s_axi_wready == 1'b1) begin
`ifdef TRACE_AXI4_MEM_MODEL
                        $display("AXI4_MEM_MODEL write beat addr=%h data=%h left=%0d last=%0d time=%0t", w_addr_r, s_axi_wdata, w_beats_left_r, s_axi_wlast, $time);
`endif
                        for (bi = 0; bi < 4; bi = bi + 1) begin
                            if (s_axi_wstrb[bi] == 1'b1) begin
                                mem[write_idx][bi * 8 +: 8] <= s_axi_wdata[bi * 8 +: 8];
                            end
                        end
                        w_addr_r <= w_addr_r + 32'd4;
                        if (w_beats_left_r == 8'd1 || s_axi_wlast == 1'b1) begin
`ifdef TRACE_AXI4_MEM_MODEL
                            $display("AXI4_MEM_MODEL write resp enter time=%0t", $time);
`endif
                            s_axi_wready <= 1'b0;
                            s_axi_bvalid <= 1'b1;
                            s_axi_bid <= w_id_r;
                            w_state_r <= W_RESP;
                        end else begin
                            w_beats_left_r <= w_beats_left_r - 8'd1;
                        end
                    end
                end
                W_RESP: begin
                    if (s_axi_bvalid == 1'b0) begin
                        s_axi_awready <= 1'b1;
                        w_state_r <= W_IDLE;
                    end
                end
                default: begin
                    w_state_r <= W_IDLE;
                end
            endcase

            case (r_state_r)
                R_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid == 1'b1 && s_axi_arready == 1'b1) begin
                        r_addr_r <= s_axi_araddr;
                        r_id_r <= s_axi_arid;
                        r_beats_left_r <= s_axi_arlen + 8'd1;
                        wait_count_r <= WAIT_CYCLES[7:0];
                        s_axi_arready <= 1'b0;
                        r_state_r <= (WAIT_CYCLES == 0) ? R_SEND : R_WAIT;
                    end
                end
                R_WAIT: begin
                    if (wait_count_r == 8'd0) begin
                        r_state_r <= R_SEND;
                    end else begin
                        wait_count_r <= wait_count_r - 8'd1;
                    end
                end
                R_SEND: begin
                    if (s_axi_rvalid == 1'b0) begin
`ifdef TRACE_AXI4_MEM_MODEL
                        $display("AXI4_MEM_MODEL read beat addr=%h left=%0d time=%0t", r_addr_r, r_beats_left_r, $time);
`endif
                        s_axi_rdata <= mem[read_idx];
                        s_axi_rid <= r_id_r;
                        s_axi_rresp <= 2'b00;
                        s_axi_rlast <= (r_beats_left_r == 8'd1);
                        s_axi_rvalid <= 1'b1;
                    end else if (s_axi_rvalid == 1'b1 && s_axi_rready == 1'b1) begin
                        r_addr_r <= r_addr_r + 32'd4;
                        if (r_beats_left_r == 8'd1) begin
                            s_axi_arready <= 1'b1;
                            r_state_r <= R_IDLE;
                        end else begin
                            r_beats_left_r <= r_beats_left_r - 8'd1;
                            wait_count_r <= WAIT_CYCLES[7:0];
                            r_state_r <= (WAIT_CYCLES == 0) ? R_SEND : R_WAIT;
                        end
                    end
                end
                default: begin
                    r_state_r <= R_IDLE;
                end
            endcase
        end
    end

endmodule
