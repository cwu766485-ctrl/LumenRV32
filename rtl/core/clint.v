`timescale 1 ns / 1 ps

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

`include "defines.v"


// core local interruptor module
// -----------------------------------------------------------------------------
// CLINT / trap 控制模块
// -----------------------------------------------------------------------------
// 作用：
// - 处理同步异常：ECALL、EBREAK。
// - 处理异步外部中断：int_flag_i 非 0 且 mstatus.MIE 允许。
// - 处理 MRET 返回：恢复 mstatus.MIE，并跳转回 mepc。
// - 按 RISC-V machine-mode trap 流程更新 mepc、mstatus、mcause。
// - 在 CSR 更新期间拉高 hold_flag_o，要求流水线暂停，避免 trap 状态被年轻指令破坏。
// 面试重点：
// - CLINT 不执行普通指令，只负责 trap 状态机和跳转目标 mtvec/mepc。
// - trap 真正重定向 PC 是通过 int_assert_o/int_addr_o 送到 EX，再由 ctrl/pc_reg 生效。
// -----------------------------------------------------------------------------
module clint(

    input wire clk,
    input wire rst,

    // from core
    input wire[`INT_BUS] int_flag_i,         // 外部中断标志

    // from id
    input wire[`InstBus] inst_i,             // 当前 ID 阶段指令
    input wire[`InstAddrBus] inst_addr_i,    // 当前 ID 阶段 PC

    // from ex
    input wire jump_flag_i,
    input wire[`InstAddrBus] jump_addr_i,
    input wire div_started_i,

    // from ctrl
    input wire[`Hold_Flag_Bus] hold_flag_i,  // 当前流水线暂停状态

    // from csr_reg
    input wire[`RegBus] data_i,              // CSR 读数据，本实现未显式使用
    input wire[`RegBus] csr_mtvec,           // trap 入口基地址 mtvec
    input wire[`RegBus] csr_mepc,            // 异常返回地址 mepc
    input wire[`RegBus] csr_mstatus,         // 机器状态寄存器 mstatus

    input wire global_int_en_i,              // 全局中断使能

    // to ctrl
    output wire hold_flag_o,                 // trap CSR 更新期间请求暂停流水线

    // to csr_reg
    output reg we_o,                         // 写 CSR 使能
    output reg[`MemAddrBus] waddr_o,         // 写 CSR 地址
    output reg[`MemAddrBus] raddr_o,         // 读 CSR 地址，当前保留
    output reg[`RegBus] data_o,              // 写 CSR 数据

    // to ex
    output reg[`InstAddrBus] int_addr_o,     // trap/mret 重定向地址
    output reg int_assert_o                  // trap/mret 重定向有效

    );


    // 中断/异常类型判断状态，组合生成。
    localparam S_INT_IDLE            = 4'b0001;
    localparam S_INT_SYNC_ASSERT     = 4'b0010;
    localparam S_INT_ASYNC_ASSERT    = 4'b0100;
    localparam S_INT_MRET            = 4'b1000;

    // CSR 更新微状态机。一次 trap entry 需要顺序写 mepc、mstatus、mcause。
    localparam S_CSR_IDLE            = 5'b00001;
    localparam S_CSR_MSTATUS         = 5'b00010;
    localparam S_CSR_MEPC            = 5'b00100;
    localparam S_CSR_MSTATUS_MRET    = 5'b01000;
    localparam S_CSR_MCAUSE          = 5'b10000;

    reg[3:0] int_state;
    reg[4:0] csr_state;
    reg[`InstAddrBus] inst_addr;
    reg[31:0] cause;


    assign hold_flag_o = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE))? `HoldEnable: `HoldDisable;


    // 判断本拍是否需要进入 trap 或执行 mret。
    always @ (*) begin
        if (rst == `RstEnable) begin
            int_state = S_INT_IDLE;
        end else begin
            if (inst_i == `INST_ECALL || inst_i == `INST_EBREAK) begin
                // 除法刚启动时先不接收同步异常，避免 div 控制流与 trap 控制流冲突。
                if (div_started_i == `DivStop) begin
                    int_state = S_INT_SYNC_ASSERT;
                end else begin
                    int_state = S_INT_IDLE;
                end
            end else if (int_flag_i != `INT_NONE && global_int_en_i == `True) begin
                int_state = S_INT_ASYNC_ASSERT;
            end else if (inst_i == `INST_MRET) begin
                int_state = S_INT_MRET;
            end else begin
                int_state = S_INT_IDLE;
            end
        end
    end

    // CSR 状态机：保存 trap 原因和返回地址，并安排后续 CSR 写入。
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            csr_state <= S_CSR_IDLE;
            cause <= `ZeroWord;
            inst_addr <= `ZeroWord;
        end else begin
            case (csr_state)
                S_CSR_IDLE: begin
                    // 同步异常：mepc 记录异常指令地址，mcause 记录异常原因。
                    if (int_state == S_INT_SYNC_ASSERT) begin
                        csr_state <= S_CSR_MEPC;
                        // 若异常发生在跳转相关路径上，修正要保存的指令地址。
                        if (jump_flag_i == `JumpEnable) begin
                            inst_addr <= jump_addr_i - 4'h4;
                        end else begin
                            inst_addr <= inst_addr_i;
                        end
                        case (inst_i)
                            `INST_ECALL: begin
                                cause <= 32'd11;
                            end
                            `INST_EBREAK: begin
                                cause <= 32'd3;
                            end
                            default: begin
                                cause <= 32'd10;
                            end
                        endcase
                    // 异步中断：mcause 最高位为 1，低位记录中断号。
                    end else if (int_state == S_INT_ASYNC_ASSERT) begin
                        // 当前实现将外部中断原因编码为 0x80000004。
                        cause <= 32'h80000004;
                        csr_state <= S_CSR_MEPC;
                        if (jump_flag_i == `JumpEnable) begin
                            inst_addr <= jump_addr_i;
                        // 除法启动会让 PC 预先跳到下一条，保存 mepc 时需要回退。
                        end else if (div_started_i == `DivStart) begin
                            inst_addr <= inst_addr_i - 4'h4;
                        end else begin
                            inst_addr <= inst_addr_i;
                        end
                    // MRET：恢复中断使能并跳回 mepc。
                    end else if (int_state == S_INT_MRET) begin
                        csr_state <= S_CSR_MSTATUS_MRET;
                    end
                end
                S_CSR_MEPC: begin
                    csr_state <= S_CSR_MSTATUS;
                end
                S_CSR_MSTATUS: begin
                    csr_state <= S_CSR_MCAUSE;
                end
                S_CSR_MCAUSE: begin
                    csr_state <= S_CSR_IDLE;
                end
                S_CSR_MSTATUS_MRET: begin
                    csr_state <= S_CSR_IDLE;
                end
                default: begin
                    csr_state <= S_CSR_IDLE;
                end
            endcase
        end
    end

    // 按 CSR 微状态实际写 CSR。
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            we_o <= `WriteDisable;
            waddr_o <= `ZeroWord;
            data_o <= `ZeroWord;
        end else begin
            case (csr_state)
                // 保存 trap 返回地址。
                S_CSR_MEPC: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MEPC};
                    data_o <= inst_addr;
                end
                // 保存 trap 原因。
                S_CSR_MCAUSE: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MCAUSE};
                    data_o <= cause;
                end
                // trap entry：清 mstatus.MIE，关闭全局中断。
                S_CSR_MSTATUS: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {csr_mstatus[31:4], 1'b0, csr_mstatus[2:0]};
                end
                // mret：用 MPIE(bit7) 恢复 MIE(bit3)。
                S_CSR_MSTATUS_MRET: begin
                    we_o <= `WriteEnable;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {csr_mstatus[31:4], csr_mstatus[7], csr_mstatus[2:0]};
                end
                default: begin
                    we_o <= `WriteDisable;
                    waddr_o <= `ZeroWord;
                    data_o <= `ZeroWord;
                end
            endcase
        end
    end

    // 向 EX 发出重定向请求：trap 跳 mtvec，mret 跳 mepc。
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            int_assert_o <= `INT_DEASSERT;
            int_addr_o <= `ZeroWord;
        end else begin
            case (csr_state)
                // mcause 写完后 trap 状态完整，可以跳转到 mtvec。
                S_CSR_MCAUSE: begin
                    int_assert_o <= `INT_ASSERT;
                    int_addr_o <= csr_mtvec;
                end
                // mret 恢复状态后跳回 mepc。
                S_CSR_MSTATUS_MRET: begin
                    int_assert_o <= `INT_ASSERT;
                    int_addr_o <= csr_mepc;
                end
                default: begin
                    int_assert_o <= `INT_DEASSERT;
                    int_addr_o <= `ZeroWord;
                end
            endcase
        end
    end

endmodule


