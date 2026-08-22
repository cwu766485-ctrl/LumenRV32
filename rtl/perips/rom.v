/*
Copyright 2020 Blue Liang, liangkangnan@163.com

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

`timescale 1 ns / 1 ps

`include "../core/defines.v"

// -----------------------------------------------------------------------------
// ROM / boot instruction memory
// -----------------------------------------------------------------------------
// This module is a simple 32-bit word-addressed memory used as the memory interface ROM
// slave. In the SoC address map it is normally selected by the 0x0xxx_xxxx
// region and is heavily used by the CPU instruction fetch path.
//
// Interface meaning:
// - req_i/ready_o form a simple request/response handshake.
// - addr_i is a byte address, but the array is 32-bit word based, so
//   addr_i[31:2] is used as the ROM word index.
// - data_o returns one 32-bit word.
//
// Why does ROM have write ports?
// The original TinyRISC-V style keeps ROM/RAM slave interfaces uniform. The ROM
// also supports byte-mask writes in simulation or debug-style loading paths.
// Semantically, software treats this region as boot/read-mostly memory.
//
// WAIT_CYCLES:
// - WAIT_CYCLES == 0: zero-wait ROM. Reads are combinational and ready_o
//   follows req_i.
// - WAIT_CYCLES  > 0: wait-state ROM model. The request is locked and returned
//   after WAIT_CYCLES cycles. This is useful for testing stall/hold correctness.
// -----------------------------------------------------------------------------
module rom #(
    parameter WAIT_CYCLES = `RomWaitCycles
)(

    input wire clk,
    input wire rst,

    input wire req_i, // 请求有效
    input wire we_i, // 写使能，1 表示写，0 表示读
    input wire[`MemMaskBus] wmask_i, //4-bit字节写掩码
    input wire[`MemAddrBus] addr_i, //byte address
    input wire[`MemBus] data_i, // 写数据总线

    output reg[`MemBus] data_o, // 读数据总线
    output reg ready_o // 响应有效

    );

    // 4096 x 32-bit by default (`RomNum = 4096), i.e. 16 KiB.
    reg[`MemBus] _rom[0:`RomNum - 1];

`ifdef FPGA_ROM_INIT
    // FPGA/image initialization path. The macro should expand to a memory file
    // path accepted by $readmemh, for example a generated .hex file.
    initial begin
        $readmemh(`FPGA_ROM_INIT, _rom);
    end
`endif

    generate
        if (WAIT_CYCLES == 0) begin: g_zero_wait
            integer bi;

            // Uniform slave write path. Usually ROM is read-only from software,
            // but allowing writes here makes simulation/debug loading easier and
            // keeps the interface identical to RAM.
            always @ (posedge clk) begin
                if (we_i == `WriteEnable && req_i == `True) begin
                    for (bi = 0; bi < 4; bi = bi + 1) begin
                        if (wmask_i[bi] == 1'b1) begin
                            // [bi * 8 +: 8] selects one byte inside the word.
                            _rom[addr_i[31:2]][bi * 8 +: 8] <= data_i[bi * 8 +: 8];
                        end
                    end
                end
            end

            // Zero-wait read path: instruction fetch can receive the word in
            // the same cycle as req_i.
            always @ (*) begin
                if (rst == `RstEnable) begin
                    data_o = `ZeroWord;
                    ready_o = `False;
                end else begin
                    data_o = _rom[addr_i[31:2]];
                    ready_o = req_i;
                end
            end
        end else begin: g_wait
            localparam CNT_W = 8;

            // Wait-state transaction registers. They lock the request so ROM
            // can model a slow memory while keeping address/data stable.
            reg busy_r;
            reg[CNT_W - 1:0] wait_count_r;
            reg[`MemAddrBus] addr_r;
            reg we_r;
            reg[`MemMaskBus] wmask_r;
            reg[`MemBus] data_r;
            integer bi;

            // The response becomes valid only when the locked transaction has
            // counted down to zero.
            always @ (*) begin
                if (rst == `RstEnable) begin
                    data_o = `ZeroWord;
                    ready_o = `False;
                end else begin
                    data_o = (busy_r == `True && wait_count_r == 0) ? _rom[addr_r[31:2]] : `ZeroWord;
                    ready_o = (busy_r == `True && wait_count_r == 0);
                end
            end

            // Wait-state request FSM:
            // idle -> lock request -> count down -> complete read/write -> idle.
            // This path is important for verifying that pc_reg/ifetch/icache and
            // the memory interface hold logic remain correct when ROM is not zero-wait.
            always @ (posedge clk) begin
                if (rst == `RstEnable) begin
                    busy_r <= `False;
                    wait_count_r <= {CNT_W{1'b0}};
                    addr_r <= `ZeroWord;
                    we_r <= `WriteDisable;
                    wmask_r <= 4'b0;
                    data_r <= `ZeroWord;
                end else begin
                    if (busy_r == `False) begin
                        if (req_i == `True) begin
                            busy_r <= `True;
                            wait_count_r <= WAIT_CYCLES - 1;
                            addr_r <= addr_i;
                            we_r <= we_i;
                            wmask_r <= wmask_i;
                            data_r <= data_i;
                        end
                    end else if (wait_count_r != 0) begin
                        wait_count_r <= wait_count_r - 1'b1;
                    end else begin
                        // Complete a delayed write if the locked transaction was a
                        // write. For a delayed read, data_o is produced above.
                        if (we_r == `WriteEnable) begin
                            for (bi = 0; bi < 4; bi = bi + 1) begin
                                if (wmask_r[bi] == 1'b1) begin
                                    _rom[addr_r[31:2]][bi * 8 +: 8] <= data_r[bi * 8 +: 8];
                                end
                            end
                        end
                        busy_r <= `False;
                    end
                end
            end
        end
    endgenerate

endmodule
