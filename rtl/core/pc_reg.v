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
// PC 寄存器
// -----------------------------------------------------------------------------
// 作用：
// - 保存当前取指地址，是五级流水线最前端的状态寄存器。
// - 正常情况下每拍 PC + 4，表示顺序执行 RV32 定长 32-bit 指令。
// - 遇到跳转/异常/中断入口时，由 ctrl 转发 EX/CLINT 产生的 jump_addr 覆盖 PC。
// - 遇到取指、访存、除法、中断 CSR 更新等 stall 时保持 PC 不变。
// - JTAG reset 也会把 PC 拉回 CpuResetAddr，方便调试器重新启动程序。
// 面试重点：PC 本身不判断 hazard，只执行 ctrl.v 给出的统一控制决策。
// -----------------------------------------------------------------------------
module pc_reg(

    input wire clk,
    input wire rst,

    input wire jump_flag_i,                 // 跳转/异常/中断重定向有效；表示“现在要不要重定向 PC”。只要它是 JumpEnable，PC 就不再顺序 +4，而是跳到 jump_addr_i
    input wire[`InstAddrBus] jump_addr_i,   // 重定向目标地址
    input wire[`Hold_Flag_Bus] hold_flag_i, // ctrl.v 统一输出的流水线暂停级别
    input wire jtag_reset_flag_i,           // JTAG 调试复位，让 PC 回到启动地址，方便 JTAG/UART debug 重新跑程序

    output reg[`InstAddrBus] pc_o           // 当前取指 PC，也就是“下一次要取指的地址”

    );

/*
这个 always 块就是 PC 更新规则：
always @ (posedge clk) begin
意思是：每个时钟上升沿更新一次 PC。
优先级是：
reset / jtag reset
    > jump
    > hold
    > pc + 4
也就是：
如果系统复位或 JTAG 复位：
pc_o <= `CpuResetAddr;
PC 回到启动地址。这里 CpuResetAddr 是宏，当前是 32'h0。

如果发生跳转/异常/中断：
pc_o <= jump_addr_i;
PC 改成目标地址。

如果流水线需要暂停：
pc_o <= pc_o;
PC 保持不变。

否则正常顺序执行：
pc_o <= pc_o + 4'h4;
因为每条指令 4 字节，所以 PC 加 4。

宏定义就是 Verilog 预处理常量，比如：

`define RstEnable 1'b0
`define JumpEnable 1'b1
`define CpuResetAddr 32'h0
`define InstAddrBus 31:0
写宏的好处是代码更可读。比如：
rst == `RstEnable
比直接写：
rst == 1'b0
更容易看懂：这是在判断复位有效。注意你这个项目里 reset 是低有效，所以 RstEnable = 1'b0。
*/
    always @ (posedge clk) begin
        // 复位优先级最高：系统复位或调试复位都回到启动地址。
        if (rst == `RstEnable || jtag_reset_flag_i == 1'b1) begin
            pc_o <= `CpuResetAddr;
        // 跳转/异常/中断重定向次之，会清掉顺序取指路径。
        end else if (jump_flag_i == `JumpEnable) begin
            pc_o <= jump_addr_i;
        // 前端或后端需要等待时，PC 必须冻结，避免重复/跳过取指。
        // Hold_Load inserts a load-use bubble.  The fetch request for the
        // current PC may still be outstanding, so PC must not advance past
        // it; otherwise the ifetch queue can skip the intervening address.
        end else if (hold_flag_i == `Hold_Pc || hold_flag_i == `Hold_If || hold_flag_i == `Hold_Id ||
                     hold_flag_i == `Hold_Load || hold_flag_i == `Hold_Ex) begin
            pc_o <= pc_o;
        // 无 stall、无跳转时顺序取下一条 32-bit 指令。
        end else begin
            pc_o <= pc_o + 4'h4;
        end
    end

endmodule
