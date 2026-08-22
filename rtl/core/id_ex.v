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

// ID/EX pipeline register.  It latches decoded operands/control from id.v and
// presents stable inputs to ex.v.
//
// Hold policy:
// - Hold_Id / Hold_Load insert a bubble.
// - Hold_Ex keeps the current EX-stage instruction stable because the next
//   stage is applying backpressure and cannot accept a new transaction yet.
module id_ex(

    input wire clk,
    input wire rst,

    input wire[`InstBus] inst_i,
    input wire[`InstAddrBus] inst_addr_i,
    input wire reg_we_i,
    input wire[`RegAddrBus] reg_waddr_i,
    input wire[`RegBus] reg1_rdata_i,
    input wire[`RegBus] reg2_rdata_i,
    input wire csr_we_i,
    input wire[`MemAddrBus] csr_waddr_i,
    input wire[`RegBus] csr_rdata_i,
    input wire[`MemAddrBus] op1_i,
    input wire[`MemAddrBus] op2_i,
    input wire[`MemAddrBus] op1_jump_i,
    input wire[`MemAddrBus] op2_jump_i,
    input wire predict_taken_i,
    input wire[`InstAddrBus] predict_target_i,
    input wire[`Hold_Flag_Bus] hold_flag_i,

    output wire[`MemAddrBus] op1_o,
    output wire[`MemAddrBus] op2_o,
    output wire[`MemAddrBus] op1_jump_o,
    output wire[`MemAddrBus] op2_jump_o,
    output wire predict_taken_o,
    output wire[`InstAddrBus] predict_target_o,
    output wire[`InstBus] inst_o,
    output wire[`InstAddrBus] inst_addr_o,
    output wire reg_we_o,
    output wire[`RegAddrBus] reg_waddr_o,
    output wire[`RegBus] reg1_rdata_o,
    output wire[`RegBus] reg2_rdata_o,
    output wire csr_we_o,
    output wire[`MemAddrBus] csr_waddr_o,
    output wire[`RegBus] csr_rdata_o

    );

    reg[`InstBus] inst;
    reg[`InstAddrBus] inst_addr;
    reg reg_we;
    reg[`RegAddrBus] reg_waddr;
    reg[`RegBus] reg1_rdata;
    reg[`RegBus] reg2_rdata;
    reg csr_we;
    reg[`MemAddrBus] csr_waddr;
    reg[`RegBus] csr_rdata;
    reg[`MemAddrBus] op1;
    reg[`MemAddrBus] op2;
    reg[`MemAddrBus] op1_jump;
    reg[`MemAddrBus] op2_jump;
    reg predict_taken;
    reg[`InstAddrBus] predict_target;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            inst <= `INST_NOP;
            inst_addr <= `ZeroWord;
            reg_we <= `WriteDisable;
            reg_waddr <= `ZeroReg;
            reg1_rdata <= `ZeroWord;
            reg2_rdata <= `ZeroWord;
            csr_we <= `WriteDisable;
            csr_waddr <= `ZeroWord;
            csr_rdata <= `ZeroWord;
            op1 <= `ZeroWord;
            op2 <= `ZeroWord;
            op1_jump <= `ZeroWord;
            op2_jump <= `ZeroWord;
            predict_taken <= `False;
            predict_target <= `ZeroWord;
        end else if (hold_flag_i == `Hold_Id || hold_flag_i == `Hold_Load) begin
            inst <= `INST_NOP;
            inst_addr <= `ZeroWord;
            reg_we <= `WriteDisable;
            reg_waddr <= `ZeroReg;
            reg1_rdata <= `ZeroWord;
            reg2_rdata <= `ZeroWord;
            csr_we <= `WriteDisable;
            csr_waddr <= `ZeroWord;
            csr_rdata <= `ZeroWord;
            op1 <= `ZeroWord;
            op2 <= `ZeroWord;
            op1_jump <= `ZeroWord;
            op2_jump <= `ZeroWord;
            predict_taken <= `False;
            predict_target <= `ZeroWord;
        end else if (hold_flag_i == `Hold_Ex) begin
            inst <= inst;
            inst_addr <= inst_addr;
            reg_we <= reg_we;
            reg_waddr <= reg_waddr;
            reg1_rdata <= reg1_rdata;
            reg2_rdata <= reg2_rdata;
            csr_we <= csr_we;
            csr_waddr <= csr_waddr;
            csr_rdata <= csr_rdata;
            op1 <= op1;
            op2 <= op2;
            op1_jump <= op1_jump;
            op2_jump <= op2_jump;
            predict_taken <= predict_taken;
            predict_target <= predict_target;
        end else begin
            inst <= inst_i;
            inst_addr <= inst_addr_i;
            reg_we <= reg_we_i;
            reg_waddr <= reg_waddr_i;
            reg1_rdata <= reg1_rdata_i;
            reg2_rdata <= reg2_rdata_i;
            csr_we <= csr_we_i;
            csr_waddr <= csr_waddr_i;
            csr_rdata <= csr_rdata_i;
            op1 <= op1_i;
            op2 <= op2_i;
            op1_jump <= op1_jump_i;
            op2_jump <= op2_jump_i;
            predict_taken <= predict_taken_i;
            predict_target <= predict_target_i;
        end
    end

    assign inst_o = inst;
    assign inst_addr_o = inst_addr;
    assign reg_we_o = reg_we;
    assign reg_waddr_o = reg_waddr;
    assign reg1_rdata_o = reg1_rdata;
    assign reg2_rdata_o = reg2_rdata;
    assign csr_we_o = csr_we;
    assign csr_waddr_o = csr_waddr;
    assign csr_rdata_o = csr_rdata;
    assign op1_o = op1;
    assign op2_o = op2;
    assign op1_jump_o = op1_jump;
    assign op2_jump_o = op2_jump;
    assign predict_taken_o = predict_taken;
    assign predict_target_o = predict_target;

endmodule
