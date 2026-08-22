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

module axi4_extmem_bridge(
    input wire clk,
    input wire rst,

    input wire req_i,
    input wire we_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] data_i,
    input wire[`MemMaskBus] wmask_i,
    output reg[`MemBus] data_o,
    output reg ready_o,

    output reg[31:0] m_axi_awaddr,
    output wire[7:0] m_axi_awlen,
    output wire[2:0] m_axi_awsize,
    output wire[1:0] m_axi_awburst,
    output reg m_axi_awvalid,
    input wire m_axi_awready,

    output reg[31:0] m_axi_wdata,
    output reg[3:0] m_axi_wstrb,
    output reg m_axi_wlast,
    output reg m_axi_wvalid,
    input wire m_axi_wready,

    input wire[1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output reg m_axi_bready,

    output reg[31:0] m_axi_araddr,
    output wire[7:0] m_axi_arlen,
    output wire[2:0] m_axi_arsize,
    output wire[1:0] m_axi_arburst,
    output reg m_axi_arvalid,
    input wire m_axi_arready,

    input wire[31:0] m_axi_rdata,
    input wire[1:0] m_axi_rresp,
    input wire m_axi_rlast,
    input wire m_axi_rvalid,
    output reg m_axi_rready
);

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_WRITE_REQ  = 3'd1;
    localparam [2:0] ST_WRITE_RESP = 3'd2;
    localparam [2:0] ST_READ_REQ   = 3'd3;
    localparam [2:0] ST_READ_RESP  = 3'd4;

    reg[2:0] state_r;
    reg req_seen_r;

    assign m_axi_awlen = 8'h00;
    assign m_axi_arlen = 8'h00;
    assign m_axi_awsize = 3'd2;
    assign m_axi_arsize = 3'd2;
    assign m_axi_awburst = 2'b01;
    assign m_axi_arburst = 2'b01;

    initial begin
        state_r = ST_IDLE;
        req_seen_r = 1'b0;
        ready_o = `False;
        data_o = `ZeroWord;
        m_axi_awaddr = `ZeroWord;
        m_axi_awvalid = 1'b0;
        m_axi_wdata = `ZeroWord;
        m_axi_wstrb = 4'h0;
        m_axi_wlast = 1'b0;
        m_axi_wvalid = 1'b0;
        m_axi_bready = 1'b0;
        m_axi_araddr = `ZeroWord;
        m_axi_arvalid = 1'b0;
        m_axi_rready = 1'b0;
    end

`ifndef SYNTHESIS
    reg aw_hold_seen_r;
    reg[31:0] awaddr_hold_r;
    reg w_hold_seen_r;
    reg[31:0] wdata_hold_r;
    reg[3:0] wstrb_hold_r;
    reg wlast_hold_r;
    reg ar_hold_seen_r;
    reg[31:0] araddr_hold_r;
`endif

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state_r <= ST_IDLE;
            req_seen_r <= 1'b0;
            ready_o <= `False;
            data_o <= `ZeroWord;
            m_axi_awaddr <= `ZeroWord;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= `ZeroWord;
            m_axi_wstrb <= 4'h0;
            m_axi_wlast <= 1'b0;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b0;
            m_axi_araddr <= `ZeroWord;
            m_axi_arvalid <= 1'b0;
            m_axi_rready <= 1'b0;
`ifndef SYNTHESIS
            aw_hold_seen_r <= 1'b0;
            awaddr_hold_r <= `ZeroWord;
            w_hold_seen_r <= 1'b0;
            wdata_hold_r <= `ZeroWord;
            wstrb_hold_r <= 4'h0;
            wlast_hold_r <= 1'b0;
            ar_hold_seen_r <= 1'b0;
            araddr_hold_r <= `ZeroWord;
