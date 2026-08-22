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

// External memory wrapper skeleton for future DDR/MIG hookup.
//
// Front side:
//   - memory interface slave style request/response
//   - intended address space: 0x3xxx_xxxx
//
// Back side:
//   - generic one-outstanding request/response interface that can later be
//     adapted to Vivado MIG app_* signals or an AXI memory bridge
//
// For the current pre-MIG stage, the wrapper can use a built-in model RAM so
// that CPU/DMA/D-Cache integration can be validated before the board-level
// DDR interface is available.
module external_memory_wrapper #(
    parameter USE_MODEL = 1,
    parameter WAIT_CYCLES = 8,
    parameter DEPTH_WORDS = 16384
)(
    input wire clk,
    input wire rst,

    input wire req_i,
    input wire we_i,
    input wire[`MemMaskBus] wmask_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] data_i,
    output reg[`MemBus] data_o,
    output reg ready_o,

    // Generic backend port for future DDR/MIG adaptation.
    output reg backend_req_o,
    output reg backend_we_o,
    output reg[`MemAddrBus] backend_addr_o,
    output reg[`MemBus] backend_wdata_o,
    output reg[`MemMaskBus] backend_wmask_o,
    input wire[`MemBus] backend_rdata_i,
    input wire backend_ready_i
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
    wire[ADDR_WORD_BITS - 1:0] model_addr_idx = addr_i[ADDR_WORD_BITS + 1:2];

    function [`MemBus] apply_wmask;
        input [`MemBus] old_word;
        input [`MemBus] new_word;
        input [`MemMaskBus] wmask;
        begin
            apply_wmask = old_word;
            if (wmask[0]) apply_wmask[7:0] = new_word[7:0];
            if (wmask[1]) apply_wmask[15:8] = new_word[15:8];
            if (wmask[2]) apply_wmask[23:16] = new_word[23:16];
            if (wmask[3]) apply_wmask[31:24] = new_word[31:24];
        end
    endfunction

    generate
        if (USE_MODEL != 0) begin: g_model
            localparam CNT_W = 8;
            reg busy_r;
            reg[CNT_W - 1:0] wait_count_r;
            reg[`MemAddrBus] addr_r;
            reg[ADDR_WORD_BITS - 1:0] addr_idx_r;
            reg we_r;
            reg[`MemMaskBus] wmask_r;
            reg[`MemBus] data_r;
            reg[`MemBus] model_mem[0:DEPTH_WORDS - 1];
            integer bi;

            always @ (*) begin
                backend_req_o = `False;
                backend_we_o = `WriteDisable;
                backend_addr_o = addr_i;
                backend_wdata_o = data_i;
                backend_wmask_o = wmask_i;
                if (rst == `RstEnable) begin
                    data_o = `ZeroWord;
                    ready_o = `False;
                end else begin
                    data_o = (busy_r == `True && wait_count_r == 0) ? model_mem[addr_idx_r] : `ZeroWord;
                    ready_o = (busy_r == `True && wait_count_r == 0);
                end
            end

            always @ (posedge clk) begin
                if (rst == `RstEnable) begin
                    busy_r <= `False;
                    wait_count_r <= {CNT_W{1'b0}};
                    addr_r <= `ZeroWord;
                    addr_idx_r <= {ADDR_WORD_BITS{1'b0}};
                    we_r <= `WriteDisable;
                    wmask_r <= 4'b0;
                    data_r <= `ZeroWord;
                end else begin
                    if (busy_r == `False) begin
                        if (req_i == `True) begin
                            busy_r <= `True;
                            wait_count_r <= (WAIT_CYCLES > 0) ? (WAIT_CYCLES - 1) : 0;
                            addr_r <= addr_i;
                            addr_idx_r <= model_addr_idx;
                            we_r <= we_i;
                            wmask_r <= wmask_i;
                            data_r <= data_i;
                        end
                    end else if (wait_count_r != 0) begin
                        wait_count_r <= wait_count_r - 1'b1;
                    end else begin
                        if (we_r == `WriteEnable) begin
                            for (bi = 0; bi < 4; bi = bi + 1) begin
                                if (wmask_r[bi] == 1'b1) begin
                                    model_mem[addr_idx_r][bi * 8 +: 8] <= data_r[bi * 8 +: 8];
                                end
                            end
                        end
                        busy_r <= `False;
                    end
                end
            end
        end else begin: g_backend
            reg outstanding_r;
            reg[`MemAddrBus] backend_addr_r;
            reg[`MemBus] backend_wdata_r;
            reg[`MemMaskBus] backend_wmask_r;
            reg backend_we_r;

            initial begin
                outstanding_r = `False;
                backend_we_r = `WriteDisable;
                backend_addr_r = `ZeroWord;
                backend_wdata_r = `ZeroWord;
                backend_wmask_r = 4'b0;
            end

            always @ (*) begin
                backend_req_o = outstanding_r;
                backend_we_o = backend_we_r;
                backend_addr_o = backend_addr_r;
                backend_wdata_o = backend_wdata_r;
                backend_wmask_o = backend_wmask_r;
                data_o = backend_rdata_i;
                ready_o = backend_ready_i && outstanding_r;
            end

            always @ (posedge clk) begin
                if (rst == `RstEnable) begin
                    outstanding_r <= `False;
                    backend_we_r <= `WriteDisable;
                    backend_addr_r <= `ZeroWord;
                    backend_wdata_r <= `ZeroWord;
                    backend_wmask_r <= 4'b0;
                end else begin
                    if (!outstanding_r && req_i == `True) begin
                        outstanding_r <= `True;
                        backend_we_r <= we_i;
                        backend_addr_r <= addr_i;
                        backend_wdata_r <= data_i;
                        backend_wmask_r <= wmask_i;
                    end else if (outstanding_r && backend_ready_i == `True) begin
                        outstanding_r <= `False;
                    end
                end
            end
        end
    endgenerate

endmodule
