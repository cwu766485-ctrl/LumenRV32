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

module dma(

    input wire clk,
    input wire rst,

    input wire we_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] data_i,
    output reg[`MemBus] data_o,

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

    localparam DMA_CTRL   = 8'h00;
    localparam DMA_STATUS = 8'h04;
    localparam DMA_SRC    = 8'h08;
    localparam DMA_DST    = 8'h0c;
    localparam DMA_LEN    = 8'h10;
    localparam DMA_COUNT  = 8'h14;
    localparam DMA_AUX    = 8'h18;
    localparam DMA_FIFO_STATUS = 8'h1c;
    localparam DMA_ERROR  = 8'h20;
    localparam DMA_DESC_STATUS = 8'h24;

    localparam UART_STATUS = 32'h2000_1004;
    localparam UART_TXDATA = 32'h2000_100c;
    localparam UART_RXDATA = 32'h2000_1010;
    localparam SPI_CTRL    = 32'h2000_3000;
    localparam SPI_DATA    = 32'h2000_3004;
    localparam SPI_STATUS  = 32'h2000_3008;

    localparam ST_IDLE          = 5'd0;
    localparam ST_POLL_REQ      = 5'd1;
    localparam ST_POLL_WAIT     = 5'd2;
    localparam ST_POLL_GAP      = 5'd3;
    localparam ST_READ_REQ      = 5'd4;
    localparam ST_READ_WAIT     = 5'd5;
    localparam ST_WRITE_REQ     = 5'd6;
    localparam ST_WRITE_WAIT    = 5'd7;
    localparam ST_CLEAR_REQ     = 5'd8;
    localparam ST_CLEAR_WAIT    = 5'd9;
    localparam ST_SPI_DATA_REQ  = 5'd10;
    localparam ST_SPI_DATA_WAIT = 5'd11;
    localparam ST_SPI_CTRL_REQ  = 5'd12;
    localparam ST_SPI_CTRL_WAIT = 5'd13;
    localparam ST_SPI_BUSY_REQ  = 5'd14;
    localparam ST_SPI_BUSY_WAIT = 5'd15;
    localparam ST_SPI_GAP       = 5'd16;
    localparam ST_SPI_RX_REQ    = 5'd17;
    localparam ST_SPI_RX_WAIT   = 5'd18;

    reg[4:0] state_r;

    reg[`MemAddrBus] src_reg;
    reg[`MemAddrBus] dst_reg;
    reg[`MemBus] len_reg;
    reg[`MemBus] aux_reg;
    reg irq_en_r;
    reg fixed_src_r;
    reg fixed_dst_r;
    reg byte_mode_r;
    reg spi_stream_r;
    reg done_r;
    reg error_r;
    reg irq_pending_r;

    reg[`MemAddrBus] cur_src_r;
    reg[`MemAddrBus] cur_dst_r;
    reg[`MemBus] remaining_r;
    reg[`MemBus] moved_count_r;
    reg[`MemBus] read_word_r;
    reg[7:0] read_byte_r;
    reg have_read_data_r;

    localparam integer DMA_FIFO_DEPTH = 4;
    localparam [2:0] DMA_FIFO_DEPTH_VALUE = 3'd4;
    reg[`MemBus] fifo_word_r[0:DMA_FIFO_DEPTH-1];
    reg[7:0] fifo_byte_r[0:DMA_FIFO_DEPTH-1];
    reg[1:0] fifo_wr_ptr_r;
    reg[1:0] fifo_rd_ptr_r;
    reg[2:0] fifo_count_r;
    reg fifo_overflow_r;
    reg fifo_underflow_r;

    wire fifo_empty = (fifo_count_r == 3'd0);
    wire fifo_full = (fifo_count_r == DMA_FIFO_DEPTH_VALUE);
    wire[`MemBus] fifo_word_front = fifo_word_r[fifo_rd_ptr_r];
    wire[7:0] fifo_byte_front = fifo_byte_r[fifo_rd_ptr_r];

    wire start_pulse = (we_i == `WriteEnable) && (addr_i[7:0] == DMA_CTRL) && (data_i[0] == 1'b1);
    wire clear_done = (we_i == `WriteEnable) && (addr_i[7:0] == DMA_STATUS) && (data_i[1] == 1'b1);
    wire clear_irq = (we_i == `WriteEnable) && (addr_i[7:0] == DMA_STATUS) && (data_i[2] == 1'b1);
    wire busy = (state_r != ST_IDLE);

    wire ctrl_fixed_src = start_pulse ? data_i[2] : fixed_src_r;
    wire ctrl_fixed_dst = start_pulse ? data_i[3] : fixed_dst_r;
    wire ctrl_byte_mode = start_pulse ? data_i[4] : byte_mode_r;
    wire ctrl_spi_stream = start_pulse ? data_i[5] : spi_stream_r;

    wire mode_uart_tx = byte_mode_r && fixed_dst_r && !fixed_src_r && !spi_stream_r && (dst_reg == UART_TXDATA);
    wire mode_uart_rx = byte_mode_r && fixed_src_r && !fixed_dst_r && !spi_stream_r && (src_reg == UART_RXDATA);
    wire mode_spi_tx = byte_mode_r && fixed_dst_r && !fixed_src_r && spi_stream_r && (dst_reg == SPI_DATA);
    wire mode_spi_rx = byte_mode_r && fixed_src_r && !fixed_dst_r && spi_stream_r && (src_reg == SPI_DATA);
    wire start_mode_uart_tx = ctrl_byte_mode && ctrl_fixed_dst && !ctrl_fixed_src && !ctrl_spi_stream && (dst_reg == UART_TXDATA);
    wire start_mode_uart_rx = ctrl_byte_mode && ctrl_fixed_src && !ctrl_fixed_dst && !ctrl_spi_stream && (src_reg == UART_RXDATA);
    wire start_mode_spi_tx = ctrl_byte_mode && ctrl_fixed_dst && !ctrl_fixed_src && ctrl_spi_stream && (dst_reg == SPI_DATA);
    wire start_mode_spi_rx = ctrl_byte_mode && ctrl_fixed_src && !ctrl_fixed_dst && ctrl_spi_stream && (src_reg == SPI_DATA);

    wire invalid_word_align = (!ctrl_byte_mode) && ((src_reg[1:0] != 2'b00) || (dst_reg[1:0] != 2'b00));
    wire invalid_fixed_combo = ctrl_fixed_src && ctrl_fixed_dst;
    wire invalid_stream_combo = ctrl_spi_stream && !(start_mode_spi_tx || start_mode_spi_rx);
    wire start_error = (len_reg == 32'h0) || invalid_word_align || invalid_fixed_combo || invalid_stream_combo;

    wire[`MemAddrBus] read_addr = fixed_src_r ? src_reg :
                                  (byte_mode_r ? {cur_src_r[31:2], 2'b00} : cur_src_r);
    wire[`MemAddrBus] write_addr = fixed_dst_r ? dst_reg :
                                   (byte_mode_r ? {cur_dst_r[31:2], 2'b00} : cur_dst_r);
    wire[1:0] read_lane = fixed_src_r ? 2'b00 : cur_src_r[1:0];
    wire[1:0] write_lane = fixed_dst_r ? 2'b00 : cur_dst_r[1:0];
    wire[`MemBus] byte_write_data = {24'h0, fifo_byte_front} << ({write_lane, 3'b000});
    wire[`MemMaskBus] byte_write_mask = fixed_dst_r ? 4'b0001 : (4'b0001 << write_lane);
    wire[`MemBus] spi_ctrl_wdata = aux_reg | 32'h1;
    wire[`MemBus] spi_dummy_wdata = 32'h0000_00ff;

    wire req_poll = (state_r == ST_POLL_REQ) || (state_r == ST_POLL_WAIT);
    wire req_read = (state_r == ST_READ_REQ) || (state_r == ST_READ_WAIT);
    wire req_write = (state_r == ST_WRITE_REQ) || (state_r == ST_WRITE_WAIT);
    wire req_clear = (state_r == ST_CLEAR_REQ) || (state_r == ST_CLEAR_WAIT);
    wire req_spi_data = (state_r == ST_SPI_DATA_REQ) || (state_r == ST_SPI_DATA_WAIT);
    wire req_spi_ctrl = (state_r == ST_SPI_CTRL_REQ) || (state_r == ST_SPI_CTRL_WAIT);
    wire req_spi_busy = (state_r == ST_SPI_BUSY_REQ) || (state_r == ST_SPI_BUSY_WAIT);
    wire req_spi_rx = (state_r == ST_SPI_RX_REQ) || (state_r == ST_SPI_RX_WAIT);

    assign mem_addr_o = req_poll ? (mode_uart_tx || mode_uart_rx ? UART_STATUS : SPI_STATUS) :
                        req_read ? read_addr :
                        req_write ? write_addr :
                        req_clear ? UART_STATUS :
                        req_spi_data ? SPI_DATA :
                        req_spi_ctrl ? SPI_CTRL :
                        req_spi_busy ? SPI_STATUS :
                        req_spi_rx ? SPI_DATA :
                        `ZeroWord;

    assign mem_data_o = req_write ? (byte_mode_r ? byte_write_data : fifo_word_front) :
                        req_clear ? 32'h0 :
                        req_spi_data ? spi_dummy_wdata :
                        req_spi_ctrl ? spi_ctrl_wdata :
                        `ZeroWord;

    assign mem_wmask_o = req_write ? (byte_mode_r ? byte_write_mask : 4'hf) :
                         (req_clear || req_spi_data || req_spi_ctrl) ? 4'hf :
                         4'hf;

    assign mem_req_o = req_poll || req_read || req_write || req_clear || req_spi_data || req_spi_ctrl || req_spi_busy || req_spi_rx;
    assign mem_we_o = (req_write || req_clear || req_spi_data || req_spi_ctrl) ? `WriteEnable : `WriteDisable;
    assign busy_o = busy;
    assign done_o = done_r;
    assign error_o = error_r;
    assign irq_o = irq_pending_r & irq_en_r;

    task automatic advance_transfer;
        begin
            moved_count_r <= moved_count_r + 32'd1;
            if (!fixed_src_r) begin
                cur_src_r <= byte_mode_r ? (cur_src_r + 32'd1) : (cur_src_r + 32'd4);
            end
            if (!fixed_dst_r) begin
                cur_dst_r <= byte_mode_r ? (cur_dst_r + 32'd1) : (cur_dst_r + 32'd4);
            end
            if (remaining_r == 32'd1) begin
                remaining_r <= 32'h0;
            end else begin
                remaining_r <= remaining_r - 32'd1;
            end
        end
    endtask

    task automatic fifo_clear;
        begin
            fifo_wr_ptr_r <= 2'd0;
            fifo_rd_ptr_r <= 2'd0;
            fifo_count_r <= 3'd0;
        end
    endtask

    task automatic fifo_push;
        input[`MemBus] word_value;
        input[7:0] byte_value;
        begin
            if (fifo_full) begin
                fifo_overflow_r <= 1'b1;
                error_r <= 1'b1;
            end else begin
                fifo_word_r[fifo_wr_ptr_r] <= word_value;
                fifo_byte_r[fifo_wr_ptr_r] <= byte_value;
                fifo_wr_ptr_r <= fifo_wr_ptr_r + 2'd1;
                fifo_count_r <= fifo_count_r + 3'd1;
            end
        end
    endtask

    task automatic fifo_pop;
        begin
            if (fifo_empty) begin
                fifo_underflow_r <= 1'b1;
                error_r <= 1'b1;
            end else begin
                fifo_rd_ptr_r <= fifo_rd_ptr_r + 2'd1;
                fifo_count_r <= fifo_count_r - 3'd1;
            end
        end
    endtask

    task automatic finish_transfer;
        begin
            state_r <= ST_IDLE;
            done_r <= 1'b1;
            irq_pending_r <= 1'b1;
        end
    endtask

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state_r <= ST_IDLE;
            src_reg <= `ZeroWord;
            dst_reg <= `ZeroWord;
            len_reg <= `ZeroWord;
            aux_reg <= `ZeroWord;
            irq_en_r <= 1'b0;
            fixed_src_r <= 1'b0;
            fixed_dst_r <= 1'b0;
            byte_mode_r <= 1'b0;
            spi_stream_r <= 1'b0;
            done_r <= 1'b0;
            error_r <= 1'b0;
            irq_pending_r <= 1'b0;
            cur_src_r <= `ZeroWord;
            cur_dst_r <= `ZeroWord;
            remaining_r <= `ZeroWord;
            moved_count_r <= `ZeroWord;
            read_word_r <= `ZeroWord;
            read_byte_r <= 8'h0;
            have_read_data_r <= 1'b0;
            fifo_clear();
            fifo_overflow_r <= 1'b0;
            fifo_underflow_r <= 1'b0;
        end else begin
            if (we_i == `WriteEnable) begin
                case (addr_i[7:0])
                    DMA_CTRL: begin
                        irq_en_r <= data_i[1];
                        fixed_src_r <= data_i[2];
                        fixed_dst_r <= data_i[3];
                        byte_mode_r <= data_i[4];
                        spi_stream_r <= data_i[5];
                    end
                    DMA_SRC: src_reg <= data_i;
                    DMA_DST: dst_reg <= data_i;
                    DMA_LEN: len_reg <= data_i;
                    DMA_AUX: aux_reg <= data_i;
                    default: begin
                    end
                endcase
            end

            if (clear_done) begin
                done_r <= 1'b0;
            end
            if (clear_irq) begin
                irq_pending_r <= 1'b0;
            end

            case (state_r)
                ST_IDLE: begin
                    if (start_pulse) begin
                        done_r <= 1'b0;
                        error_r <= 1'b0;
                        irq_pending_r <= 1'b0;
                        moved_count_r <= 32'h0;
                        cur_src_r <= src_reg;
                        cur_dst_r <= dst_reg;
                        remaining_r <= len_reg;
                        have_read_data_r <= 1'b0;
                        fifo_clear();
                        fifo_overflow_r <= 1'b0;
                        fifo_underflow_r <= 1'b0;
                        if (start_error) begin
                            error_r <= 1'b1;
                        end else if (start_mode_uart_rx) begin
                            state_r <= ST_POLL_REQ;
                        end else if (start_mode_spi_rx) begin
                            state_r <= ST_SPI_DATA_REQ;
                        end else begin
                            state_r <= ST_READ_REQ;
                        end
                    end
                end
                ST_POLL_REQ: begin
                    state_r <= ST_POLL_WAIT;
                end
                ST_POLL_WAIT: begin
                    if (mem_ready_i == `True) begin
                        if (mode_uart_rx) begin
                            state_r <= mem_data_i[1] ? ST_READ_REQ : ST_POLL_GAP;
                        end else if (mode_uart_tx) begin
                            state_r <= (mem_data_i[0] == 1'b0) ? ST_WRITE_REQ : ST_POLL_GAP;
                        end else begin
                            state_r <= (mem_data_i[0] == 1'b0) ? ST_SPI_RX_REQ : ST_POLL_GAP;
                        end
                    end
                end
                ST_POLL_GAP: begin
                    state_r <= ST_POLL_REQ;
                end
                ST_READ_REQ: begin
                    state_r <= ST_READ_WAIT;
                end
                ST_READ_WAIT: begin
                    if (mem_ready_i == `True) begin
                        read_word_r <= mem_data_i;
                        read_byte_r <= mem_data_i >> ({read_lane, 3'b000});
                        fifo_push(mem_data_i, mem_data_i >> ({read_lane, 3'b000}));
                        have_read_data_r <= 1'b1;
                        if (mode_uart_tx || mode_spi_tx) begin
                            state_r <= mode_uart_tx ? ST_POLL_REQ : ST_WRITE_REQ;
                        end else begin
                            state_r <= ST_WRITE_REQ;
                        end
                    end
                end
                ST_WRITE_REQ: begin
                    state_r <= ST_WRITE_WAIT;
                end
                ST_WRITE_WAIT: begin
                    if (mem_ready_i == `True) begin
                        fifo_pop();
                        if (mode_uart_rx) begin
                            have_read_data_r <= 1'b0;
                            advance_transfer();
                            state_r <= ST_CLEAR_REQ;
                        end else if (mode_spi_tx) begin
                            state_r <= ST_SPI_CTRL_REQ;
                        end else if (mode_spi_rx) begin
                            have_read_data_r <= 1'b0;
                            advance_transfer();
                            if (remaining_r == 32'd1) begin
                                finish_transfer();
                            end else begin
                                state_r <= ST_SPI_DATA_REQ;
                            end
                        end else begin
                            have_read_data_r <= 1'b0;
                            advance_transfer();
                            if (remaining_r == 32'd1) begin
                                finish_transfer();
                            end else begin
                                state_r <= ST_READ_REQ;
                            end
                        end
                    end
                end
                ST_CLEAR_REQ: begin
                    state_r <= ST_CLEAR_WAIT;
                end
                ST_CLEAR_WAIT: begin
                    if (mem_ready_i == `True) begin
                        if (remaining_r == 32'd0) begin
                            finish_transfer();
                        end else begin
                            state_r <= ST_POLL_REQ;
                        end
                    end
                end
                ST_SPI_DATA_REQ: begin
                    state_r <= ST_SPI_DATA_WAIT;
                end
                ST_SPI_DATA_WAIT: begin
                    if (mem_ready_i == `True) begin
                        state_r <= ST_SPI_CTRL_REQ;
                    end
                end
                ST_SPI_CTRL_REQ: begin
                    state_r <= ST_SPI_CTRL_WAIT;
                end
                ST_SPI_CTRL_WAIT: begin
                    if (mem_ready_i == `True) begin
                        state_r <= ST_SPI_BUSY_REQ;
                    end
                end
                ST_SPI_BUSY_REQ: begin
                    state_r <= ST_SPI_BUSY_WAIT;
                end
                ST_SPI_BUSY_WAIT: begin
                    if (mem_ready_i == `True) begin
                        if (mem_data_i[0] == 1'b0) begin
                            if (mode_spi_tx) begin
                                have_read_data_r <= 1'b0;
                                advance_transfer();
                                if (remaining_r == 32'd1) begin
                                    finish_transfer();
                                end else begin
                                    state_r <= ST_READ_REQ;
                                end
                            end else begin
                                state_r <= ST_SPI_RX_REQ;
                            end
                        end else begin
                            state_r <= ST_SPI_GAP;
                        end
                    end
                end
                ST_SPI_GAP: begin
                    state_r <= ST_SPI_BUSY_REQ;
                end
                ST_SPI_RX_REQ: begin
                    state_r <= ST_SPI_RX_WAIT;
                end
                ST_SPI_RX_WAIT: begin
                    if (mem_ready_i == `True) begin
                        read_word_r <= mem_data_i;
                        read_byte_r <= mem_data_i[7:0];
                        fifo_push(mem_data_i, mem_data_i[7:0]);
                        have_read_data_r <= 1'b1;
                        if (mode_spi_rx) begin
                            state_r <= ST_WRITE_REQ;
                        end else begin
                            state_r <= ST_IDLE;
                        end
                    end
                end
                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

    always @ (*) begin
        case (addr_i[7:0])
            DMA_CTRL: data_o = {26'h0, spi_stream_r, byte_mode_r, fixed_dst_r, fixed_src_r, irq_en_r, 1'b0};
            DMA_STATUS: data_o = {28'h0, error_r, irq_pending_r, done_r, busy};
            DMA_SRC: data_o = src_reg;
            DMA_DST: data_o = dst_reg;
            DMA_LEN: data_o = len_reg;
            DMA_COUNT: data_o = moved_count_r;
            DMA_AUX: data_o = aux_reg;
            DMA_FIFO_STATUS: data_o = {19'h0, fifo_underflow_r, fifo_overflow_r, fifo_full, fifo_empty, fifo_count_r, fifo_rd_ptr_r, fifo_wr_ptr_r};
            DMA_ERROR: data_o = {29'h0, fifo_underflow_r, fifo_overflow_r, error_r};
            DMA_DESC_STATUS: data_o = {16'h0, state_r, 3'h0, spi_stream_r, byte_mode_r, fixed_dst_r, fixed_src_r, busy, done_r, error_r};
            default: data_o = `ZeroWord;
        endcase
    end

endmodule
