`timescale 1 ns / 1 ps

 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com

 Modifications Copyright 2026 LumenRV32 contributors
 Modified for USER2 DMI transport, response buffering and CDC integration.
                                                                         
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

`define DM_RESP_VALID     1'b1
`define DM_RESP_INVALID   1'b0
`define DTM_REQ_VALID     1'b1
`define DTM_REQ_INVALID   1'b0

`define DTM_OP_NOP        2'b00
`define DTM_OP_READ       2'b01
`define DTM_OP_WRITE      2'b10


module jtag_dm #(
    parameter DMI_ADDR_BITS = 6,
    parameter DMI_DATA_BITS = 32,
    parameter DMI_OP_BITS = 2)(

    clk,
    rst_n,

    // rx
    dm_ack_o,
    dtm_req_valid_i,
    dtm_req_data_i,

    // tx
    dtm_ack_i,
    dm_resp_data_o,
    dm_resp_valid_o,

    dm_reg_we_o,
    dm_reg_addr_o,
    dm_reg_wdata_o,
    dm_reg_rdata_i,
    dm_mem_we_o,
    dm_mem_addr_o,
    dm_mem_wdata_o,
    dm_mem_rdata_i,

    dm_op_req_o,
    dm_halt_req_o,
    dm_reset_req_o,
    dm_resp_idle_o

    );

    parameter DM_RESP_BITS = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;
    parameter DTM_REQ_BITS = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;
    parameter SHIFT_REG_BITS = DTM_REQ_BITS;

    // ?????????
    input wire clk;
    input wire rst_n;
    output wire dm_ack_o;
    input wire dtm_req_valid_i;
    input wire[DTM_REQ_BITS-1:0] dtm_req_data_i;
    input wire dtm_ack_i;
    output wire[DM_RESP_BITS-1:0] dm_resp_data_o;
    output wire dm_resp_valid_o;
    output wire dm_reg_we_o;
    output wire[4:0] dm_reg_addr_o;
    output wire[31:0] dm_reg_wdata_o;
    input wire[31:0] dm_reg_rdata_i;
    output wire dm_mem_we_o;
    output wire[31:0] dm_mem_addr_o;
    output wire[31:0] dm_mem_wdata_o;
    input wire[31:0] dm_mem_rdata_i;
    output wire dm_op_req_o;
    output wire dm_halt_req_o;
    output wire dm_reset_req_o;
    // CPU-domain indication that the one-entry DMI response sender has
    // completed its entire four-phase transaction.
    output wire dm_resp_idle_o;

    // DM????????
    reg[31:0] dcsr;
    reg[31:0] dmstatus;
    reg[31:0] dmcontrol;
    reg[31:0] hartinfo;
    reg[31:0] abstractcs;
    reg[31:0] data0;
    reg[31:0] sbcs;
    reg[31:0] sbaddress0;
    reg[31:0] sbdata0;
    reg[31:0] command;

    // DM???????????
    localparam DCSR       = 16'h7b0;
    localparam DMSTATUS   = 6'h11;
    localparam DMCONTROL  = 6'h10;
    localparam HARTINFO   = 6'h12;
    localparam ABSTRACTCS = 6'h16;
    localparam DATA0      = 6'h04;
    localparam SBCS       = 6'h38;
    localparam SBADDRESS0 = 6'h39;
    localparam SBDATA0    = 6'h3C;
    localparam COMMAND    = 6'h17;
    localparam DPC        = 16'h7b1;

    localparam OP_SUCC = 2'b00;

    reg[31:0] read_data;
    reg dm_reg_we;
    reg[4:0] dm_reg_addr;
    reg[31:0] dm_reg_wdata;
    reg dm_mem_we;
    reg[31:0] dm_mem_addr;
    reg[31:0] dm_mem_wdata;
    reg dm_halt_req;
    reg dm_reset_req;
    // One-entry response buffer.  The request and response CDCs are
    // independent; retaining a completed response here prevents a request
    // arriving just after the previous response was captured from being lost
    // while the CPU-domain transmitter is still returning to idle.
    reg resp_pending;
    reg[DMI_ADDR_BITS-1:0] resp_addr;
    reg[DMI_DATA_BITS-1:0] resp_read_data;
    reg is_read_reg;
    // Explicit declaration is required for strict lint; this is driven by
    // the response-channel full_handshake_tx instance below.
    wire tx_idle;
    wire rx_valid;
    wire[DTM_REQ_BITS-1:0] rx_data;

    wire[31:0] sbaddress0_next = sbaddress0 + 4;
    wire[DM_RESP_BITS-1:0] dm_resp_data;
    // DMSTATUS reflects the live debug-halt request.  The compact debug
    // implementation has no separate hart-halted acknowledgement channel,
    // therefore these all/any halted/running bits must not depend on a stale
    // software-visible mirror register.
    wire[31:0] dmstatus_live = {dmstatus[31:12],
                                 dm_halt_req ? 4'h3 : 4'hc,
                                 dmstatus[7:0]};

    wire[DMI_OP_BITS-1:0] op = rx_data[DMI_OP_BITS-1:0];
    wire[DMI_DATA_BITS-1:0] data = rx_data[DMI_DATA_BITS+DMI_OP_BITS-1:DMI_OP_BITS];
    wire[DMI_ADDR_BITS-1:0] address = rx_data[DTM_REQ_BITS-1:DMI_DATA_BITS+DMI_OP_BITS];

    wire read_dmstatus = (op == `DTM_OP_READ) & (address == DMSTATUS);

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dm_mem_we <= 1'b0;
            dm_reg_we <= 1'b0;
            dm_halt_req <= 1'b0;
            dm_reset_req <= 1'b0;
            dm_mem_addr <= 32'h0;
            dm_reg_addr <= 5'h0;
            sbaddress0 <= 32'h0;
            dcsr <= 32'h0;
            hartinfo <= 32'h0;
            sbcs <= 32'h20040404;
            dmcontrol <= 32'h0;
            abstractcs <= 32'h1000003;
            data0 <= 32'h0;
            sbdata0 <= 32'h0;
            command <= 32'h0;
            dm_reg_wdata <= 32'h0;
            dm_mem_wdata <= 32'h0;
            dmstatus <= 32'h430c82;
            is_read_reg <= 1'b0;
            read_data <= 32'h0;
            resp_pending <= 1'b0;
            resp_addr <= {DMI_ADDR_BITS{1'b0}};
            resp_read_data <= {DMI_DATA_BITS{1'b0}};
        end else begin
            // full_handshake_tx samples resp_pending while it is idle, then
            // holds resp_addr/resp_read_data internally for the full CDC
            // transfer. Clear this slot only after that sampling edge.
            if (resp_pending && tx_idle)
                resp_pending <= 1'b0;
            if (rx_valid) begin
                resp_pending <= 1'b1;
                resp_addr <= address;
                resp_read_data <= {DMI_DATA_BITS{1'b0}};
                case (op)
                    `DTM_OP_READ: begin
                        case (address)
                            DMSTATUS: begin
                                read_data <= dmstatus_live;
                                resp_read_data <= dmstatus_live;
                            end
                            DMCONTROL: begin
                                read_data <= dmcontrol;
                                resp_read_data <= dmcontrol;
                            end
                            HARTINFO: begin
                                read_data <= hartinfo;
                                resp_read_data <= hartinfo;
                            end
                            SBCS: begin
                                read_data <= sbcs;
                                resp_read_data <= sbcs;
                            end
                            ABSTRACTCS: begin
                                read_data <= abstractcs;
                                resp_read_data <= abstractcs;
                            end
                            DATA0: begin
                                if (is_read_reg == 1'b1) begin
                                    read_data <= dm_reg_rdata_i;
                                    resp_read_data <= dm_reg_rdata_i;
                                end else begin
                                    read_data <= data0;
                                    resp_read_data <= data0;
                                end
                                is_read_reg <= 1'b0;
                            end
                            SBDATA0: begin
                                read_data <= dm_mem_rdata_i;
                                resp_read_data <= dm_mem_rdata_i;
                                if (sbcs[16] == 1'b1) begin
                                    sbaddress0 <= sbaddress0_next;
                                end
                                if (sbcs[15] == 1'b1) begin
                                    dm_mem_addr <= sbaddress0_next;
                                end
                            end
                            default: begin
                                read_data <= {(DMI_DATA_BITS){1'b0}};
                            end
                        endcase
                    end

                    `DTM_OP_WRITE: begin
                        read_data <= {(DMI_DATA_BITS){1'b0}};
                        case (address)
                            DMCONTROL: begin
                                // reset DM module
                                if (data[0] == 1'b0) begin
                                    dcsr <= 32'hc0;
                                    dmstatus <= 32'h430c82;  // not halted, all running
                                    hartinfo <= 32'h0;
                                    sbcs <= 32'h20040404;
                                    abstractcs <= 32'h1000003;
                                    dmcontrol <= data;
                                    dm_halt_req <= 1'b0;
                                    dm_reset_req <= 1'b0;
                                // DM is active
                                end else begin
                                    // we have only one hart
                                    dmcontrol <= (data & ~(32'h3fffc0)) | 32'h10000;
                                    // halt
                                    if (data[31] == 1'b1) begin
                                        dm_halt_req <= 1'b1;
                                        // clear ALLRUNNING ANYRUNNING and set ALLHALTED
                                        dmstatus <= {dmstatus[31:12], 4'h3, dmstatus[7:0]};
                                    // resume
                                    end else if (dm_halt_req == 1'b1 && data[30] == 1'b1) begin
                                        dm_halt_req <= 1'b0;
                                        // set ALLRUNNING ANYRUNNING and clear ALLHALTED
                                        dmstatus <= {dmstatus[31:12], 4'hc, dmstatus[7:0]};
                                    end
                                end
                            end
                            COMMAND: begin
                                // access reg
                                if (data[31:24] == 8'h0) begin
                                    if (data[22:20] > 3'h2) begin
                                        abstractcs <= abstractcs | (1'b1 << 9);
                                    end else begin
                                        abstractcs <= abstractcs & (~(3'h7 << 8));
                                        // read or write
                                        if (data[18] == 1'b0) begin
                                            dm_reg_addr <= data[15:0] - 16'h1000;
                                            // read
                                            if (data[16] == 1'b0) begin
                                                if (data[15:0] == DCSR) begin
                                                    data0 <= dcsr;
                                                end else if (data[15:0] < 16'h1020) begin
                                                    is_read_reg <= 1'b1;
                                                end
                                            // write
                                            end else begin
                                                // when write dpc, we reset cpu here
                                                if (data[15:0] == DPC) begin
                                                    dm_reset_req <= 1'b1;
                                                    dm_halt_req <= 1'b0;
                                                    dmstatus <= {dmstatus[31:12], 4'hc, dmstatus[7:0]};
                                                end else if (data[15:0] < 16'h1020) begin
                                                    dm_reg_we <= 1'b1;
                                                    dm_reg_wdata <= data0;
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            DATA0: begin
                                data0 <= data;
                            end
                            SBCS: begin
                                sbcs <= data;
                            end
                            SBADDRESS0: begin
                                sbaddress0 <= data;
                                if (sbcs[20] == 1'b1) begin
                                    dm_mem_addr <= data;
                                end
                            end
                            SBDATA0: begin
                                sbdata0 <= data;
                                dm_mem_addr <= sbaddress0;
                                dm_mem_wdata <= data;
                                dm_mem_we <= 1'b1;
                                if (sbcs[16] == 1'b1) begin
                                    sbaddress0 <= sbaddress0_next;
                                end
                            end
                        endcase
                    end

                    `DTM_OP_NOP: begin
                        read_data <= {(DMI_DATA_BITS){1'b0}};
                    end
                endcase
            end else begin
                dm_mem_we <= 1'b0;
                dm_reg_we <= 1'b0;
                dm_reset_req <= 1'b0;
            end
        end
    end

    assign dm_reg_we_o = dm_reg_we;
    assign dm_reg_addr_o = dm_reg_addr;
    assign dm_reg_wdata_o = dm_reg_wdata;
    assign dm_mem_we_o = dm_mem_we;
    assign dm_mem_addr_o = dm_mem_addr;
    assign dm_mem_wdata_o = dm_mem_wdata;

    assign dm_op_req_o = (rx_valid & (~read_dmstatus)) | resp_pending;
    assign dm_halt_req_o = dm_halt_req;
    assign dm_reset_req_o = dm_reset_req;
    assign dm_resp_idle_o = tx_idle;

    assign dm_resp_data = {resp_addr, resp_read_data, OP_SUCC};


    full_handshake_tx #(
        .DW(DM_RESP_BITS)
    ) tx(
        .clk(clk),
        .rst_n(rst_n),
        .ack_i(dtm_ack_i),
        .req_i(resp_pending),
        .req_data_i(dm_resp_data),
        .idle_o(tx_idle),
        .req_o(dm_resp_valid_o),
        .req_data_o(dm_resp_data_o)
    );

    full_handshake_rx #(
        .DW(DTM_REQ_BITS)
    ) rx(
        .clk(clk),
        .rst_n(rst_n),
        .req_i(dtm_req_valid_i),
        .req_data_i(dtm_req_data_i),
        .ack_o(dm_ack_o),
        .recv_data_o(rx_data),
        .recv_rdy_o(rx_valid)
    );

endmodule


