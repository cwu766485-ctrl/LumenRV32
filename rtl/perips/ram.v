/*
Copyright 2019 Blue Liang, liangkangnan@163.com

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
// RAM / on-chip data memory
// -----------------------------------------------------------------------------
// This module is a simple 32-bit word-addressed memory used as one memory interface slave.
//
// Interface meaning:
// - req_i/ready_o form a simple request/response handshake.
// - we_i selects read or write: WriteEnable(1) = write, WriteDisable(0) = read.
// - wmask_i is a byte write mask. wmask_i[0] controls data_i[7:0],
//   wmask_i[1] controls data_i[15:8], and so on.
// - addr_i is a byte address, but the memory array is 32-bit word based, so
//   addr_i[31:2] is used as the array index and addr_i[1:0] is ignored here.
//
// WAIT_CYCLES:
// - WAIT_CYCLES == 0: zero-wait memory. Reads are combinational and ready_o
//   follows req_i in the same cycle. Writes commit on the clock edge.
// - WAIT_CYCLES  > 0: wait-state memory model. A request is locked, counted
//   down, and ready_o is asserted when wait_count_r reaches 0.
//
// Interview point:
// This RAM is not a cache. It is the real backing storage behind the memory interface RAM
// address window. D-cache may cache data from this RAM, but this module itself
// is just a simple memory slave.
// -----------------------------------------------------------------------------
module ram #(
    parameter WAIT_CYCLES = `RamWaitCycles
)(

    input wire clk,
    input wire rst,

    input wire req_i,
    input wire we_i,
    input wire[`MemMaskBus] wmask_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] data_i,

    output reg[`MemBus] data_o,
    output reg ready_o

    );

    // 4096 x 32-bit by default (`MemNum = 4096), i.e. 16 KiB.
    reg[`MemBus] _ram[0:`MemNum - 1];

    generate
        if (WAIT_CYCLES == 0) begin: g_zero_wait
            integer bi;

            // Zero-wait write path.
            // The write still happens on the clock edge because FPGA block RAM
            // and register arrays are normally synchronous for writes.
            always @ (posedge clk) begin
                if (we_i == `WriteEnable && req_i == `True) begin
                    for (bi = 0; bi < 4; bi = bi + 1) begin
                        if (wmask_i[bi] == 1'b1) begin
                            // Part-select form: [bi * 8 +: 8] selects one byte.
                            _ram[addr_i[31:2]][bi * 8 +: 8] <= data_i[bi * 8 +: 8];
                        end
                    end
                end
            end

            // Zero-wait read/ready path.
            // If req_i is asserted, the selected word is immediately visible
            // and ready_o is asserted in the same combinational cycle.
            always @ (*) begin
                if (rst == `RstEnable) begin
                    data_o = `ZeroWord;
                    ready_o = `False;
                end else begin
                    data_o = _ram[addr_i[31:2]];
                    ready_o = req_i;
                end
            end
        end else begin: g_wait
            localparam CNT_W = 8;

            // Wait-state transaction state. Once a request is accepted, all
            // transaction fields are locked so the master may keep seeing a
            // stable response even if upstream signals change.
            reg busy_r;
            reg[CNT_W - 1:0] wait_count_r;
            reg[`MemAddrBus] addr_r;
            reg we_r;
            reg[`MemMaskBus] wmask_r;
            reg[`MemBus] data_r;
            integer bi;

            // During wait-state mode, data_o/ready_o become valid only at the
            // final wait cycle. Before that, the RAM tells memory interface/CPU "not ready".
            always @ (*) begin
                if (rst == `RstEnable) begin
                    data_o = `ZeroWord;
                    ready_o = `False;
                end else begin
                    data_o = (busy_r == `True && wait_count_r == 0) ? _ram[addr_r[31:2]] : `ZeroWord;
                    ready_o = (busy_r == `True && wait_count_r == 0);
                end
            end

            // Wait-state request FSM:
            // 1. idle: accept req_i and lock addr/data/wmask/we
            // 2. wait: decrement wait_count_r
            // 3. complete: perform write if needed, assert ready through the
            //    combinational block, then return to idle
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
`ifdef TRACE_RAM
                            $display("RAM_REQ addr=%08x we=%b wdata=%08x wmask=%x time=%0t",
                                addr_i, we_i, data_i, wmask_i, $time);
`endif
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
`ifdef TRACE_RAM
                        $display("RAM_DONE addr=%08x we=%b wdata=%08x rdata=%08x time=%0t",
                            addr_r, we_r, data_r, _ram[addr_r[31:2]], $time);
`endif
                        // Complete a delayed write on the final wait cycle.
                        // For delayed reads, the combinational block exposes
                        // _ram[addr_r[31:2]] while ready_o is high.
                        if (we_r == `WriteEnable) begin
                            for (bi = 0; bi < 4; bi = bi + 1) begin
                                if (wmask_r[bi] == 1'b1) begin
                                    _ram[addr_r[31:2]][bi * 8 +: 8] <= data_r[bi * 8 +: 8];
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
