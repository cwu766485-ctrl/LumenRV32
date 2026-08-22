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

// Bridge one selected memory interface peripheral slot onto a single-outstanding AXI-Lite master.
module axi_lite_bridge(

    input wire clk,
    input wire rst,

    input wire sel_i,
    input wire req_i,
    input wire we_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] data_i,
    input wire[`MemMaskBus] wmask_i,
    output reg[`MemBus] data_o,
    output reg ready_o,

    output reg[`MemAddrBus] m_axi_awaddr,
    output reg m_axi_awvalid,
    input wire m_axi_awready,
    output reg[`MemBus] m_axi_wdata,
    output reg[3:0] m_axi_wstrb,
    output reg m_axi_wvalid,
    input wire m_axi_wready,
    input wire[1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output wire m_axi_bready,

    output reg[`MemAddrBus] m_axi_araddr,
    output reg m_axi_arvalid,
    input wire m_axi_arready,
    input wire[`MemBus] m_axi_rdata,
    input wire[1:0] m_axi_rresp,
    input wire m_axi_rvalid,
    output wire m_axi_rready

    );

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_W_ADDR = 3'd1;
    localparam [2:0] ST_W_RESP = 3'd2;
    localparam [2:0] ST_R_ADDR = 3'd3;
    localparam [2:0] ST_R_RESP = 3'd4;

    wire bridge_req = sel_i & req_i;

    reg[2:0] state_r;
    reg[`MemAddrBus] addr_r;
    reg[`MemBus] data_r;
    reg[`MemMaskBus] wmask_r;
    reg we_r;

    assign m_axi_bready = 1'b1;
    assign m_axi_rready = 1'b1;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state_r <= ST_IDLE;
            addr_r <= `ZeroWord;
            data_r <= `ZeroWord;
            wmask_r <= 4'b0;
            we_r <= `WriteDisable;
            data_o <= `ZeroWord;
            ready_o <= `False;
            m_axi_awaddr <= `ZeroWord;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= `ZeroWord;
            m_axi_wstrb <= 4'b0;
            m_axi_wvalid <= 1'b0;
            m_axi_araddr <= `ZeroWord;
            m_axi_arvalid <= 1'b0;
        end else begin
            ready_o <= `False;

            case (state_r)
                ST_IDLE: begin
                    if (bridge_req == `True) begin
                        addr_r <= {4'h2, addr_i[27:0]};
                        data_r <= data_i;
                        wmask_r <= wmask_i;
                        we_r <= we_i;
                        if (we_i == `WriteEnable) begin
                            m_axi_awaddr <= {4'h2, addr_i[27:0]};
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata <= data_i;
                            m_axi_wstrb <= wmask_i;
                            m_axi_wvalid <= 1'b1;
                            state_r <= ST_W_ADDR;
                        end else begin
                            m_axi_araddr <= {4'h2, addr_i[27:0]};
                            m_axi_arvalid <= 1'b1;
                            state_r <= ST_R_ADDR;
                        end
                    end
                end
                ST_W_ADDR: begin
                    if (m_axi_awvalid == 1'b1 && m_axi_awready == 1'b1) begin
                        m_axi_awvalid <= 1'b0;
                    end
                    if (m_axi_wvalid == 1'b1 && m_axi_wready == 1'b1) begin
                        m_axi_wvalid <= 1'b0;
                    end
                    if ((m_axi_awvalid == 1'b0 || m_axi_awready == 1'b1) &&
                        (m_axi_wvalid == 1'b0 || m_axi_wready == 1'b1)) begin
                        state_r <= ST_W_RESP;
                    end
                end
                ST_W_RESP: begin
                    if (m_axi_bvalid == 1'b1) begin
                        data_o <= `ZeroWord;
                        ready_o <= `True;
                        state_r <= ST_IDLE;
                    end
                end
                ST_R_ADDR: begin
                    if (m_axi_arvalid == 1'b1 && m_axi_arready == 1'b1) begin
                        m_axi_arvalid <= 1'b0;
                        state_r <= ST_R_RESP;
                    end
                end
                ST_R_RESP: begin
                    if (m_axi_rvalid == 1'b1) begin
                        data_o <= m_axi_rdata;
                        ready_o <= `True;
                        state_r <= ST_IDLE;
                    end
                end
                default: begin
                    state_r <= ST_IDLE;
                end
            endcase

            if (state_r == ST_IDLE && bridge_req != `True) begin
                data_o <= `ZeroWord;
            end
        end
    end

endmodule
