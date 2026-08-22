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

// -----------------------------------------------------------------------------
// CSR 寄存器文件
// -----------------------------------------------------------------------------
// 作用：
// - 保存 machine-mode 下常用 CSR：mtvec、mepc、mcause、mie、mstatus、mscratch。
// - 提供 cycle/cycleh 64-bit 周期计数器，软件可用 CSR 指令读取性能/时间。
// - EX/WB 路径可以通过 CSR 指令读写；CLINT 也可以在异常/中断入口时写 mepc/mcause/mstatus。
// - 读路径带写后读旁路：同一拍写某 CSR 又读同一 CSR 时，直接返回新值。
// 面试重点：
// - 普通 CSR 指令写入来自 WB 阶段，异常/中断状态写入来自 clint.v。
// - global_int_en_o 当前取 mstatus.MIE(bit3)，决定外部中断是否可进入。
// -----------------------------------------------------------------------------
module csr_reg(

    input wire clk,
    input wire rst,

    // from WB/EX CSR path
    input wire we_i,                        // CSR 指令写使能
    input wire[`MemAddrBus] raddr_i,        // CSR 指令读地址
    input wire[`MemAddrBus] waddr_i,        // CSR 指令写地址
    input wire[`RegBus] data_i,             // CSR 指令写数据

    // from clint
    input wire clint_we_i,                  // CLINT 写 CSR 使能
    input wire[`MemAddrBus] clint_raddr_i,  // CLINT 读 CSR 地址
    input wire[`MemAddrBus] clint_waddr_i,  // CLINT 写 CSR 地址
    input wire[`RegBus] clint_data_i,       // CLINT 写 CSR 数据

    output wire global_int_en_o,            // 全局中断使能，来自 mstatus.MIE

    // to clint
    output reg[`RegBus] clint_data_o,       // CLINT 读出的 CSR 数据
    output wire[`RegBus] clint_csr_mtvec,   // mtvec
    output wire[`RegBus] clint_csr_mepc,    // mepc
    output wire[`RegBus] clint_csr_mstatus, // mstatus

    // to ex
    output reg[`RegBus] data_o              // CSR 指令读出的数据

    );

    reg[`DoubleRegBus] cycle;
    reg[`RegBus] mtvec;
    reg[`RegBus] mcause;
    reg[`RegBus] mepc;
    reg[`RegBus] mie;
    reg[`RegBus] mstatus;
    reg[`RegBus] mscratch;

    assign global_int_en_o = (mstatus[3] == 1'b1)? `True: `False;

    assign clint_csr_mtvec = mtvec;
    assign clint_csr_mepc = mepc;
    assign clint_csr_mstatus = mstatus;

    // cycle/cycleh：每个时钟加 1，复位清 0。
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            cycle <= {`ZeroWord, `ZeroWord};
        end else begin
            cycle <= cycle + 1'b1;
        end
    end

    // CSR 写入仲裁：
    // - 普通 CSR 指令写入优先。
    // - 若本拍没有普通 CSR 写入，CLINT 可更新异常/中断相关 CSR。
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            mtvec <= `ZeroWord;
            mcause <= `ZeroWord;
            mepc <= `ZeroWord;
            mie <= `ZeroWord;
            mstatus <= `ZeroWord;
            mscratch <= `ZeroWord;
        end else begin
            // WB 阶段提交 CSR 指令写入。
            if (we_i == `WriteEnable) begin
                case (waddr_i[11:0])
                    `CSR_MTVEC: begin
                        mtvec <= data_i;
                    end
                    `CSR_MCAUSE: begin
                        mcause <= data_i;
                    end
                    `CSR_MEPC: begin
                        mepc <= data_i;
                    end
                    `CSR_MIE: begin
                        mie <= data_i;
                    end
                    `CSR_MSTATUS: begin
                        mstatus <= data_i;
                    end
                    `CSR_MSCRATCH: begin
                        mscratch <= data_i;
                    end
                    default: begin

                    end
                endcase
            // CLINT 在 trap entry/mret 时更新 mepc/mcause/mstatus。
            end else if (clint_we_i == `WriteEnable) begin
                case (clint_waddr_i[11:0])
                    `CSR_MTVEC: begin
                        mtvec <= clint_data_i;
                    end
                    `CSR_MCAUSE: begin
                        mcause <= clint_data_i;
                    end
                    `CSR_MEPC: begin
                        mepc <= clint_data_i;
                    end
                    `CSR_MIE: begin
                        mie <= clint_data_i;
                    end
                    `CSR_MSTATUS: begin
                        mstatus <= clint_data_i;
                    end
                    `CSR_MSCRATCH: begin
                        mscratch <= clint_data_i;
                    end
                    default: begin

                    end
                endcase
            end
        end
    end

    // CSR 指令读路径，带同拍写后读旁路。
    always @ (*) begin
        if ((waddr_i[11:0] == raddr_i[11:0]) && (we_i == `WriteEnable)) begin
            data_o = data_i;
        end else begin
            case (raddr_i[11:0])
                `CSR_CYCLE: begin
                    data_o = cycle[31:0];
                end
                `CSR_CYCLEH: begin
                    data_o = cycle[63:32];
                end
                `CSR_MTVEC: begin
                    data_o = mtvec;
                end
                `CSR_MCAUSE: begin
                    data_o = mcause;
                end
                `CSR_MEPC: begin
                    data_o = mepc;
                end
                `CSR_MIE: begin
                    data_o = mie;
                end
                `CSR_MSTATUS: begin
                    data_o = mstatus;
                end
                `CSR_MSCRATCH: begin
                    data_o = mscratch;
                end
                default: begin
                    data_o = `ZeroWord;
                end
            endcase
        end
    end

    // CLINT 读路径，供异常/中断状态机读取 CSR 当前值。
    always @ (*) begin
        if ((clint_waddr_i[11:0] == clint_raddr_i[11:0]) && (clint_we_i == `WriteEnable)) begin
            clint_data_o = clint_data_i;
        end else begin
            case (clint_raddr_i[11:0])
                `CSR_CYCLE: begin
                    clint_data_o = cycle[31:0];
                end
                `CSR_CYCLEH: begin
                    clint_data_o = cycle[63:32];
                end
                `CSR_MTVEC: begin
                    clint_data_o = mtvec;
                end
                `CSR_MCAUSE: begin
                    clint_data_o = mcause;
                end
                `CSR_MEPC: begin
                    clint_data_o = mepc;
                end
                `CSR_MIE: begin
                    clint_data_o = mie;
                end
                `CSR_MSTATUS: begin
                    clint_data_o = mstatus;
                end
                `CSR_MSCRATCH: begin
                    clint_data_o = mscratch;
                end
                default: begin
                    clint_data_o = `ZeroWord;
                end
            endcase
        end
    end

endmodule


