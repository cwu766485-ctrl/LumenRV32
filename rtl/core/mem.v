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

// Complete memory transactions and commit register / CSR writes.
// -----------------------------------------------------------------------------
// MEM 访存阶段
// -----------------------------------------------------------------------------
// 作用：
// - 接收 EX/MEM 固化后的访存请求，把地址/写数据/写掩码传给 D-cache 或 memory interface。
// - 对 load 返回的 32-bit word 按 funct3 和地址低两位做 LB/LH/LW/LBU/LHU 解析。
// - 在 mem_req_i 有效但 mem_ready_i 未返回时拉高 hold_flag_o，要求 ctrl 冻结后端。
// - 非 load 指令直接透传 EX 的寄存器/CSR 写回数据。
// 面试重点：
// - MEM 不重新计算地址，只完成“等待 memory ready”和“load 数据抽取/扩展”。
// - store 是否完成由 mem_ready_i 决定，等待期间 EX/MEM 会保持请求稳定。
// -----------------------------------------------------------------------------
module mem(

    input wire rst,

    input wire[`InstBus] inst_i,
    input wire[`RegBus] reg_wdata_i,
    input wire reg_we_i,
    input wire[`RegAddrBus] reg_waddr_i,
    input wire[`RegBus] csr_wdata_i,
    input wire csr_we_i,
    input wire[`MemAddrBus] csr_waddr_i,
    input wire[`MemAddrBus] mem_addr_i,
    input wire[`MemBus] mem_wdata_i,
    input wire[`MemMaskBus] mem_wmask_i,
    input wire mem_we_i,
    input wire mem_req_i,
    input wire mem_load_i,
    input wire[2:0] mem_funct3_i,
    input wire[1:0] mem_addr_lsb_i,

    input wire[`MemBus] mem_rdata_i,
    input wire mem_ready_i,

    output wire[`MemAddrBus] mem_addr_o,
    output wire[`MemBus] mem_wdata_o,
    output wire[`MemMaskBus] mem_wmask_o,
    output wire mem_we_o,
    output wire mem_req_o,

    output wire[`InstBus] inst_o,
    output wire[`RegBus] reg_wdata_o,
    output wire reg_we_o,
    output wire[`RegAddrBus] reg_waddr_o,
    output wire[`RegBus] csr_wdata_o,
    output wire csr_we_o,
    output wire[`MemAddrBus] csr_waddr_o,

    output wire hold_flag_o

    );

    // 从一个 32-bit word 中取出 byte/halfword/word，并根据指令类型做符号扩展或零扩展。
    function [`RegBus] decode_load_data;
        input [2:0] load_funct3;
        input [1:0] addr_lsb;
        input [`MemBus] word_data;
        begin
            case (load_funct3)
                `INST_LB: begin
                    case (addr_lsb)
                        2'b00: decode_load_data = {{24{word_data[7]}}, word_data[7:0]};
                        2'b01: decode_load_data = {{24{word_data[15]}}, word_data[15:8]};
                        2'b10: decode_load_data = {{24{word_data[23]}}, word_data[23:16]};
                        default: decode_load_data = {{24{word_data[31]}}, word_data[31:24]};
                    endcase
                end
                `INST_LH: begin
                    if (addr_lsb[1] == 1'b0) begin
                        decode_load_data = {{16{word_data[15]}}, word_data[15:0]};
                    end else begin
                        decode_load_data = {{16{word_data[31]}}, word_data[31:16]};
                    end
                end
                `INST_LW: begin
                    decode_load_data = word_data;
                end
                `INST_LBU: begin
                    case (addr_lsb)
                        2'b00: decode_load_data = {24'h0, word_data[7:0]};
                        2'b01: decode_load_data = {24'h0, word_data[15:8]};
                        2'b10: decode_load_data = {24'h0, word_data[23:16]};
                        default: decode_load_data = {24'h0, word_data[31:24]};
                    endcase
                end
                default: begin
                    if (addr_lsb[1] == 1'b0) begin
                        decode_load_data = {16'h0, word_data[15:0]};
                    end else begin
                        decode_load_data = {16'h0, word_data[31:16]};
                    end
                end
            endcase
        end
    endfunction

    // 有效访存请求尚未 ready 时，通知 ctrl 输出 Hold_Ex。
    wire mem_wait = (mem_req_i == `MEM_REQ) && (mem_ready_i != `True);

    assign mem_addr_o = mem_addr_i;
    assign mem_wdata_o = mem_wdata_i;
    assign mem_wmask_o = mem_wmask_i;
    assign mem_we_o = mem_we_i;
    assign mem_req_o = mem_req_i;

    assign inst_o = inst_i;
    // load 指令写回 memory 返回值；普通 ALU/CSR 类指令透传前级结果。
    assign reg_wdata_o = (mem_load_i == `True) ? decode_load_data(mem_funct3_i, mem_addr_lsb_i, mem_rdata_i) : reg_wdata_i;
    assign reg_we_o = (rst == `RstEnable) ? `WriteDisable :
                      ((mem_load_i == `True) ? ((mem_ready_i == `True) ? reg_we_i : `WriteDisable) : reg_we_i);
    assign reg_waddr_o = reg_waddr_i;

    assign csr_wdata_o = csr_wdata_i;
    assign csr_we_o = (rst == `RstEnable) ? `WriteDisable : csr_we_i;
    assign csr_waddr_o = csr_waddr_i;

    assign hold_flag_o = mem_wait;

endmodule
