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

// Carry EX outputs into the MEM stage. When MEM is waiting on a slow
// target, freeze the stage and keep the request stable.
// -----------------------------------------------------------------------------
// EX/MEM 流水线寄存器
// -----------------------------------------------------------------------------
// 作用：
// - 锁存 EX 产生的 ALU/CSR 写回结果，以及 load/store 的地址、写数据、字节掩码。
// - 当 MEM 正在等待 memory interface/cache/外设返回时，hold_flag_i == Hold_Ex，本寄存器保持不变。
// - 保持不变的意义是：总线地址、写数据、wmask、读写方向必须稳定到 ready 返回。
// 面试重点：load/store 请求不是在 MEM 临时重新计算，而是在 EX 生成后由此寄存器固化。
// -----------------------------------------------------------------------------
module ex_mem(

    input wire clk,
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

    input wire[`Hold_Flag_Bus] hold_flag_i,

    output reg[`InstBus] inst_o,
    output reg[`RegBus] reg_wdata_o,
    output reg reg_we_o,
    output reg[`RegAddrBus] reg_waddr_o,
    output reg[`RegBus] csr_wdata_o,
    output reg csr_we_o,
    output reg[`MemAddrBus] csr_waddr_o,
    output reg[`MemAddrBus] mem_addr_o,
    output reg[`MemBus] mem_wdata_o,
    output reg[`MemMaskBus] mem_wmask_o,
    output reg mem_we_o,
    output reg mem_req_o,
    output reg mem_load_o,
    output reg[2:0] mem_funct3_o,
    output reg[1:0] mem_addr_lsb_o

    );

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            inst_o <= `INST_NOP;
            reg_wdata_o <= `ZeroWord;
            reg_we_o <= `WriteDisable;
            reg_waddr_o <= `ZeroReg;
            csr_wdata_o <= `ZeroWord;
            csr_we_o <= `WriteDisable;
            csr_waddr_o <= `ZeroWord;
            mem_addr_o <= `ZeroWord;
            mem_wdata_o <= `ZeroWord;
            mem_wmask_o <= 4'b1111;
            mem_we_o <= `WriteDisable;
            mem_req_o <= `MEM_NREQ;
            mem_load_o <= `False;
            mem_funct3_o <= 3'b0;
            mem_addr_lsb_o <= 2'b0;
        end else if (hold_flag_i == `Hold_Ex) begin
            // 慢外设/DDR/cache miss 等待期间保持同一笔事务，不让请求抖动。
            inst_o <= inst_o;
            reg_wdata_o <= reg_wdata_o;
            reg_we_o <= reg_we_o;
            reg_waddr_o <= reg_waddr_o;
            csr_wdata_o <= csr_wdata_o;
            csr_we_o <= csr_we_o;
            csr_waddr_o <= csr_waddr_o;
            mem_addr_o <= mem_addr_o;
            mem_wdata_o <= mem_wdata_o;
            mem_wmask_o <= mem_wmask_o;
            mem_we_o <= mem_we_o;
            mem_req_o <= mem_req_o;
            mem_load_o <= mem_load_o;
            mem_funct3_o <= mem_funct3_o;
            mem_addr_lsb_o <= mem_addr_lsb_o;
        end else begin
            inst_o <= inst_i;
            reg_wdata_o <= reg_wdata_i;
            reg_we_o <= reg_we_i;
            reg_waddr_o <= reg_waddr_i;
            csr_wdata_o <= csr_wdata_i;
            csr_we_o <= csr_we_i;
            csr_waddr_o <= csr_waddr_i;
            mem_addr_o <= mem_addr_i;
            mem_wdata_o <= mem_wdata_i;
            mem_wmask_o <= mem_wmask_i;
            mem_we_o <= mem_we_i;
            mem_req_o <= mem_req_i;
            mem_load_o <= mem_load_i;
            mem_funct3_o <= mem_funct3_i;
            mem_addr_lsb_o <= mem_addr_lsb_i;
        end
    end

endmodule
