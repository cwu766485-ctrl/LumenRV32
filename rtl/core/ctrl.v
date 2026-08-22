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

// Pipeline control. Prioritize redirects / interrupts, then MEM stalls,
// then load-use hazards, then fetch-side stalls.
// -----------------------------------------------------------------------------
// 流水线控制/仲裁模块/全局流水线控制器/它的核心作用是：把各个模块发来的暂停/跳转请求，统一仲裁成一个 hold_flag_o
/*
CPU 里很多地方都会说“我现在需要暂停一下”：
EX 阶段说：我要跳转 / 除法还没算完
MEM 阶段说：我在等 RAM/DDR/外设返回
IF 阶段说：我在等取指返回
ID 阶段检测到：load-use hazard，需要插气泡
CLINT 说：我正在处理中断/异常 CSR
JTAG 说：我要 halt CPU
这些信号不能各管各的，否则流水线会乱。所以 ctrl.v 统一决定：
hold_flag_o = `Hold_Id / `Hold_Ex / `Hold_Load / `Hold_If / `Hold_None

*/
// -----------------------------------------------------------------------------
// 作用：
// - 把 EX 跳转、MEM 等待、load-use hazard、取指等待、JTAG halt、CLINT 中断处理
//   合成为一个 hold_flag_o。
// - PC、IF/ID、ID/EX、EX/MEM、MEM/WB 都只看 hold_flag_o，不各自做全局仲裁。
// - jump_flag_o/jump_addr_o 直接转发 EX/CLINT 的重定向信息给 pc_reg 和 ifetch flush。
// 优先级：
// 1. 跳转/除法启动/中断 CSR 处理：flush 到 ID，防止错误路径继续流动。
// 2. MEM stall：冻结 EX/MEM 及其之前，保持总线请求稳定。
// 3. load-use：插入一拍气泡，让 load 数据到达后再给后一条指令使用。
// 4. IF stall：只冻结前端，等待 I-cache/memory interface 取指返回。
// 5. JTAG halt：调试暂停时冻结后端状态。
// -----------------------------------------------------------------------------
module ctrl(

    input wire rst,

    // from ex 表示现在发生了控制流重定向
    input wire jump_flag_i, //jump_flag_i 表示“要不要跳”
    input wire[`InstAddrBus] jump_addr_i, //表示“跳到哪里
    input wire hold_flag_ex_i, //来自 EX。主要用于 EX 阶段多周期操作，比如除法启动/执行期间，需要暂停流水线

    // from mem / fetch / hazard
    // 比如 load/store 访问 RAM、DDR、外设，还没 ready，这时必须冻结后端，保持访存请求稳定
    input wire hold_flag_mem_i,
    input wire hold_flag_load_i,
    input wire hold_flag_if_i,

    // from jtag
    input wire jtag_halt_flag_i,

    // from clint
    input wire hold_flag_clint_i,

    output reg[`Hold_Flag_Bus] hold_flag_o,

    // to pc_reg
    output reg jump_flag_o,
    output reg[`InstAddrBus] jump_addr_o

    );

    always @ (*) begin
        jump_addr_o = jump_addr_i;
        jump_flag_o = jump_flag_i;
        hold_flag_o = `Hold_None;

        // 按优先级编码统一 stall/flush 策略。后续流水级只消费最终编码，
        // 避免多个模块同时驱动暂停信号造成控制不一致。
        if (hold_flag_mem_i == `HoldEnable) begin
            jump_flag_o = `JumpDisable;
            hold_flag_o = `Hold_Ex;
        end else if (jump_flag_i == `JumpEnable || hold_flag_ex_i == `HoldEnable || hold_flag_clint_i == `HoldEnable) begin
            hold_flag_o = `Hold_Id;
        end else if (hold_flag_load_i == `HoldEnable) begin
            hold_flag_o = `Hold_Load;
        end else if (hold_flag_if_i == `HoldEnable) begin
            hold_flag_o = `Hold_If;
        end else if (jtag_halt_flag_i == `HoldEnable) begin
            hold_flag_o = `Hold_Ex;
        end else begin
            hold_flag_o = `Hold_None;
        end
    end

endmodule
