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

`include "defines.v"

// -----------------------------------------------------------------------------
// Fetch adapter with a small prefetch queue
// -----------------------------------------------------------------------------
// pc_reg still provides the sequential fetch PC, but ifetch now decouples the
// fetch backend from IF/ID with a four-entry FIFO:
//
//   pc_reg -> I-cache / memory backend -> prefetch queue -> IF/ID
//
// A hit can be pushed into the queue every cycle.  A miss is tracked as one
// outstanding pending request and holds PC until the backend returns the word.
// flush_i clears both the pending request and all queued wrong-path entries.
// -----------------------------------------------------------------------------
module ifetch(

    input wire clk,
    input wire rst,

    input wire flush_i,
    input wire freeze_i,
    input wire[`InstAddrBus] pc_i,
    input wire resp_ready_i,

    input wire[`InstBus] backend_inst_i,
    input wire backend_hold_i,
    output wire[`MemAddrBus] backend_addr_o,
    output wire backend_req_o,

    output reg[`InstBus] resp_inst_o,
    output reg[`InstAddrBus] resp_addr_o,
    output reg resp_valid_o,
    output wire hold_flag_o,
    output wire[2:0] perf_queue_occupancy_o,
    output wire perf_queue_full_o,
    output wire perf_queue_stall_o

    );

    localparam QUEUE_DEPTH = 4;
    localparam QUEUE_COUNT_BITS = 3;
    localparam[QUEUE_COUNT_BITS - 1:0] QUEUE_DEPTH_COUNT = 3'd4;

    reg[`InstBus] queue_inst[0:QUEUE_DEPTH - 1];
    reg[`InstAddrBus] queue_addr[0:QUEUE_DEPTH - 1];
    reg[QUEUE_COUNT_BITS - 1:0] queue_count;

    reg req_pending_r;
    reg[`InstAddrBus] req_addr_r;

    integer i;

    wire queue_not_empty = (queue_count != 0);
    wire accept_resp = (queue_not_empty == `True) && (resp_ready_i == `True);
    wire queue_has_room = (queue_count < QUEUE_DEPTH_COUNT) ||
                          (accept_resp == `True);
    wire pc_in_queue =
        ((queue_count > 3'd0) && (queue_addr[0] == pc_i)) ||
        ((queue_count > 3'd1) && (queue_addr[1] == pc_i)) ||
        ((queue_count > 3'd2) && (queue_addr[2] == pc_i)) ||
        ((queue_count > 3'd3) && (queue_addr[3] == pc_i));

    wire issue_req = (flush_i == `False) &&
                     (freeze_i == `False) &&
                     (req_pending_r == `False) &&
                     (queue_has_room == `True) &&
                     (pc_in_queue == `False);

    wire pending_complete = (req_pending_r == `True) && (backend_hold_i == `False);
    wire issue_hit = (issue_req == `True) && (backend_hold_i == `False);
    wire issue_miss = (issue_req == `True) && (backend_hold_i == `True);
    wire push_entry = pending_complete || issue_hit;
    wire[`InstBus] push_inst = pending_complete ? backend_inst_i : backend_inst_i;
    wire[`InstAddrBus] push_addr = pending_complete ? req_addr_r : pc_i;

    assign backend_addr_o = (req_pending_r == `True) ? req_addr_r : pc_i;
    assign backend_req_o = (req_pending_r == `True) || (issue_req == `True);

    // PC/frontend should only stop when the queue cannot accept another fetch,
    // the backend is servicing a miss, or the rest of the pipeline is frozen.
    assign hold_flag_o = (freeze_i == `True) ||
                         ((queue_has_room == `False) && (req_pending_r == `False)) ||
                         ((req_pending_r == `True) && (backend_hold_i == `True)) ||
                         ((pc_in_queue == `True) && (accept_resp == `False)) ||
                         (issue_miss == `True);
    assign perf_queue_occupancy_o = queue_count;
    assign perf_queue_full_o = (queue_count == QUEUE_DEPTH_COUNT);
    assign perf_queue_stall_o = hold_flag_o && (freeze_i == `False);

    always @ (*) begin
        if (queue_not_empty == `True) begin
            resp_inst_o = queue_inst[0];
            resp_addr_o = queue_addr[0];
            resp_valid_o = `True;
        end else begin
            resp_inst_o = `INST_NOP;
            resp_addr_o = `ZeroWord;
            resp_valid_o = `False;
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable || flush_i == `True) begin
            req_pending_r <= `False;
            req_addr_r <= `ZeroWord;
            queue_count <= 0;
            for (i = 0; i < QUEUE_DEPTH; i = i + 1) begin
                queue_inst[i] <= `INST_NOP;
                queue_addr[i] <= `ZeroWord;
            end
        end else begin
            if (issue_miss == `True) begin
                req_pending_r <= `True;
                req_addr_r <= pc_i;
            end else if (pending_complete == `True) begin
                req_pending_r <= `False;
            end

            case ({accept_resp, push_entry})
                2'b00: begin
                    queue_count <= queue_count;
                end
                2'b01: begin
                    case (queue_count)
                        3'd0: begin
                            queue_inst[0] <= push_inst;
                            queue_addr[0] <= push_addr;
                            queue_count <= 3'd1;
                        end
                        3'd1: begin
                            queue_inst[1] <= push_inst;
                            queue_addr[1] <= push_addr;
                            queue_count <= 3'd2;
                        end
                        3'd2: begin
                            queue_inst[2] <= push_inst;
                            queue_addr[2] <= push_addr;
                            queue_count <= 3'd3;
                        end
                        default: begin
                            queue_inst[3] <= push_inst;
                            queue_addr[3] <= push_addr;
                            queue_count <= 3'd4;
                        end
                    endcase
                end
                2'b10: begin
                    case (queue_count)
                        3'd0: begin
                            queue_count <= 3'd0;
                        end
                        3'd1: begin
                            queue_inst[0] <= `INST_NOP;
                            queue_addr[0] <= `ZeroWord;
                            queue_count <= 3'd0;
                        end
                        3'd2: begin
                            queue_inst[0] <= queue_inst[1];
                            queue_addr[0] <= queue_addr[1];
                            queue_inst[1] <= `INST_NOP;
                            queue_addr[1] <= `ZeroWord;
                            queue_count <= 3'd1;
                        end
                        3'd3: begin
                            queue_inst[0] <= queue_inst[1];
                            queue_addr[0] <= queue_addr[1];
                            queue_inst[1] <= queue_inst[2];
                            queue_addr[1] <= queue_addr[2];
                            queue_inst[2] <= `INST_NOP;
                            queue_addr[2] <= `ZeroWord;
                            queue_count <= 3'd2;
                        end
                        default: begin
                            queue_inst[0] <= queue_inst[1];
                            queue_addr[0] <= queue_addr[1];
                            queue_inst[1] <= queue_inst[2];
                            queue_addr[1] <= queue_addr[2];
                            queue_inst[2] <= queue_inst[3];
                            queue_addr[2] <= queue_addr[3];
                            queue_inst[3] <= `INST_NOP;
                            queue_addr[3] <= `ZeroWord;
                            queue_count <= 3'd3;
                        end
                    endcase
                end
                default: begin
                    case (queue_count)
                        3'd0: begin
                            queue_inst[0] <= push_inst;
                            queue_addr[0] <= push_addr;
                            queue_count <= 3'd1;
                        end
                        3'd1: begin
                            queue_inst[0] <= push_inst;
                            queue_addr[0] <= push_addr;
                            queue_count <= 3'd1;
                        end
                        3'd2: begin
                            queue_inst[0] <= queue_inst[1];
                            queue_addr[0] <= queue_addr[1];
                            queue_inst[1] <= push_inst;
                            queue_addr[1] <= push_addr;
                            queue_count <= 3'd2;
                        end
                        3'd3: begin
                            queue_inst[0] <= queue_inst[1];
                            queue_addr[0] <= queue_addr[1];
                            queue_inst[1] <= queue_inst[2];
                            queue_addr[1] <= queue_addr[2];
                            queue_inst[2] <= push_inst;
                            queue_addr[2] <= push_addr;
                            queue_count <= 3'd3;
                        end
                        default: begin
                            queue_inst[0] <= queue_inst[1];
                            queue_addr[0] <= queue_addr[1];
                            queue_inst[1] <= queue_inst[2];
                            queue_addr[1] <= queue_addr[2];
                            queue_inst[2] <= queue_inst[3];
                            queue_addr[2] <= queue_addr[3];
                            queue_inst[3] <= push_inst;
                            queue_addr[3] <= push_addr;
                            queue_count <= 3'd4;
                        end
                    endcase
                end
            endcase
        end
    end

endmodule
