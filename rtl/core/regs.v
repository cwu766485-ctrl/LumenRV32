`timescale 1 ns / 1 ps

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

`include "defines.v"

// -----------------------------------------------------------------------------
// 通用寄存器堆
// -----------------------------------------------------------------------------
// 作用：
// - 实现 RV32 的 32 个 32-bit 通用寄存器 x0-x31。
// - x0 固定为 0，任何对 x0 的写入都会被丢弃。
// - ID 阶段有两个组合读端口，WB 阶段有一个同步写端口。
// - JTAG 调试器也可以读写寄存器，用于暂停后检查/修改 CPU 状态。
//
// 相关宏实际数值：
// - RegNum      = 32，一共有 32 个通用寄存器。
// - RegAddrBus  = 4:0，寄存器地址 5 bit，可索引 x0-x31。
// - RegBus      = 31:0，寄存器数据 32 bit。
// - ZeroReg     = 5'h0，也就是 x0。
// - ZeroWord    = 32'h0。
// - WriteEnable = 1'b1，WriteDisable = 1'b0。
// - RstDisable  = 1'b1，表示复位未使能，CPU 正常运行。
//
// 和 D-cache 的区别：
// - regs.v 是 CPU 内部的通用寄存器堆，保存 x0-x31 这些架构寄存器。
// - D-cache 是数据存储层缓存，服务 load/store，缓存的是内存地址对应的数据。
// - 指令 add/sub/and/or 等直接读 regs.v，不访问 D-cache。
// - 指令 lw/sw 先读 regs.v 得到 base/data，再通过 EX/MEM/D-cache 访问内存。
//
// 面试重点：
// - 同拍写后读通过旁路返回 wdata_i，避免 WB 写回与 ID 读同一寄存器时读到旧值。
// - EX/MEM/WB 更早阶段的 RAW 旁路在 id.v 中完成。
// - 这个模块没有复杂状态机，核心是“同步写 + 组合读 + x0 恒 0”。
// -----------------------------------------------------------------------------
module regs(

    input wire clk,
    input wire rst,                         // 系统复位；这里用 rst == RstDisable(1'b1) 表示正常运行

    // from WB
    input wire we_i,                        // WB 阶段写使能，WriteEnable=1'b1 时写入
    input wire[`RegAddrBus] waddr_i,        // WB 阶段写地址，5 bit，对应 x0-x31
    input wire[`RegBus] wdata_i,            // WB 阶段写数据，32 bit

    // from jtag
    input wire jtag_we_i,                   // JTAG 写使能，调试器可直接修改通用寄存器
    input wire[`RegAddrBus] jtag_addr_i,    // JTAG 访问地址，5 bit
    input wire[`RegBus] jtag_data_i,        // JTAG 写数据，32 bit

    // from id
    input wire[`RegAddrBus] raddr1_i,       // ID 阶段读端口 1 地址，通常是 rs1

    // to id
    output reg[`RegBus] rdata1_o,           // 读端口 1 数据，组合输出

    // from id
    input wire[`RegAddrBus] raddr2_i,       // ID 阶段读端口 2 地址，通常是 rs2

    // to id
    output reg[`RegBus] rdata2_o,           // 读端口 2 数据，组合输出

    // to jtag
    output reg[`RegBus] jtag_data_o         // JTAG 读数据，组合输出

    );

    // 32 x 32-bit 寄存器数组：
    // - regs[0] 对应 x0，但写逻辑会禁止写 x0，读逻辑也强制 x0 返回 0。
    // - regs[1] 常用作 ra，regs[2] 常用作 sp，但硬件本身不关心 ABI 名字。
    reg[`RegBus] regs[0:`RegNum - 1];

    // 同步写端口：
    // - always @(posedge clk) 表示只有时钟上升沿才真正改写寄存器数组。
    // - rst == RstDisable(1'b1) 时才允许写；复位有效时不写。
    // - CPU 正常 WB 写优先于 JTAG 写。
    // - 写 x0/ZeroReg(5'h0) 会被丢弃，保证 x0 恒为 0。
    integer reset_idx;
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            // Give simulation and FPGA bring-up a deterministic architectural
            // state. Software may save a callee-saved register before it has
            // assigned a value; leaving the array uninitialized would then
            // propagate X values through the stack and obscure real failures.
            for (reset_idx = 0; reset_idx < `RegNum; reset_idx = reset_idx + 1) begin
                regs[reset_idx] <= `ZeroWord;
            end
        end else begin
            // CPU 正常写回。
            if ((we_i == `WriteEnable) && (waddr_i != `ZeroReg)) begin
                regs[waddr_i] <= wdata_i;
            end else if ((jtag_we_i == `WriteEnable) && (jtag_addr_i != `ZeroReg)) begin
                // CPU 本拍没有正常写回时，允许 JTAG 修改寄存器。
                regs[jtag_addr_i] <= jtag_data_i;
            end
        end
    end

    // 读端口 1：组合读。
    // - always @(*) 表示输入地址或写回信号变化时，读数据立即重新计算。
    // - raddr1_i == x0 时永远返回 0。
    // - 如果本拍 WB 正在写同一个寄存器，直接返回 wdata_i。
    //   这叫“同拍写后读旁路”，避免 ID 读到旧 regs[] 内容。
    always @ (*) begin
        if (raddr1_i == `ZeroReg) begin
            rdata1_o = `ZeroWord;
        // WB 同拍写回同一寄存器时返回新值。
        end else if (raddr1_i == waddr_i && we_i == `WriteEnable) begin
            rdata1_o = wdata_i;
        end else begin
            rdata1_o = regs[raddr1_i];
        end
    end

    // 读端口 2：组合读，逻辑同读端口 1。
    // - 端口 1/2 独立，所以 R-type 指令可以同一拍读 rs1 和 rs2。
    always @ (*) begin
        if (raddr2_i == `ZeroReg) begin
            rdata2_o = `ZeroWord;
        // WB 同拍写回同一寄存器时返回新值。
        end else if (raddr2_i == waddr_i && we_i == `WriteEnable) begin
            rdata2_o = wdata_i;
        end else begin
            rdata2_o = regs[raddr2_i];
        end
    end

    // JTAG 读端口：组合读。
    // - 调试器可异步观察寄存器值。
    // - x0 仍返回 0。
    // - 这里没有对 JTAG 同拍写后读做额外旁路；调试场景通常不要求和 CPU 读端口一样紧。
    always @ (*) begin
        if (jtag_addr_i == `ZeroReg) begin
            jtag_data_o = `ZeroWord;
        end else begin
            jtag_data_o = regs[jtag_addr_i];
        end
    end

endmodule


