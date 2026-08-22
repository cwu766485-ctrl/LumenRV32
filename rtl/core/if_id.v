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
// IF/ID 流水线寄存器 + 两项 skid buffer
// -----------------------------------------------------------------------------
// 作用：
// - 接收 ifetch 已经确认有效的指令，向 ID 阶段提供当前待译码指令。
// - 当后端 stall 但前端已经多取了年轻指令时，用 slot0/slot1 临时保存。
// - slot0 永远是最老、下一条要交给 ID 的指令；slot1 是后一条。
// - Hold_Id(3'b011) 表示发生跳转/异常/中断 flush，必须清空 buffer 防止错误路径执行。
//
// 可以把这个模块当成一个最多存 2 条指令的小队列：
// - push：ifetch 返回了一条新指令 inst_i/inst_addr_i，并且 inst_valid_i=1。
// - pop：ID 阶段可以消费当前最老的一条指令。
// - slot_count=2'b00：队列空。
// - slot_count=2'b01：只有 slot0 有效。
// - slot_count=2'b10：slot0 和 slot1 都有效，队列满。
//
// 相关宏的实际数值：
// - RstEnable  = 1'b0，系统复位低有效。
// - True       = 1'b1，False = 1'b0。
// - INST_NOP   = 32'h00000001，表示流水线里使用的 NOP 指令编码。
// - INT_NONE   = 8'h00，表示当前指令没有携带中断标志。
// - InstBus    = 31:0，指令宽度 32 bit。
// - InstAddrBus= 31:0，指令地址宽度 32 bit。
// - INT_BUS    = 7:0，中断标志宽度 8 bit。
// - Hold_None  = 3'b000，流水线正常流动。
// - Hold_If    = 3'b010，取指侧等待，ID 仍可消耗 buffer 中已有指令。
// - Hold_Id    = 3'b011，控制流 flush，清空 IF/ID buffer。
// - Hold_Load  = 3'b100，load-use hazard，前端冻结，允许新取回指令暂存。
// - Hold_Ex    = 3'b101，后端/MEM/调试冻结，前端冻结，允许新取回指令暂存。
//
// 面试重点：
// - 这个模块不译码、不执行，只解决“取指返回”和“译码消费”速率不一致的问题。
// - 它保证程序顺序：slot0 永远先于 slot1 被输出。
// -----------------------------------------------------------------------------
module if_id(

    input wire clk,
    input wire rst,

    input wire[`InstBus] inst_i,            // ifetch 返回的 32-bit 指令，InstBus=31:0
    input wire[`InstAddrBus] inst_addr_i,   // inst_i 对应的 PC，InstAddrBus=31:0
    input wire inst_valid_i,                // ifetch 返回有效，True=1'b1 时表示 inst_i/inst_addr_i 可入队

    input wire[`Hold_Flag_Bus] hold_flag_i, // ctrl.v 输出的暂停/flush 编码，Hold_Flag_Bus=2:0
/*
Hold_None = 3'b000  正常流动
Hold_If   = 3'b010  取指等待，但已有指令还能继续给 ID
Hold_Id   = 3'b011  flush，清空 IF/ID
Hold_Load = 3'b100  load-use hazard，前端冻结
Hold_Ex   = 3'b101  后端冻结
*/
    input wire[`INT_BUS] int_flag_i,        // 当前取指同时携带的外部中断标志，INT_BUS=7:0
    output wire[`INT_BUS] int_flag_o,       // 跟随输出指令送到后续 CLINT 的中断标志
    output wire replay_hold_o,              // buffer 满时拉高，让 ifetch 暂停继续交付响应

    output wire[`InstBus] inst_o,           // 输出给 ID 阶段的当前待译码指令
    output wire[`InstAddrBus] inst_addr_o   // inst_o 对应的 PC

    );

    // 两个队列槽位：
    // - slot0 保存最老指令，输出端永远优先看 slot0。
    // - slot1 保存后一条指令，只有 slot0 被 pop 后才会前移到 slot0。
    reg[`InstBus] slot0_inst;
    reg[`InstAddrBus] slot0_addr;
    reg[`INT_BUS] slot0_int;
    reg[`InstBus] slot1_inst;
    reg[`InstAddrBus] slot1_addr;
    reg[`INT_BUS] slot1_int;
    reg[1:0] slot_count;
    // 2'b00  空
    // 2'b01  slot0 有效
    // 2'b10  slot0 和 slot1 都有效

    // hold_frontend：
    // - Hold_Ex(3'b101)：后端/MEM/调试冻结，ID 不能继续消费指令。
    // - Hold_Load(3'b100)：load-use hazard，需要插入气泡，ID 也不能正常消费当前指令。
    // 这两种情况下，如果 ifetch 已经返回了新指令，本模块只允许 push 暂存，不允许 pop 给 ID。
    wire hold_frontend = (hold_flag_i == `Hold_Ex) || (hold_flag_i == `Hold_Load);

    // pop_entry：
    // - Hold_None(3'b000)：流水线正常，ID 可以消费 slot0。
    // - Hold_If(3'b010)：取指侧等待，但 buffer 里已有指令仍可以继续送给 ID。
    // - slot_count != 0：队列里确实有指令可 pop。
    wire pop_entry = ((hold_flag_i == `Hold_None) || (hold_flag_i == `Hold_If)) && (slot_count != 2'b00);

    // entry_in_slot0/slot1：
    // 防止同一个 inst_addr_i 被重复 push。取指等待/重放时，ifetch 可能再次给同一 PC 的响应。
    wire entry_in_slot0 = (slot_count != 2'b00) && (slot0_addr == inst_addr_i);
    wire entry_in_slot1 = (slot_count == 2'b10) && (slot1_addr == inst_addr_i);

    // push_entry：
    // - inst_valid_i=True(1'b1)：ifetch 确实给了一条有效指令。
    // - 该 PC 不在 slot0/slot1 中：避免重复入队。
    // - slot_count != 2：队列未满。
    wire push_entry = (inst_valid_i == `True) && !entry_in_slot0 && !entry_in_slot1 && (slot_count != 2'b10);

    // 时序逻辑：
    // - 所有 slot 内容和 slot_count 都是寄存器，只在 clk 上升沿更新。
    // - reset/flush 清空队列。
    // - hold_frontend 时只允许入队，不允许出队。
    // - 正常流动时按 {pop_entry, push_entry} 同时处理出队/入队。
    always @ (posedge clk) begin
        if (rst == `RstEnable || hold_flag_i == `Hold_Id) begin
            // reset 或 flush：
            // - rst == RstEnable(1'b0)：系统复位。
            // - hold_flag_i == Hold_Id(3'b011)：跳转/异常/中断导致 IF/ID 中的旧路径指令无效。
            // 清空所有暂存指令，让跳转/异常后的新 PC 重新取指。
            slot0_inst <= `INST_NOP;
            slot0_addr <= `ZeroWord;
            slot0_int <= `INT_NONE;
            slot1_inst <= `INST_NOP;
            slot1_addr <= `ZeroWord;
            slot1_int <= `INT_NONE;
            slot_count <= 2'b00;
        end else if (hold_frontend == `True) begin
            // 后端冻结但取指响应可能已经到达：
            // - 不允许 pop，因为 ID/EX 后面的流水线现在不能正常推进。
            // - 允许 push，把已经到达的取指结果暂存在 slot0/slot1，避免丢指令。
            case (slot_count)
                2'b00: begin
                    // 队列空，新指令放入 slot0。
                    if (push_entry == `True) begin
                        slot0_inst <= inst_i;
                        slot0_addr <= inst_addr_i;
                        slot0_int <= int_flag_i;
                        slot_count <= 2'b01;
                    end
                end
                2'b01: begin
                    // 队列已有 slot0，新指令放入 slot1。
                    if (push_entry == `True) begin
                        slot1_inst <= inst_i;
                        slot1_addr <= inst_addr_i;
                        slot1_int <= int_flag_i;
                        slot_count <= 2'b10;
                    end
                end
                default: begin
                    // 队列已满或非法状态，这里保持不变。
                    slot_count <= slot_count;
                end
            endcase
        end else begin
            // 正常流动：可以同时 pop 最老指令、push 新指令，保持程序顺序。
            // {pop_entry, push_entry} 的含义：
            // - 2'b00：不出队、不入队。
            // - 2'b01：只入队。
            // - 2'b10：只出队。
            // - 2'b11：出队同时入队。
            case ({pop_entry, push_entry})
                2'b00: begin
                    // 无新指令、ID 也没有消费，保持队列状态。
                    slot_count <= slot_count;
                end
                2'b01: begin
                    // 只 push：根据当前 slot_count 决定放 slot0 还是 slot1。
                    case (slot_count)
                        2'b00: begin
                            // 空队列入队，新指令成为最老指令。
                            slot0_inst <= inst_i;
                            slot0_addr <= inst_addr_i;
                            slot0_int <= int_flag_i;
                            slot_count <= 2'b01;
                        end
                        2'b01: begin
                            // slot0 已有指令，新指令排到 slot1。
                            slot1_inst <= inst_i;
                            slot1_addr <= inst_addr_i;
                            slot1_int <= int_flag_i;
                            slot_count <= 2'b10;
                        end
                        default: begin
                            slot_count <= slot_count;
                        end
                    endcase
                end
                2'b10: begin
                    // 只 pop：ID 消费最老指令，但本拍没有新指令补进来。
                    case (slot_count)
                        2'b01: begin
                            // 只有 slot0，一旦 pop 后队列变空。
                            slot0_inst <= `INST_NOP;
                            slot0_addr <= `ZeroWord;
                            slot0_int <= `INT_NONE;
                            slot_count <= 2'b00;
                        end
                        2'b10: begin
                            // slot0 被消费，slot1 前移成为新的最老指令。
                            slot0_inst <= slot1_inst;
                            slot0_addr <= slot1_addr;
                            slot0_int <= slot1_int;
                            slot1_inst <= `INST_NOP;
                            slot1_addr <= `ZeroWord;
                            slot1_int <= `INT_NONE;
                            slot_count <= 2'b01;
                        end
                        default: begin
                            slot_count <= slot_count;
                        end
                    endcase
                end
                default: begin
                    // pop 和 push 同时发生：
                    // - ID 消费 slot0。
                    // - ifetch 又给了新指令。
                    // - 队列长度通常保持不变，但要维护 slot0/slot1 顺序。
                    case (slot_count)
                        2'b01: begin
                            // 原来只有 slot0：slot0 被 pop，同时新指令进 slot0。
                            slot0_inst <= inst_i;
                            slot0_addr <= inst_addr_i;
                            slot0_int <= int_flag_i;
                            slot_count <= 2'b01;
                        end
                        2'b10: begin
                            // 原来队列满：slot0 被 pop，slot1 前移，新指令进 slot1。
                            slot0_inst <= slot1_inst;
                            slot0_addr <= slot1_addr;
                            slot0_int <= slot1_int;
                            slot1_inst <= inst_i;
                            slot1_addr <= inst_addr_i;
                            slot1_int <= int_flag_i;
                            slot_count <= 2'b10;
                        end
                        default: begin
                            // 理论上 slot_count=0 时 pop_entry 不会为 1，这里兜底处理为只入队。
                            slot0_inst <= inst_i;
                            slot0_addr <= inst_addr_i;
                            slot0_int <= int_flag_i;
                            slot_count <= 2'b01;
                        end
                    endcase
                end
            endcase
        end
    end

    // 组合输出：
    // - 队列非空时，输出 slot0，也就是最老的待译码指令。
    // - 队列为空时，输出 NOP/0/INT_NONE，避免 ID 阶段看到随机值。
    assign inst_o = (slot_count != 2'b00) ? slot0_inst : `INST_NOP;
    assign inst_addr_o = (slot_count != 2'b00) ? slot0_addr : `ZeroWord;
    assign int_flag_o = (slot_count != 2'b00) ? slot0_int : `INT_NONE;

    // replay_hold_o：
    // - slot_count == 2'b10 表示两个槽位都满。
    // - 此时通知 ifetch 暂停继续交付响应，避免第三条指令覆盖 slot1。
    assign replay_hold_o = (slot_count == 2'b10);

endmodule
