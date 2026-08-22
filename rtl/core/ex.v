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

`timescale 1 ns / 1 ps

`include "defines.v"

// Execute stage. Memory requests are described here and completed in MEM.
// -----------------------------------------------------------------------------
// EX 执行阶段
// -----------------------------------------------------------------------------
// 作用：
// - 执行 RV32I ALU、分支比较、JAL/JALR 目标地址计算。
// - 执行 RV32M 乘法；除法/取余交给 div.v 多周期单元，并通过 hold_flag_o 冻结流水线。
// - 为 load/store 生成地址、写数据、字节写掩码，MEM 阶段只负责等待 ready 和 load 扩展。
// - 计算 CSR 新值，CSR 写入最终仍在 WB 后提交到 csr_reg.v。
// - 当 CLINT 断言中断/异常跳转时，屏蔽本拍普通写回/访存，优先进入 trap。
// 面试重点：
// - EX 是“真正做计算”的地方，也是控制流重定向的主要产生点。
// - store byte/halfword 的 wmask 和 data 对齐在这里完成。
// -----------------------------------------------------------------------------
module ex(

    input wire rst,

    // from id/ex
    input wire[`InstBus] inst_i,
    input wire[`InstAddrBus] inst_addr_i,
    input wire reg_we_i,
    input wire[`RegAddrBus] reg_waddr_i,
    input wire[`RegBus] reg1_rdata_i,
    input wire[`RegBus] reg2_rdata_i,
    input wire csr_we_i,
    input wire[`MemAddrBus] csr_waddr_i,
    input wire[`RegBus] csr_rdata_i,
    input wire int_assert_i,
    input wire[`InstAddrBus] int_addr_i,
    input wire[`MemAddrBus] op1_i,
    input wire[`MemAddrBus] op2_i,
    input wire[`MemAddrBus] op1_jump_i,
    input wire[`MemAddrBus] op2_jump_i,
    input wire predict_taken_i,
    input wire[`InstAddrBus] predict_target_i,

    // from div
    input wire div_ready_i,
    input wire[`RegBus] div_result_i,
    input wire div_busy_i,
    input wire[`RegAddrBus] div_reg_waddr_i,

    // to mem
    output reg[`MemAddrBus] mem_addr_o,
    output reg[`MemBus] mem_wdata_o,
    output reg[`MemMaskBus] mem_wmask_o,
    output wire mem_we_o,
    output wire mem_req_o,
    output reg mem_load_o,
    output reg[2:0] mem_funct3_o,
    output reg[1:0] mem_addr_lsb_o,

    // to regs
    output wire[`RegBus] reg_wdata_o,
    output wire reg_we_o,
    output wire[`RegAddrBus] reg_waddr_o,

    // to csr reg
    output reg[`RegBus] csr_wdata_o,
    output wire csr_we_o,
    output wire[`MemAddrBus] csr_waddr_o,

    // to div
    output wire div_start_o,
    output reg[`RegBus] div_dividend_o,
    output reg[`RegBus] div_divisor_o,
    output reg[2:0] div_op_o,
    output reg[`RegAddrBus] div_reg_waddr_o,

    // to ctrl
    output wire hold_flag_o,
    output wire jump_flag_o,
    output wire[`InstAddrBus] jump_addr_o,
    output wire icache_invalidate_o,
    output wire branch_predict_hit_o,
    output wire branch_predict_miss_o,
    output wire branch_resolve_valid_o,
    output wire[`InstAddrBus] branch_resolve_pc_o,
    output wire branch_resolve_taken_o,
    output wire[`InstAddrBus] branch_resolve_target_o

    );

    // 根据 store 类型和地址低两位生成字节写掩码。
    // SB 只写一个 byte；SH 写半字；SW 写整个 word。
    function [`MemMaskBus] build_store_mask;
        input [2:0] store_funct3;
        input [1:0] addr_lsb;
        begin
            case (store_funct3)
                `INST_SB: build_store_mask = (4'b0001 << addr_lsb);
                `INST_SH: build_store_mask = addr_lsb[1] ? 4'b1100 : 4'b0011;
                default: build_store_mask = 4'b1111;
            endcase
        end
    endfunction

    // 把待写的 byte/halfword 放到 32-bit 总线对应 lane 上，配合 wmask 使用。
    function [`MemBus] build_store_data;
        input [2:0] store_funct3;
        input [1:0] addr_lsb;
        input [`RegBus] src_data;
        begin
            case (store_funct3)
                `INST_SB: build_store_data = {4{src_data[7:0]}} << (addr_lsb * 8);
                `INST_SH: build_store_data = addr_lsb[1] ? {src_data[15:0], 16'h0} : {16'h0, src_data[15:0]};
                default: build_store_data = src_data;
            endcase
        end
    endfunction

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[4:0] rd = inst_i[11:7];
    wire[4:0] uimm = inst_i[19:15];

    wire[31:0] sr_shift = reg1_rdata_i >> reg2_rdata_i[4:0];
    wire[31:0] sri_shift = reg1_rdata_i >> inst_i[24:20];
    wire[31:0] sr_shift_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    wire[31:0] sri_shift_mask = 32'hffffffff >> inst_i[24:20];

    wire[31:0] op1_add_op2_res = op1_i + op2_i;
    wire[31:0] op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

    // 乘法符号处理：MULH/MULHSU 先取绝对值相乘，最后按符号决定高 32 位取反加一。
    wire[31:0] reg1_data_invert = ~reg1_rdata_i + 1'b1;
    wire[31:0] reg2_data_invert = ~reg2_rdata_i + 1'b1;

    wire op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    wire op1_ge_op2_unsigned = op1_i >= op2_i;
    wire op1_eq_op2 = (op1_i == op2_i);

    reg[`RegBus] mul_op1;
    reg[`RegBus] mul_op2;
    wire[`DoubleRegBus] mul_temp = mul_op1 * mul_op2;
    wire[`DoubleRegBus] mul_temp_invert = ~mul_temp + 1'b1;

    reg[`RegBus] reg_wdata;
    reg reg_we;
    reg[`RegAddrBus] reg_waddr;
    reg[`RegBus] div_wdata;
    reg div_we;
    reg[`RegAddrBus] div_waddr;
    reg div_hold_flag;
    reg div_jump_flag;
    reg[`InstAddrBus] div_jump_addr;
    reg jump_flag;
    reg[`InstAddrBus] jump_addr;
    reg icache_invalidate;
    reg branch_predict_hit;
    reg branch_predict_miss;
    reg branch_taken;
    reg[`InstAddrBus] branch_target;
    reg mem_we;
    reg mem_req;
    reg div_start;

    // trap 进入时不允许再启动普通执行单元，防止错误路径产生副作用。
    assign div_start_o = (int_assert_i == `INT_ASSERT) ? `DivStop : div_start;

    assign reg_wdata_o = reg_wdata | div_wdata;
    assign reg_we_o = (int_assert_i == `INT_ASSERT) ? `WriteDisable : (reg_we || div_we);
    assign reg_waddr_o = reg_waddr | div_waddr;

    assign mem_we_o = (int_assert_i == `INT_ASSERT) ? `WriteDisable : mem_we;
    assign mem_req_o = (int_assert_i == `INT_ASSERT) ? `MEM_NREQ : mem_req;

    assign hold_flag_o = div_hold_flag;
    assign jump_flag_o = jump_flag || div_jump_flag || ((int_assert_i == `INT_ASSERT) ? `JumpEnable : `JumpDisable);
    assign jump_addr_o = (int_assert_i == `INT_ASSERT) ? int_addr_i : (jump_addr | div_jump_addr);
    assign icache_invalidate_o = icache_invalidate;
    assign branch_predict_hit_o = branch_predict_hit;
    assign branch_predict_miss_o = branch_predict_miss;
    assign branch_resolve_valid_o = (inst_i[6:0] == `INST_TYPE_B);
    assign branch_resolve_pc_o = inst_addr_i;
    assign branch_resolve_taken_o = branch_taken;
    assign branch_resolve_target_o = branch_target;

    assign csr_we_o = (int_assert_i == `INT_ASSERT) ? `WriteDisable : csr_we_i;
    assign csr_waddr_o = csr_waddr_i;

    // 乘法操作数预处理：普通 MUL/MULHU 直接用原值；有符号乘法转成绝对值。
    always @ (*) begin
        if ((opcode == `INST_TYPE_R_M) && (funct7 == 7'b0000001)) begin
            case (funct3)
                `INST_MUL, `INST_MULHU: begin
                    mul_op1 = reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
                `INST_MULHSU: begin
                    mul_op1 = (reg1_rdata_i[31] == 1'b1) ? reg1_data_invert : reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
                `INST_MULH: begin
                    mul_op1 = (reg1_rdata_i[31] == 1'b1) ? reg1_data_invert : reg1_rdata_i;
                    mul_op2 = (reg2_rdata_i[31] == 1'b1) ? reg2_data_invert : reg2_rdata_i;
                end
                default: begin
                    mul_op1 = reg1_rdata_i;
                    mul_op2 = reg2_rdata_i;
                end
            endcase
        end else begin
            mul_op1 = reg1_rdata_i;
            mul_op2 = reg2_rdata_i;
        end
    end

    // 除法控制：
    // - EX 检测到 DIV/REM 时启动 div.v，并产生一次跳转到下一条指令地址。
    // - div_busy_i 期间保持 hold，直到 div_ready_i 返回结果。
    // - 返回结果通过 div_we/div_wdata 合并到普通 reg 写回通路。
    always @ (*) begin
        div_dividend_o = reg1_rdata_i;
        div_divisor_o = reg2_rdata_i;
        div_op_o = funct3;
        div_reg_waddr_o = reg_waddr_i;
        if ((opcode == `INST_TYPE_R_M) && (funct7 == 7'b0000001)) begin
            div_we = `WriteDisable;
            div_wdata = `ZeroWord;
            div_waddr = `ZeroWord;
            case (funct3)
                `INST_DIV, `INST_DIVU, `INST_REM, `INST_REMU: begin
                    div_start = `DivStart;
                    div_jump_flag = `JumpEnable;
                    div_hold_flag = `HoldEnable;
                    div_jump_addr = op1_jump_add_op2_jump_res;
                end
                default: begin
                    div_start = `DivStop;
                    div_jump_flag = `JumpDisable;
                    div_hold_flag = `HoldDisable;
                    div_jump_addr = `ZeroWord;
                end
            endcase
        end else begin
            div_jump_flag = `JumpDisable;
            div_jump_addr = `ZeroWord;
            if (div_busy_i == `True) begin
                div_start = `DivStart;
                div_we = `WriteDisable;
                div_wdata = `ZeroWord;
                div_waddr = `ZeroWord;
                div_hold_flag = `HoldEnable;
            end else begin
                div_start = `DivStop;
                div_hold_flag = `HoldDisable;
                if (div_ready_i == `DivResultReady) begin
                    div_wdata = div_result_i;
                    div_waddr = div_reg_waddr_i;
                    div_we = `WriteEnable;
                end else begin
                    div_we = `WriteDisable;
                    div_wdata = `ZeroWord;
                    div_waddr = `ZeroWord;
                end
            end
        end
    end

    // 主执行组合逻辑：
    // - 默认不访存、不跳转、写回 0。
    // - 根据 opcode/funct3/funct7 覆盖对应控制信号。
    // - 组合 always 块必须覆盖所有输出，避免 latch。
    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        reg_wdata = `ZeroWord;
        jump_flag = `JumpDisable;
        jump_addr = `ZeroWord;
        icache_invalidate = `False;
        branch_predict_hit = `False;
        branch_predict_miss = `False;
        branch_taken = `False;
        branch_target = `ZeroWord;
        mem_addr_o = `ZeroWord;
        mem_wdata_o = `ZeroWord;
        mem_wmask_o = 4'b1111;
        mem_we = `WriteDisable;
        mem_req = `MEM_NREQ;
        mem_load_o = `False;
        mem_funct3_o = 3'b0;
        mem_addr_lsb_o = 2'b0;
        csr_wdata_o = `ZeroWord;

        case (opcode)
            // I-type ALU immediate。
            `INST_TYPE_I: begin
                case (funct3)
                    `INST_ADDI: reg_wdata = op1_add_op2_res;
                    `INST_SLTI: reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                    `INST_SLTIU: reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                    `INST_XORI: reg_wdata = op1_i ^ op2_i;
                    `INST_ORI: reg_wdata = op1_i | op2_i;
                    `INST_ANDI: reg_wdata = op1_i & op2_i;
                    `INST_SLLI: reg_wdata = reg1_rdata_i << inst_i[24:20];
                    `INST_SRI: begin
                        if (inst_i[30] == 1'b1) begin
                            reg_wdata = (sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask));
                        end else begin
                            reg_wdata = reg1_rdata_i >> inst_i[24:20];
                        end
                    end
                    default: begin
                        reg_wdata = `ZeroWord;
                    end
                endcase
            end
            // R/M-type：普通 ALU 和乘法在本 always 块直接给出 reg_wdata。
            `INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `INST_ADD_SUB: begin
                            if (inst_i[30] == 1'b0) begin
                                reg_wdata = op1_add_op2_res;
                            end else begin
                                reg_wdata = op1_i - op2_i;
                            end
                        end
                        `INST_SLL: reg_wdata = op1_i << op2_i[4:0];
                        `INST_SLT: reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                        `INST_SLTU: reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                        `INST_XOR: reg_wdata = op1_i ^ op2_i;
                        `INST_SR: begin
                            if (inst_i[30] == 1'b1) begin
                                reg_wdata = (sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask));
                            end else begin
                                reg_wdata = reg1_rdata_i >> reg2_rdata_i[4:0];
                            end
                        end
                        `INST_OR: reg_wdata = op1_i | op2_i;
                        `INST_AND: reg_wdata = op1_i & op2_i;
                        default: reg_wdata = `ZeroWord;
                    endcase
                end else if (funct7 == 7'b0000001) begin
                    case (funct3)
                        `INST_MUL: reg_wdata = mul_temp[31:0];
                        `INST_MULHU: reg_wdata = mul_temp[63:32];
                        `INST_MULH: begin
                            case ({reg1_rdata_i[31], reg2_rdata_i[31]})
                                2'b00: reg_wdata = mul_temp[63:32];
                                2'b11: reg_wdata = mul_temp[63:32];
                                2'b10: reg_wdata = mul_temp_invert[63:32];
                                default: reg_wdata = mul_temp_invert[63:32];
                            endcase
                        end
                        `INST_MULHSU: begin
                            if (reg1_rdata_i[31] == 1'b1) begin
                                reg_wdata = mul_temp_invert[63:32];
                            end else begin
                                reg_wdata = mul_temp[63:32];
                            end
                        end
                        default: reg_wdata = `ZeroWord;
                    endcase
                end else begin
                    reg_wdata = `ZeroWord;
                end
            end
            // Load：只发读请求和记录 load 类型，load 数据在 mem.v 中对齐/扩展。
            `INST_TYPE_L: begin
                mem_req = `MEM_REQ;
                mem_we = `WriteDisable;
                mem_addr_o = op1_add_op2_res;
                mem_load_o = `True;
                mem_funct3_o = funct3;
                mem_addr_lsb_o = op1_add_op2_res[1:0];
                reg_wdata = `ZeroWord;
            end
            // Store：发写请求，同时生成 aligned wdata 和 byte mask。
            `INST_TYPE_S: begin
                mem_req = `MEM_REQ;
                mem_we = `WriteEnable;
                mem_addr_o = op1_add_op2_res;
                mem_wdata_o = build_store_data(funct3, op1_add_op2_res[1:0], reg2_rdata_i);
                mem_wmask_o = build_store_mask(funct3, op1_add_op2_res[1:0]);
                reg_wdata = `ZeroWord;
            end
            // Branch：比较 op1/op2，满足条件时输出 jump_flag/jump_addr。
            `INST_TYPE_B: begin
                reg_wdata = `ZeroWord;
                branch_target = op1_jump_add_op2_jump_res;
                case (funct3)
                    `INST_BEQ: begin
                        branch_taken = op1_eq_op2;
                    end
                    `INST_BNE: begin
                        branch_taken = ~op1_eq_op2;
                    end
                    `INST_BLT: begin
                        branch_taken = ~op1_ge_op2_signed;
                    end
                    `INST_BGE: begin
                        branch_taken = op1_ge_op2_signed;
                    end
                    `INST_BLTU: begin
                        branch_taken = ~op1_ge_op2_unsigned;
                    end
                    `INST_BGEU: begin
                        branch_taken = op1_ge_op2_unsigned;
                    end
                    default: begin
                        branch_taken = `False;
                    end
                endcase
                if (predict_taken_i == `True) begin
                    if (branch_taken == `True) begin
                        jump_flag = (predict_target_i != branch_target) ? `JumpEnable : `JumpDisable;
                        jump_addr = (predict_target_i != branch_target) ? branch_target : `ZeroWord;
                    end else begin
                        jump_flag = `JumpEnable;
                        jump_addr = inst_addr_i + 4'h4;
                    end
                end else begin
                    jump_flag = branch_taken ? `JumpEnable : `JumpDisable;
                    jump_addr = branch_taken ? branch_target : `ZeroWord;
                end
                if ((predict_taken_i == `True && branch_taken == `True &&
                     predict_target_i == branch_target) ||
                    (predict_taken_i == `False && branch_taken == `False)) begin
                    branch_predict_hit = `True;
                end else begin
                    branch_predict_miss = `True;
                end
            end
            // JAL/JALR：写回 PC+4，同时重定向 PC。
            `INST_JAL, `INST_JALR: begin
                jump_flag = `JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
                reg_wdata = op1_add_op2_res;
            end
            `INST_LUI, `INST_AUIPC: begin
                reg_wdata = op1_add_op2_res;
            end
            `INST_NOP_OP: begin
                reg_wdata = `ZeroWord;
            end
            `INST_FENCE: begin
                reg_wdata = `ZeroWord;
                // FENCE is naturally ordered by this in-order pipeline.
                // FENCE.I additionally invalidates I-cache and resumes at PC+4.
                if (funct3 == `INST_FENCE_I_FUNCT3) begin
                    icache_invalidate = `True;
                    jump_flag = `JumpEnable;
                    jump_addr = inst_addr_i + 4'h4;
                end
            end
            // CSR：把旧 CSR 值写回 rd，并生成新 CSR 写值。
            `INST_CSR: begin
                case (funct3)
                    `INST_CSRRW: begin
                        csr_wdata_o = reg1_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRS: begin
                        csr_wdata_o = reg1_rdata_i | csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRC: begin
                        csr_wdata_o = csr_rdata_i & (~reg1_rdata_i);
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRWI: begin
                        csr_wdata_o = {27'h0, uimm};
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRSI: begin
                        csr_wdata_o = {27'h0, uimm} | csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `INST_CSRRCI: begin
                        csr_wdata_o = (~{27'h0, uimm}) & csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    default: begin
                        csr_wdata_o = `ZeroWord;
                        reg_wdata = `ZeroWord;
                    end
                endcase
            end
            default: begin
                reg_wdata = `ZeroWord;
            end
        endcase
    end

endmodule
