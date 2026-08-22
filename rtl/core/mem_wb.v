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

// Carry MEM outputs into the WB stage.
// -----------------------------------------------------------------------------
// MEM/WB 流水线寄存器
// -----------------------------------------------------------------------------
// 作用：
// - 锁存 MEM 阶段完成后的寄存器写回和 CSR 写回信息。
// - WB 阶段没有单独模块，regs.v/csr_reg.v 直接使用这里的输出提交结果。
// - Hold_Ex 时保持当前 WB 输入，避免 MEM 正在等待时写回信息被年轻指令覆盖。
// 面试重点：通用寄存器和 CSR 的最终提交点都在这一拍之后。
// -----------------------------------------------------------------------------
module mem_wb(

    input wire clk,
    input wire rst,

    input wire[`InstBus] inst_i,
    input wire[`RegBus] reg_wdata_i,
    input wire reg_we_i,
    input wire[`RegAddrBus] reg_waddr_i,
    input wire[`RegBus] csr_wdata_i,
    input wire csr_we_i,
    input wire[`MemAddrBus] csr_waddr_i,

    input wire[`Hold_Flag_Bus] hold_flag_i,

    output reg[`InstBus] inst_o,
    output reg[`RegBus] reg_wdata_o,
    output reg reg_we_o,
    output reg[`RegAddrBus] reg_waddr_o,
    output reg[`RegBus] csr_wdata_o,
    output reg csr_we_o,
    output reg[`MemAddrBus] csr_waddr_o

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
        end else if (hold_flag_i == `Hold_Ex) begin
            // 后端 stall 时保持写回信息稳定。
            inst_o <= inst_o;
            reg_wdata_o <= reg_wdata_o;
            reg_we_o <= reg_we_o;
            reg_waddr_o <= reg_waddr_o;
            csr_wdata_o <= csr_wdata_o;
            csr_we_o <= csr_we_o;
            csr_waddr_o <= csr_waddr_o;
        end else begin
            inst_o <= inst_i;
            reg_wdata_o <= reg_wdata_i;
            reg_we_o <= reg_we_i;
            reg_waddr_o <= reg_waddr_i;
            csr_wdata_o <= csr_wdata_i;
            csr_we_o <= csr_we_i;
            csr_waddr_o <= csr_waddr_i;
        end
    end

endmodule
