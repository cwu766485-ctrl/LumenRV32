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

// A lightweight performance monitor unit that exposes coarse-grained
// pipeline and control-flow activity through memory-mapped counters.
module pmu(

    input wire clk,
    input wire rst,

    input wire we_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] data_i,
    output reg[`MemBus] data_o,

    input wire[`InstBus] inst_i,
    input wire[`Hold_Flag_Bus] hold_flag_i,
    input wire int_assert_i,
    input wire div_busy_i,
    input wire icache_hit_i,
    input wire icache_miss_i,
    input wire dcache_load_hit_i,
    input wire dcache_load_miss_i,
    input wire dcache_store_hit_i,
    input wire dcache_store_miss_i,
    input wire branch_redirect_i,
    input wire branch_flush_i,
    input wire[2:0] prefetch_occupancy_i,
    input wire prefetch_full_i,
    input wire prefetch_stall_i,
    input wire branch_predict_hit_i,
    input wire branch_predict_miss_i,
    input wire dcache_load_miss_stall_i,
    input wire dcache_store_wait_i,
    input wire fetch_bus_wait_i,
    input wire data_bus_wait_i,
    input wire id_contention_i,
    input wire store_buffer_enqueue_i,
    input wire store_buffer_full_stall_i,
    input wire store_buffer_drain_i

    );

    localparam PMU_CTRL = 8'h00;
    localparam PMU_CYCLE = 8'h04;
    localparam PMU_CYCLEH = 8'h08;
    localparam PMU_INST = 8'h0c;
    localparam PMU_INSTH = 8'h10;
    localparam PMU_JUMP = 8'h14;
    localparam PMU_JUMPH = 8'h18;
    localparam PMU_LOAD = 8'h1c;
    localparam PMU_LOADH = 8'h20;
    localparam PMU_STORE = 8'h24;
    localparam PMU_STOREH = 8'h28;
    localparam PMU_HOLD = 8'h2c;
    localparam PMU_HOLDH = 8'h30;
    localparam PMU_INT = 8'h34;
    localparam PMU_INTH = 8'h38;
    localparam PMU_DIV_WAIT = 8'h3c;
    localparam PMU_DIV_WAITH = 8'h40;
    localparam PMU_SIM_DONE = 8'h44;
    localparam PMU_SIM_TICKS = 8'h48;
    localparam PMU_SIM_TICKSH = 8'h4c;
    localparam PMU_ICACHE_HIT = 8'h50;
    localparam PMU_ICACHE_MISS = 8'h54;
    localparam PMU_DCACHE_LOAD_HIT = 8'h58;
    localparam PMU_DCACHE_LOAD_MISS = 8'h5c;
    localparam PMU_DCACHE_STORE_HIT = 8'h60;
    localparam PMU_DCACHE_STORE_MISS = 8'h64;
    localparam PMU_BRANCH_REDIRECT = 8'h68;
    localparam PMU_BRANCH_FLUSH = 8'h6c;
    localparam PMU_PREFETCH_OCC_SUM = 8'h70;
    localparam PMU_PREFETCH_FULL = 8'h74;
    localparam PMU_PREFETCH_STALL = 8'h78;
    localparam PMU_BRANCH_PRED_HIT = 8'h7c;
    localparam PMU_BRANCH_PRED_MISS = 8'h80;
    localparam PMU_DCACHE_LOAD_MISS_STALL = 8'h84;
    localparam PMU_DCACHE_STORE_WAIT = 8'h88;
    localparam PMU_ID_CONTENTION = 8'h8c;
    localparam PMU_STORE_BUFFER_ENQUEUE = 8'h90;
    localparam PMU_STORE_BUFFER_FULL_STALL = 8'h94;
    localparam PMU_STORE_BUFFER_DRAIN = 8'h98;
    localparam PMU_FETCH_BUS_WAIT = 8'h9c;
    localparam PMU_DATA_BUS_WAIT = 8'ha0;

    wire[6:0] opcode = inst_i[6:0];
    wire inst_valid = (inst_i != `INST_NOP);
    wire jump_event = inst_valid && (
        (opcode == `INST_TYPE_B) ||
        (opcode == `INST_JAL) ||
        (opcode == `INST_JALR) ||
        (inst_i == `INST_MRET)
    );
    wire load_event = inst_valid && (opcode == `INST_TYPE_L);
    wire store_event = inst_valid && (opcode == `INST_TYPE_S);
    wire hold_event = (hold_flag_i != `Hold_None);
    wire int_event = (int_assert_i == `INT_ASSERT);
    wire clear_counters = (we_i == `WriteEnable) && (addr_i[7:0] == PMU_CTRL) && (data_i[0] == 1'b1);
    wire div_wait_event = (div_busy_i == `True);

    reg[`DoubleRegBus] cycle_counter;
    reg[`DoubleRegBus] inst_counter;
    reg[`DoubleRegBus] jump_counter;
    reg[`DoubleRegBus] load_counter;
    reg[`DoubleRegBus] store_counter;
    reg[`DoubleRegBus] hold_counter;
    reg[`DoubleRegBus] int_counter;
    reg[`DoubleRegBus] div_wait_counter;
    reg[`DoubleRegBus] icache_hit_counter;
    reg[`DoubleRegBus] icache_miss_counter;
    reg[`DoubleRegBus] dcache_load_hit_counter;
    reg[`DoubleRegBus] dcache_load_miss_counter;
    reg[`DoubleRegBus] dcache_store_hit_counter;
    reg[`DoubleRegBus] dcache_store_miss_counter;
    reg[`DoubleRegBus] branch_redirect_counter;
    reg[`DoubleRegBus] branch_flush_counter;
    reg[`DoubleRegBus] prefetch_occupancy_sum_counter;
    reg[`DoubleRegBus] prefetch_full_counter;
    reg[`DoubleRegBus] prefetch_stall_counter;
    reg[`DoubleRegBus] branch_predict_hit_counter;
    reg[`DoubleRegBus] branch_predict_miss_counter;
    reg[`DoubleRegBus] dcache_load_miss_stall_counter;
    reg[`DoubleRegBus] dcache_store_wait_counter;
    reg[`DoubleRegBus] fetch_bus_wait_counter;
    reg[`DoubleRegBus] data_bus_wait_counter;
    reg[`DoubleRegBus] id_contention_counter;
    reg[`DoubleRegBus] store_buffer_enqueue_counter;
    reg[`DoubleRegBus] store_buffer_full_stall_counter;
    reg[`DoubleRegBus] store_buffer_drain_counter;
    reg[`DoubleRegBus] sim_ticks_reg;
    reg[`RegBus] sim_done_reg;

    always @ (posedge clk) begin
        if (rst == `RstEnable || clear_counters) begin
            cycle_counter <= 64'h0;
            inst_counter <= 64'h0;
            jump_counter <= 64'h0;
            load_counter <= 64'h0;
            store_counter <= 64'h0;
            hold_counter <= 64'h0;
            int_counter <= 64'h0;
            div_wait_counter <= 64'h0;
            icache_hit_counter <= 64'h0;
            icache_miss_counter <= 64'h0;
            dcache_load_hit_counter <= 64'h0;
            dcache_load_miss_counter <= 64'h0;
            dcache_store_hit_counter <= 64'h0;
            dcache_store_miss_counter <= 64'h0;
            branch_redirect_counter <= 64'h0;
            branch_flush_counter <= 64'h0;
            prefetch_occupancy_sum_counter <= 64'h0;
            prefetch_full_counter <= 64'h0;
            prefetch_stall_counter <= 64'h0;
            branch_predict_hit_counter <= 64'h0;
            branch_predict_miss_counter <= 64'h0;
            dcache_load_miss_stall_counter <= 64'h0;
            dcache_store_wait_counter <= 64'h0;
            fetch_bus_wait_counter <= 64'h0;
            data_bus_wait_counter <= 64'h0;
            id_contention_counter <= 64'h0;
            store_buffer_enqueue_counter <= 64'h0;
            store_buffer_full_stall_counter <= 64'h0;
            store_buffer_drain_counter <= 64'h0;
            sim_ticks_reg <= 64'h0;
            sim_done_reg <= 32'h0;
        end else begin
            cycle_counter <= cycle_counter + 64'd1;

            if (inst_valid) begin
                inst_counter <= inst_counter + 64'd1;
            end
            if (jump_event) begin
                jump_counter <= jump_counter + 64'd1;
            end
            if (load_event) begin
                load_counter <= load_counter + 64'd1;
            end
            if (store_event) begin
                store_counter <= store_counter + 64'd1;
            end
            if (hold_event) begin
                hold_counter <= hold_counter + 64'd1;
            end
            if (int_event) begin
                int_counter <= int_counter + 64'd1;
            end
            if (div_wait_event) begin
                div_wait_counter <= div_wait_counter + 64'd1;
            end
            if (icache_hit_i) begin
                icache_hit_counter <= icache_hit_counter + 64'd1;
            end
            if (icache_miss_i) begin
                icache_miss_counter <= icache_miss_counter + 64'd1;
            end
            if (dcache_load_hit_i) begin
                dcache_load_hit_counter <= dcache_load_hit_counter + 64'd1;
            end
            if (dcache_load_miss_i) begin
                dcache_load_miss_counter <= dcache_load_miss_counter + 64'd1;
            end
            if (dcache_store_hit_i) begin
                dcache_store_hit_counter <= dcache_store_hit_counter + 64'd1;
            end
            if (dcache_store_miss_i) begin
                dcache_store_miss_counter <= dcache_store_miss_counter + 64'd1;
            end
            if (branch_redirect_i) begin
                branch_redirect_counter <= branch_redirect_counter + 64'd1;
            end
            if (branch_flush_i) begin
                branch_flush_counter <= branch_flush_counter + 64'd1;
            end
            prefetch_occupancy_sum_counter <= prefetch_occupancy_sum_counter + {61'h0, prefetch_occupancy_i};
            if (prefetch_full_i) begin
                prefetch_full_counter <= prefetch_full_counter + 64'd1;
            end
            if (prefetch_stall_i) begin
                prefetch_stall_counter <= prefetch_stall_counter + 64'd1;
            end
            if (branch_predict_hit_i) begin
                branch_predict_hit_counter <= branch_predict_hit_counter + 64'd1;
            end
            if (branch_predict_miss_i) begin
                branch_predict_miss_counter <= branch_predict_miss_counter + 64'd1;
            end
            if (dcache_load_miss_stall_i) begin
                dcache_load_miss_stall_counter <= dcache_load_miss_stall_counter + 64'd1;
            end
            if (dcache_store_wait_i) begin
                dcache_store_wait_counter <= dcache_store_wait_counter + 64'd1;
            end
            if (fetch_bus_wait_i) begin
                fetch_bus_wait_counter <= fetch_bus_wait_counter + 64'd1;
            end
            if (data_bus_wait_i) begin
                data_bus_wait_counter <= data_bus_wait_counter + 64'd1;
            end
            if (id_contention_i) begin
                id_contention_counter <= id_contention_counter + 64'd1;
            end
            if (store_buffer_enqueue_i) begin
                store_buffer_enqueue_counter <= store_buffer_enqueue_counter + 64'd1;
            end
            if (store_buffer_full_stall_i) begin
                store_buffer_full_stall_counter <= store_buffer_full_stall_counter + 64'd1;
            end
            if (store_buffer_drain_i) begin
                store_buffer_drain_counter <= store_buffer_drain_counter + 64'd1;
            end
            if (we_i == `WriteEnable) begin
                case (addr_i[7:0])
                    PMU_SIM_DONE: begin
                        sim_done_reg <= data_i;
                    end
                    PMU_SIM_TICKS: begin
                        sim_ticks_reg[31:0] <= data_i;
                    end
                    PMU_SIM_TICKSH: begin
                        sim_ticks_reg[63:32] <= data_i;
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    always @ (*) begin
        case (addr_i[7:0])
            PMU_CTRL: begin
                data_o = 32'h0;
            end
            PMU_CYCLE: begin
                data_o = cycle_counter[31:0];
            end
            PMU_CYCLEH: begin
                data_o = cycle_counter[63:32];
            end
            PMU_INST: begin
                data_o = inst_counter[31:0];
            end
            PMU_INSTH: begin
                data_o = inst_counter[63:32];
            end
            PMU_JUMP: begin
                data_o = jump_counter[31:0];
            end
            PMU_JUMPH: begin
                data_o = jump_counter[63:32];
            end
            PMU_LOAD: begin
                data_o = load_counter[31:0];
            end
            PMU_LOADH: begin
                data_o = load_counter[63:32];
            end
            PMU_STORE: begin
                data_o = store_counter[31:0];
            end
            PMU_STOREH: begin
                data_o = store_counter[63:32];
            end
            PMU_HOLD: begin
                data_o = hold_counter[31:0];
            end
            PMU_HOLDH: begin
                data_o = hold_counter[63:32];
            end
            PMU_INT: begin
                data_o = int_counter[31:0];
            end
            PMU_INTH: begin
                data_o = int_counter[63:32];
            end
            PMU_DIV_WAIT: begin
                data_o = div_wait_counter[31:0];
            end
            PMU_DIV_WAITH: begin
                data_o = div_wait_counter[63:32];
            end
            PMU_SIM_DONE: begin
                data_o = sim_done_reg;
            end
            PMU_SIM_TICKS: begin
                data_o = sim_ticks_reg[31:0];
            end
            PMU_SIM_TICKSH: begin
                data_o = sim_ticks_reg[63:32];
            end
            PMU_ICACHE_HIT: begin
                data_o = icache_hit_counter[31:0];
            end
            PMU_ICACHE_MISS: begin
                data_o = icache_miss_counter[31:0];
            end
            PMU_DCACHE_LOAD_HIT: begin
                data_o = dcache_load_hit_counter[31:0];
            end
            PMU_DCACHE_LOAD_MISS: begin
                data_o = dcache_load_miss_counter[31:0];
            end
            PMU_DCACHE_STORE_HIT: begin
                data_o = dcache_store_hit_counter[31:0];
            end
            PMU_DCACHE_STORE_MISS: begin
                data_o = dcache_store_miss_counter[31:0];
            end
            PMU_BRANCH_REDIRECT: begin
                data_o = branch_redirect_counter[31:0];
            end
            PMU_BRANCH_FLUSH: begin
                data_o = branch_flush_counter[31:0];
            end
            PMU_PREFETCH_OCC_SUM: begin
                data_o = prefetch_occupancy_sum_counter[31:0];
            end
            PMU_PREFETCH_FULL: begin
                data_o = prefetch_full_counter[31:0];
            end
            PMU_PREFETCH_STALL: begin
                data_o = prefetch_stall_counter[31:0];
            end
            PMU_BRANCH_PRED_HIT: begin
                data_o = branch_predict_hit_counter[31:0];
            end
            PMU_BRANCH_PRED_MISS: begin
                data_o = branch_predict_miss_counter[31:0];
            end
            PMU_DCACHE_LOAD_MISS_STALL: begin
                data_o = dcache_load_miss_stall_counter[31:0];
            end
            PMU_DCACHE_STORE_WAIT: begin
                data_o = dcache_store_wait_counter[31:0];
            end
            PMU_FETCH_BUS_WAIT: begin
                data_o = fetch_bus_wait_counter[31:0];
            end
            PMU_DATA_BUS_WAIT: begin
                data_o = data_bus_wait_counter[31:0];
            end
            PMU_ID_CONTENTION: begin
                data_o = id_contention_counter[31:0];
            end
            PMU_STORE_BUFFER_ENQUEUE: begin
                data_o = store_buffer_enqueue_counter[31:0];
            end
            PMU_STORE_BUFFER_FULL_STALL: begin
                data_o = store_buffer_full_stall_counter[31:0];
            end
            PMU_STORE_BUFFER_DRAIN: begin
                data_o = store_buffer_drain_counter[31:0];
            end
            default: begin
                data_o = `ZeroWord;
            end
        endcase
    end

endmodule


