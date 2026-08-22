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

// APB-programmed QSPI controller.
//
// Register map:
// 0x00 CTRL        bit0 start, bit1 addr_en, bit2 write_en, bit3 quad_en/reserved
// 0x04 STATUS      bit0 busy, bit1 done, bit2 error, bit8 rx_valid
// 0x08 CLKDIV      SCK half-period divider in core clocks
// 0x0c CMD         command byte
// 0x10 ADDR        24-bit flash address
// 0x14 LEN         byte count, capped by the 16-byte local FIFOs
// 0x18 TXDATA      write TX byte at TX_INDEX and auto-increment
// 0x1c RXDATA      read RX byte at RX_INDEX
// 0x20 RX_INDEX    RX read index
// 0x24 FIFO_STATUS {tx_count[7:0], rx_count[7:0]}
// 0x28 TX_INDEX    TX write index
module qspi(

    input wire clk,
    input wire rst,

    input wire[`MemBus] data_i,
    input wire[`MemAddrBus] addr_i,
    input wire we_i,
    output reg[`MemBus] data_o,

    inout wire[3:0] qspi_io,
    output reg qspi_cs_n,
    output reg qspi_clk

    );

    localparam [7:0] REG_CTRL        = 8'h00;
    localparam [7:0] REG_STATUS      = 8'h04;
    localparam [7:0] REG_CLKDIV      = 8'h08;
    localparam [7:0] REG_CMD         = 8'h0c;
    localparam [7:0] REG_ADDR        = 8'h10;
    localparam [7:0] REG_LEN         = 8'h14;
    localparam [7:0] REG_TXDATA      = 8'h18;
    localparam [7:0] REG_RXDATA      = 8'h1c;
    localparam [7:0] REG_RX_INDEX    = 8'h20;
    localparam [7:0] REG_FIFO_STATUS = 8'h24;
    localparam [7:0] REG_TX_INDEX    = 8'h28;

    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_CMD   = 3'd1;
    localparam [2:0] ST_ADDR  = 3'd2;
    localparam [2:0] ST_READ  = 3'd3;
    localparam [2:0] ST_WRITE = 3'd4;
    localparam [2:0] ST_DONE  = 3'd5;

    reg[31:0] ctrl_r;
    reg[7:0] clkdiv_r;
    reg[7:0] cmd_r;
    reg[23:0] addr_r;
    reg[7:0] len_r;
    reg[3:0] rx_index_r;
    reg[3:0] tx_index_r;

    reg busy_r;
    reg done_r;
    reg error_r;
    reg[2:0] state_r;
    reg[1:0] addr_byte_r;
    reg[7:0] byte_count_r;
    reg[2:0] bit_idx_r;
    reg[7:0] tx_shift_r;
    reg[7:0] rx_shift_r;
    reg[7:0] div_count_r;
    reg[3:0] io_o_r;
    reg[3:0] io_oe_r;

    reg[7:0] rx_fifo[0:15];
    reg[7:0] tx_fifo[0:15];
    reg[4:0] rx_count_r;
    reg[4:0] tx_count_r;

    (* keep = "true", mark_debug = "true" *) wire[7:0] dbg_qspi_rx0 = rx_fifo[0];
    (* keep = "true", mark_debug = "true" *) wire[7:0] dbg_qspi_rx1 = rx_fifo[1];
    (* keep = "true", mark_debug = "true" *) wire[7:0] dbg_qspi_rx2 = rx_fifo[2];
    (* keep = "true", mark_debug = "true" *) wire[4:0] dbg_qspi_rx_count = rx_count_r;
    (* keep = "true", mark_debug = "true" *) wire[2:0] dbg_qspi_state = state_r;
    (* keep = "true", mark_debug = "true" *) wire dbg_qspi_busy = busy_r;
    (* keep = "true", mark_debug = "true" *) wire dbg_qspi_done = done_r;
    (* keep = "true", mark_debug = "true" *) wire dbg_qspi_error = error_r;
    (* keep = "true", mark_debug = "true" *) wire[7:0] dbg_qspi_cmd = cmd_r;
    (* keep = "true", mark_debug = "true" *) wire[7:0] dbg_qspi_len = len_r;
    (* keep = "true", mark_debug = "true" *) wire dbg_qspi_mosi = io_o_r[0];
    (* keep = "true", mark_debug = "true" *) wire dbg_qspi_miso = qspi_io[1];
    (* keep = "true", mark_debug = "true" *) wire[3:0] dbg_qspi_io_oe = io_oe_r;

    wire addr_en_w = ctrl_r[1];
    wire write_en_w = ctrl_r[2];
    wire[7:0] rx_byte_w = rx_shift_r;
    integer i;

    assign qspi_io[0] = io_oe_r[0] ? io_o_r[0] : 1'bz;
    assign qspi_io[1] = io_oe_r[1] ? io_o_r[1] : 1'bz;
    assign qspi_io[2] = io_oe_r[2] ? io_o_r[2] : 1'bz;
    assign qspi_io[3] = io_oe_r[3] ? io_o_r[3] : 1'bz;

    always @ (*) begin
        case (addr_i[7:0])
            REG_CTRL: begin
                data_o = ctrl_r;
            end
            REG_STATUS: begin
                data_o = {23'h0, (rx_count_r != 5'd0), 5'h0, error_r, done_r, busy_r};
            end
            REG_CLKDIV: begin
                data_o = {24'h0, clkdiv_r};
            end
            REG_CMD: begin
                data_o = {24'h0, cmd_r};
            end
            REG_ADDR: begin
                data_o = {8'h0, addr_r};
            end
            REG_LEN: begin
                data_o = {24'h0, len_r};
            end
            REG_RXDATA: begin
                data_o = {24'h0, rx_fifo[rx_index_r]};
            end
            REG_RX_INDEX: begin
                data_o = {28'h0, rx_index_r};
            end
            REG_FIFO_STATUS: begin
                data_o = {16'h0, 3'h0, tx_count_r, 3'h0, rx_count_r};
            end
            REG_TX_INDEX: begin
                data_o = {28'h0, tx_index_r};
            end
            default: begin
                data_o = `ZeroWord;
            end
        endcase
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            ctrl_r <= `ZeroWord;
            clkdiv_r <= 8'd1;
            cmd_r <= 8'hff;
            addr_r <= 24'h0;
            len_r <= 8'h0;
            rx_index_r <= 4'h0;
            tx_index_r <= 4'h0;
            busy_r <= 1'b0;
            done_r <= 1'b0;
            error_r <= 1'b0;
            state_r <= ST_IDLE;
            addr_byte_r <= 2'h0;
            byte_count_r <= 8'h0;
            bit_idx_r <= 3'h0;
            tx_shift_r <= 8'h0;
            rx_shift_r <= 8'h0;
            div_count_r <= 8'h0;
            io_o_r <= 4'h0;
            io_oe_r <= 4'h0;
            qspi_cs_n <= 1'b1;
            qspi_clk <= 1'b0;
            rx_count_r <= 5'h0;
            tx_count_r <= 5'h0;
            for (i = 0; i < 16; i = i + 1) begin
                rx_fifo[i] <= 8'h0;
                tx_fifo[i] <= 8'h0;
            end
        end else begin
            if (we_i == 1'b1) begin
                case (addr_i[7:0])
                    REG_CTRL: begin
                        ctrl_r <= data_i;
                        if (data_i[0] == 1'b1 && busy_r == 1'b0) begin
                            busy_r <= 1'b1;
                            done_r <= 1'b0;
                            error_r <= 1'b0;
                            state_r <= ST_CMD;
                            addr_byte_r <= 2'h0;
                            byte_count_r <= 8'h0;
                            bit_idx_r <= 3'd7;
                            tx_shift_r <= cmd_r;
                            rx_shift_r <= 8'h0;
                            div_count_r <= 8'h0;
                            qspi_cs_n <= 1'b0;
                            qspi_clk <= 1'b0;
                            io_oe_r <= 4'b0001;
                            io_o_r <= {3'b000, cmd_r[7]};
                            rx_count_r <= 5'h0;
                            rx_index_r <= 4'h0;
                        end
                    end
                    REG_STATUS: begin
                        if (data_i[1] == 1'b1) begin
                            done_r <= 1'b0;
                        end
                        if (data_i[2] == 1'b1) begin
                            error_r <= 1'b0;
                        end
                    end
                    REG_CLKDIV: begin
                        clkdiv_r <= data_i[7:0];
                    end
                    REG_CMD: begin
                        cmd_r <= data_i[7:0];
                    end
                    REG_ADDR: begin
                        addr_r <= data_i[23:0];
                    end
                    REG_LEN: begin
                        len_r <= data_i[7:0];
                    end
                    REG_TXDATA: begin
                        tx_fifo[tx_index_r] <= data_i[7:0];
                        if (tx_index_r != 4'hf) begin
                            tx_index_r <= tx_index_r + 1'b1;
                        end
                        if (tx_count_r != 5'd16) begin
                            tx_count_r <= tx_count_r + 1'b1;
                        end
                    end
                    REG_RX_INDEX: begin
                        rx_index_r <= data_i[3:0];
                    end
                    REG_TX_INDEX: begin
                        tx_index_r <= data_i[3:0];
                        tx_count_r <= 5'h0;
                    end
                    default: begin
                    end
                endcase
            end

            if (busy_r == 1'b1) begin
                if (div_count_r < clkdiv_r) begin
                    div_count_r <= div_count_r + 1'b1;
                end else begin
                    div_count_r <= 8'h0;
                    if (qspi_clk == 1'b0) begin
                        qspi_clk <= 1'b1;
                        if (state_r == ST_READ) begin
                            rx_shift_r <= {rx_shift_r[6:0], qspi_io[1]};
                        end
                    end else begin
                        qspi_clk <= 1'b0;
                        if (bit_idx_r != 3'd0) begin
                            bit_idx_r <= bit_idx_r - 1'b1;
                            if (state_r != ST_READ) begin
                                io_o_r[0] <= tx_shift_r[bit_idx_r - 1'b1];
                            end
                        end else begin
                            bit_idx_r <= 3'd7;
                            case (state_r)
                                ST_CMD: begin
                                    if (addr_en_w == 1'b1) begin
                                        state_r <= ST_ADDR;
                                        addr_byte_r <= 2'd0;
                                        tx_shift_r <= addr_r[23:16];
                                        io_o_r[0] <= addr_r[23];
                                        io_oe_r <= 4'b0001;
                                    end else if (write_en_w == 1'b1) begin
                                        state_r <= (len_r == 8'h0) ? ST_DONE : ST_WRITE;
                                        tx_shift_r <= tx_fifo[0];
                                        io_o_r[0] <= tx_fifo[0][7];
                                        io_oe_r <= 4'b0001;
                                    end else begin
                                        state_r <= (len_r == 8'h0) ? ST_DONE : ST_READ;
                                        rx_shift_r <= 8'h0;
                                        io_oe_r <= 4'b0000;
                                    end
                                end
                                ST_ADDR: begin
                                    if (addr_byte_r == 2'd0) begin
                                        addr_byte_r <= 2'd1;
                                        tx_shift_r <= addr_r[15:8];
                                        io_o_r[0] <= addr_r[15];
                                    end else if (addr_byte_r == 2'd1) begin
                                        addr_byte_r <= 2'd2;
                                        tx_shift_r <= addr_r[7:0];
                                        io_o_r[0] <= addr_r[7];
                                    end else if (write_en_w == 1'b1) begin
                                        state_r <= (len_r == 8'h0) ? ST_DONE : ST_WRITE;
                                        byte_count_r <= 8'h0;
                                        tx_shift_r <= tx_fifo[0];
                                        io_o_r[0] <= tx_fifo[0][7];
                                        io_oe_r <= 4'b0001;
                                    end else begin
                                        state_r <= (len_r == 8'h0) ? ST_DONE : ST_READ;
                                        byte_count_r <= 8'h0;
                                        rx_shift_r <= 8'h0;
                                        io_oe_r <= 4'b0000;
                                    end
                                end
                                ST_READ: begin
                                    if (rx_count_r < 5'd16) begin
                                        rx_fifo[rx_count_r[3:0]] <= rx_byte_w;
                                        rx_count_r <= rx_count_r + 1'b1;
                                    end else begin
                                        error_r <= 1'b1;
                                    end
                                    if (byte_count_r + 1'b1 >= len_r || rx_count_r >= 5'd15) begin
                                        state_r <= ST_DONE;
                                    end else begin
                                        byte_count_r <= byte_count_r + 1'b1;
                                        rx_shift_r <= 8'h0;
                                    end
                                end
                                ST_WRITE: begin
                                    if (byte_count_r + 1'b1 >= len_r) begin
                                        state_r <= ST_DONE;
                                    end else begin
                                        byte_count_r <= byte_count_r + 1'b1;
                                        tx_shift_r <= tx_fifo[byte_count_r[3:0] + 1'b1];
                                        io_o_r[0] <= tx_fifo[byte_count_r[3:0] + 1'b1][7];
                                        io_oe_r <= 4'b0001;
                                    end
                                end
                                ST_DONE: begin
                                    busy_r <= 1'b0;
                                    done_r <= 1'b1;
                                    qspi_cs_n <= 1'b1;
                                    qspi_clk <= 1'b0;
                                    io_oe_r <= 4'b0000;
                                    state_r <= ST_IDLE;
                                    ctrl_r[0] <= 1'b0;
                                end
                                default: begin
                                    state_r <= ST_DONE;
                                end
                            endcase
                        end
                    end
                end
            end
        end
    end

endmodule