`endif
        end else begin
            ready_o <= `False;
            if (req_i == `False) begin
                req_seen_r <= 1'b0;
            end

            case (state_r)
                ST_IDLE: begin
                    m_axi_bready <= 1'b0;
                    m_axi_rready <= 1'b0;
                    if (req_i == `True && req_seen_r == 1'b0) begin
                        req_seen_r <= 1'b1;
                        if (we_i == `WriteEnable) begin
                            m_axi_awaddr <= addr_i;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata <= data_i;
                            m_axi_wstrb <= wmask_i;
                            m_axi_wlast <= 1'b1;
                            m_axi_wvalid <= 1'b1;
                            state_r <= ST_WRITE_REQ;
                        end else begin
                            m_axi_araddr <= addr_i;
                            m_axi_arvalid <= 1'b1;
                            state_r <= ST_READ_REQ;
                        end
                    end
                end
                ST_WRITE_REQ: begin
                    if (m_axi_awvalid == 1'b1 && m_axi_awready == 1'b1) begin
                        m_axi_awvalid <= 1'b0;
                    end
                    if (m_axi_wvalid == 1'b1 && m_axi_wready == 1'b1) begin
                        m_axi_wvalid <= 1'b0;
                    end
                    if ((m_axi_awvalid == 1'b0 || m_axi_awready == 1'b1) &&
                        (m_axi_wvalid == 1'b0 || m_axi_wready == 1'b1)) begin
                        m_axi_bready <= 1'b1;
                        state_r <= ST_WRITE_RESP;
                    end
                end
                ST_WRITE_RESP: begin
                    if (m_axi_bvalid == 1'b1) begin
                        m_axi_bready <= 1'b0;
                        ready_o <= `True;
                        state_r <= ST_IDLE;
                    end
                end
                ST_READ_REQ: begin
                    if (m_axi_arvalid == 1'b1 && m_axi_arready == 1'b1) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready <= 1'b1;
                        state_r <= ST_READ_RESP;
                    end
                end
                ST_READ_RESP: begin
                    if (m_axi_rvalid == 1'b1) begin
                        data_o <= m_axi_rdata;
                        if (m_axi_rlast == 1'b1) begin
                            m_axi_rready <= 1'b0;
                            ready_o <= `True;
                            state_r <= ST_IDLE;
                        end
                    end
                end
                default: begin
                    state_r <= ST_IDLE;
                end
            endcase

`ifndef SYNTHESIS
            if (m_axi_awvalid == 1'b1 && m_axi_awready == 1'b0) begin
                if (aw_hold_seen_r == 1'b1 && m_axi_awaddr !== awaddr_hold_r) begin
                    $display("AXI4_EXTMEM_BRIDGE_ASSERT_FAIL awaddr changed while stalled");
                    $finish(1);
                end
                aw_hold_seen_r <= 1'b1;
                awaddr_hold_r <= m_axi_awaddr;
            end else begin
                aw_hold_seen_r <= 1'b0;
            end

            if (m_axi_wvalid == 1'b1 && m_axi_wready == 1'b0) begin
                if (w_hold_seen_r == 1'b1 &&
                    (m_axi_wdata !== wdata_hold_r ||
                     m_axi_wstrb !== wstrb_hold_r ||
                     m_axi_wlast !== wlast_hold_r)) begin
                    $display("AXI4_EXTMEM_BRIDGE_ASSERT_FAIL w payload changed while stalled");
                    $finish(1);
                end
                w_hold_seen_r <= 1'b1;
                wdata_hold_r <= m_axi_wdata;
                wstrb_hold_r <= m_axi_wstrb;
                wlast_hold_r <= m_axi_wlast;
            end else begin
                w_hold_seen_r <= 1'b0;
            end

            if (m_axi_arvalid == 1'b1 && m_axi_arready == 1'b0) begin
                if (ar_hold_seen_r == 1'b1 && m_axi_araddr !== araddr_hold_r) begin
                    $display("AXI4_EXTMEM_BRIDGE_ASSERT_FAIL araddr changed while stalled");
                    $finish(1);
                end
                ar_hold_seen_r <= 1'b1;
                araddr_hold_r <= m_axi_araddr;
            end else begin
                ar_hold_seen_r <= 1'b0;
            end
`endif
        end
    end

endmodule
