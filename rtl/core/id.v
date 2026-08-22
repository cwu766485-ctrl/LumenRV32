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
// ID 译码阶段
// -----------------------------------------------------------------------------
// 作用：
// - 解析 RV32I/RV32M/CSR 指令的 opcode/funct3/funct7/rd/rs1/rs2。
// - 生成寄存器堆读地址、CSR 读写地址、EX 阶段需要的操作数 op1/op2。
// - 对跳转/分支指令生成 op1_jump/op2_jump，EX 阶段只负责相加和条件判断。
// - 做 EX/MEM/WB 到 ID 的数据旁路，减少普通 ALU RAW hazard 的 stall。
// - load-use hazard 无法靠 EX 旁路解决，由 riscv_cpu_core.v 检测后通过 ctrl 插入气泡。
// 面试重点：
// - ID 是“控制信号生成器”，并不真正执行 ALU 或访存。
// - reset 或 EX 已经确认跳转时，ID 输出 NOP，清掉错误路径指令。
//
// 当前支持的主要指令集：
// - RV32I 基础整数指令：I/R/L/S/B/J/U/CSR/FENCE/ECALL/EBREAK/MRET 相关编码。
// - RV32M 乘除法扩展：MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU。
// - CSR 指令：CSRRW/CSRRS/CSRRC/CSRRWI/CSRRSI/CSRRCI。
//
// 相关宏的实际编码：
// - INST_TYPE_I   = 7'b0010011，ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI。
// - INST_TYPE_L   = 7'b0000011，LB/LH/LW/LBU/LHU。
// - INST_TYPE_S   = 7'b0100011，SB/SH/SW。
// - INST_TYPE_R_M = 7'b0110011，R-type ALU 和 RV32M 共用 opcode。
// - INST_TYPE_B   = 7'b1100011，BEQ/BNE/BLT/BGE/BLTU/BGEU。
// - INST_JAL      = 7'b1101111，INST_JALR = 7'b1100111。
// - INST_LUI      = 7'b0110111，INST_AUIPC = 7'b0010111。
// - INST_CSR      = 7'b1110011。
// - WriteEnable   = 1'b1，WriteDisable = 1'b0。
// - ZeroReg       = 5'h0，即 x0；ZeroWord = 32'h0。
// - INST_NOP      = 32'h00000001，本项目流水线 bubble/NOP 使用该编码。
//
// 本模块输出的几类关键控制：
// - reg1_raddr_o/reg2_raddr_o：告诉 regs.v 读哪个源寄存器。
// - op1_o/op2_o：给 EX 的普通 ALU/地址计算操作数。
// - op1_jump_o/op2_jump_o：给 EX 的跳转目标计算操作数。
// - reg_we_o/reg_waddr_o：最终是否写 rd，以及写哪个 rd。
// - csr_raddr_o/csr_waddr_o/csr_we_o：CSR 指令读写控制。
// -----------------------------------------------------------------------------
module id(

    input wire rst,                         // 系统复位，RstEnable=1'b0 时有效

    // from if_id
    input wire[`InstBus] inst_i,            // IF/ID 送来的 32-bit 指令，InstBus=31:0
    input wire[`InstAddrBus] inst_addr_i,   // 当前指令 PC，InstAddrBus=31:0

    // from regs 寄存器堆读出的 rs1/rs2 数据
    input wire[`RegBus] reg1_rdata_i,       // regs.v 按 reg1_raddr_o 读出的 rs1 数据
    input wire[`RegBus] reg2_rdata_i,       // regs.v 按 reg2_raddr_o 读出的 rs2 数据

    // from csr reg
    input wire[`RegBus] csr_rdata_i,        // csr_reg.v 按 csr_raddr_o 读出的旧 CSR 值

    // from ex/mem/wb forwarding path
    input wire ex_jump_flag_i,              // EX 已确认跳转/重定向，ID 当前指令需要 flush
    input wire branch_predict_taken_i,
    input wire[`InstAddrBus] branch_predict_target_i,
    input wire ex_reg_we_i,                 // EX 阶段是否将写 rd
    input wire[`RegAddrBus] ex_reg_waddr_i, // EX 阶段目的寄存器 rd
    input wire[`RegBus] ex_reg_wdata_i,     // EX 阶段已计算出的写回数据
    input wire ex_load_i,                   // EX 当前是否为 load；load 数据此时尚未返回，不能 EX->ID 旁路
    input wire mem_reg_we_i,                // MEM 阶段是否将写 rd
    input wire[`RegAddrBus] mem_reg_waddr_i,// MEM 阶段目的寄存器 rd
    input wire[`RegBus] mem_reg_wdata_i,    // MEM 阶段写回数据
    input wire wb_reg_we_i,                 // WB 阶段是否将写 rd
    input wire[`RegAddrBus] wb_reg_waddr_i, // WB 阶段目的寄存器 rd
    input wire[`RegBus] wb_reg_wdata_i,     // WB 阶段写回数据

    // to regs
    output reg[`RegAddrBus] reg1_raddr_o,   // 读 rs1 地址，RegAddrBus=4:0
    output reg[`RegAddrBus] reg2_raddr_o,   // 读 rs2 地址，RegAddrBus=4:0

    // to csr reg
    output reg[`MemAddrBus] csr_raddr_o,    // CSR 读地址，低 12 bit 有效

    // to ex
    output reg[`MemAddrBus] op1_o,          // EX 普通运算操作数 1，例如 rs1 或 PC
    output reg[`MemAddrBus] op2_o,          // EX 普通运算操作数 2，例如 rs2 或 sign-extended immediate
    output reg[`MemAddrBus] op1_jump_o,     // EX 跳转目标计算操作数 1，例如 PC 或 rs1
    output reg[`MemAddrBus] op2_jump_o,     // EX 跳转目标计算操作数 2，例如 branch/jal/jalr offset
    output reg predict_taken_o,             // 后向 branch 静态预测 taken
    output reg[`InstAddrBus] predict_target_o, // 预测 taken 时的目标 PC
    output reg[`InstBus] inst_o,            // 传给 EX 的原始指令
    output reg[`InstAddrBus] inst_addr_o,   // 传给 EX 的当前指令 PC
    output reg[`RegBus] reg1_rdata_o,       // 旁路后的 rs1 数据，供 EX 使用
    output reg[`RegBus] reg2_rdata_o,       // 旁路后的 rs2 数据，供 EX 使用
    output reg reg_we_o,                    // 当前指令是否写通用寄存器 rd
    output reg[`RegAddrBus] reg_waddr_o,    // 当前指令写回目的寄存器 rd
    output reg csr_we_o,                    // 当前指令是否写 CSR
    output reg[`RegBus] csr_rdata_o,        // 旧 CSR 值，CSR 指令需要把旧值写回 rd
    output reg[`MemAddrBus] csr_waddr_o     // CSR 写地址，低 12 bit 有效
// 这些是最关键的译码结果
    );

    // RISC-V 32-bit 指令公共字段拆分：
    // - opcode = inst[6:0]，决定大类：I/L/S/R/B/J/U/CSR。 funct3和7区别不同指令
    // - rd     = inst[11:7]，目的寄存器。
    // - funct3 = inst[14:12]，同一 opcode 下继续区分具体指令。
    // - rs1    = inst[19:15]，源寄存器 1。
    // - rs2    = inst[24:20]，源寄存器 2。
    // - funct7 = inst[31:25]，R-type/M-type 下继续区分 ADD/SUB、SRL/SRA、M 扩展等。
    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[4:0] rd = inst_i[11:7];
    wire[4:0] rs1 = inst_i[19:15];
    wire[4:0] rs2 = inst_i[24:20];
    wire[`InstAddrBus] branch_imm = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    wire branch_backward = inst_i[31];

    // RAW (Read After Write) 数据旁路优先级：
    // 1. EX 阶段普通 ALU 结果最快，但 load 指令的数据此时还没回来，不能从 EX 旁路。
    // 2. MEM 阶段结果次之。
    // 3. WB 阶段结果最后。
    // 若都未命中，使用 regs.v 读出的寄存器堆数据。
    //ex.
    //add x5, x1, x2
    //sub x6, x5, x3
    //第二条 sub 要读 x5，但第一条 add 的 x5 可能还没写回寄存器堆。
    //如果 sub 直接从 regs.v 读，就可能读到旧的 x5
    //通过上面这些 reg1_forward_hit 等信号，sub 可以直接从 EX 旁路得到 add 的结果，避免读到旧值。
    wire reg1_forward_hit = (rs1 != `ZeroReg) && (ex_reg_we_i == `WriteEnable) && (ex_load_i == `False) && (ex_reg_waddr_i == rs1);
    wire reg2_forward_hit = (rs2 != `ZeroReg) && (ex_reg_we_i == `WriteEnable) && (ex_load_i == `False) && (ex_reg_waddr_i == rs2);
    wire reg1_mem_forward_hit = (rs1 != `ZeroReg) && (mem_reg_we_i == `WriteEnable) && (mem_reg_waddr_i == rs1);
    wire reg2_mem_forward_hit = (rs2 != `ZeroReg) && (mem_reg_we_i == `WriteEnable) && (mem_reg_waddr_i == rs2);
    wire reg1_wb_forward_hit = (rs1 != `ZeroReg) && (wb_reg_we_i == `WriteEnable) && (wb_reg_waddr_i == rs1);
    wire reg2_wb_forward_hit = (rs2 != `ZeroReg) && (wb_reg_we_i == `WriteEnable) && (wb_reg_waddr_i == rs2);
    wire[`RegBus] reg1_data = reg1_forward_hit ? ex_reg_wdata_i :
                              (reg1_mem_forward_hit ? mem_reg_wdata_i :
                              (reg1_wb_forward_hit ? wb_reg_wdata_i : reg1_rdata_i));
    wire[`RegBus] reg2_data = reg2_forward_hit ? ex_reg_wdata_i :
                              (reg2_mem_forward_hit ? mem_reg_wdata_i :
                              (reg2_wb_forward_hit ? wb_reg_wdata_i : reg2_rdata_i));

    always @ (*) begin
        // 默认值很重要：
        // - always @(*) 是组合逻辑，不保存状态。
        // - 每个输出必须在所有路径赋值，否则综合工具可能推断 latch。
        // - 默认先透传指令/PC/旁路后的寄存器数据，具体指令再覆盖控制信号。
        inst_o = inst_i;
        inst_addr_o = inst_addr_i;
        reg1_rdata_o = reg1_data;
        reg2_rdata_o = reg2_data;
        csr_rdata_o = csr_rdata_i;
        csr_raddr_o = `ZeroWord;
        csr_waddr_o = `ZeroWord;
        csr_we_o = `WriteDisable;
        op1_o = `ZeroWord;
        op2_o = `ZeroWord;
        op1_jump_o = `ZeroWord;
        op2_jump_o = `ZeroWord;
        predict_taken_o = `False;
        predict_target_o = `ZeroWord;

        case (opcode)
            // I-type 算术/逻辑立即数，opcode=7'b0010011：
            // - 指令例子：addi/slti/sltiu/xori/ori/andi/slli/srli/srai。
            // - 读 rs1，不读 rs2。
            // - imm = sign_extend(inst[31:20])，即 {{20{inst[31]}}, inst[31:20]}。
            // - rd 写回使能打开。
            // - ID 不做 ALU，ID 只把 op1=rs1、op2=imm 送给 EX。
            `INST_TYPE_I: begin
                case (funct3)
                    `INST_ADDI, `INST_SLTI, `INST_SLTIU, `INST_XORI, `INST_ORI, `INST_ANDI, `INST_SLLI, `INST_SRI: begin
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `ZeroReg;
                        op1_o = reg1_data;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                    end
                endcase
            end
            // R-type / RV32M，opcode=7'b0110011：
            // - funct7=7'b0000000 或 7'b0100000：普通 R-type ALU。
            //   例子：add/sub/sll/slt/sltu/xor/srl/sra/or/and。
            // - funct7=7'b0000001：RV32M 乘除法扩展。
            // - 读 rs1 和 rs2。
            // - 普通 ALU/乘法最终写 rd。
            // - 除法在 div.v 多周期完成，本拍先不让普通 EX 结果写 rd，所以 reg_we_o=0。
            `INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `INST_ADD_SUB, `INST_SLL, `INST_SLT, `INST_SLTU, `INST_XOR, `INST_SR, `INST_OR, `INST_AND: begin
                            reg_we_o = `WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_data;
                            op2_o = reg2_data;
                        end
                        default: begin
                            reg_we_o = `WriteDisable;
                            reg_waddr_o = `ZeroReg;
                            reg1_raddr_o = `ZeroReg;
                            reg2_raddr_o = `ZeroReg;
                        end
                    endcase
                end else if (funct7 == 7'b0000001) begin
                    case (funct3)
                        `INST_MUL, `INST_MULHU, `INST_MULH, `INST_MULHSU: begin
                            reg_we_o = `WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_data;
                            op2_o = reg2_data;
                        end
                        `INST_DIV, `INST_DIVU, `INST_REM, `INST_REMU: begin
                            reg_we_o = `WriteDisable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_data;
                            op2_o = reg2_data;
                            // 除法启动后 EX 会让 PC 跳到 inst_addr_i + 4，避免重复发射除法指令。
                            // div.v 完成后再通过 div 写回路径写 rd。
                            op1_jump_o = inst_addr_i;
                            op2_jump_o = 32'h4;
                        end
                        default: begin
                            reg_we_o = `WriteDisable;
                            reg_waddr_o = `ZeroReg;
                            reg1_raddr_o = `ZeroReg;
                            reg2_raddr_o = `ZeroReg;
                        end
                    endcase
                end else begin
                    reg_we_o = `WriteDisable;
                    reg_waddr_o = `ZeroReg;
                    reg1_raddr_o = `ZeroReg;
                    reg2_raddr_o = `ZeroReg;
                end
            end
            // Load，opcode=7'b0000011：
            // - 指令例子：lb/lh/lw/lbu/lhu。
            // - 地址 = rs1 + sign_extend(inst[31:20])。
            // - 读 rs1 作为 base，不读 rs2。
            // - rd 最终写回 load 数据，所以 reg_we_o=1。
            // - ID 只准备 op1=base、op2=offset；EX 计算地址，MEM 处理字节/半字扩展。
            `INST_TYPE_L: begin
                case (funct3)
                    `INST_LB, `INST_LH, `INST_LW, `INST_LBU, `INST_LHU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_data;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                    end
                endcase
            end
            // Store，opcode=7'b0100011：
            // - 指令例子：sb/sh/sw。
            // - 地址 = rs1 + sign_extend({inst[31:25], inst[11:7]})。
            // - 读 rs1 作为 base，读 rs2 作为待写数据。
            // - store 不写 rd，所以 reg_we_o=0。
            // - ID 只准备地址计算操作数；EX 生成 wdata/wmask，MEM 发总线请求。
            `INST_TYPE_S: begin
                case (funct3)
                    `INST_SB, `INST_SW, `INST_SH: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                        op1_o = reg1_data;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                    end
                    default: begin
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                    end
                endcase
            end
            // Branch，opcode=7'b1100011：
            // - 指令例子：beq/bne/blt/bge/bltu/bgeu。
            // - 读 rs1/rs2，EX 比较两者决定 branch taken。
            // - 目标地址 = PC + sign_extend({inst[31],inst[7],inst[30:25],inst[11:8],1'b0})。
            // - branch offset 最低 bit 固定为 0，表示至少 2-byte 对齐；本项目无 C 扩展时实际按 4-byte 指令跑。
            // - branch 不写 rd。
            `INST_TYPE_B: begin
                case (funct3)
                    `INST_BEQ, `INST_BNE, `INST_BLT, `INST_BGE, `INST_BLTU, `INST_BGEU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                        op1_o = reg1_data;
                        op2_o = reg2_data;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = branch_imm;
                        predict_taken_o = branch_predict_taken_i;
                        predict_target_o = branch_predict_target_i;
                    end
                    default: begin
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                    end
                endcase
            end
            // JAL，opcode=7'b1101111：
            // - 直接 PC-relative 跳转。
            // - rd = PC + 4，用于保存返回地址，常见 rd=x1(ra)。
            // - jump target = PC + sign_extend(J-immediate)。
            // - J-immediate 拼接为 {inst[31],inst[19:12],inst[20],inst[30:21],1'b0}。
            `INST_JAL: begin
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = inst_addr_i;
                op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            end
            // JALR，opcode=7'b1100111：
            // - 寄存器间接跳转，常用于函数返回或函数指针调用。
            // - rd = PC + 4。
            // - jump target = rs1 + sign_extend(inst[31:20])。
            `INST_JALR: begin
                reg_we_o = `WriteEnable;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `ZeroReg;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = reg1_data;
                op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
            end
            // LUI，opcode=7'b0110111：
            // - rd = {inst[31:12], 12'b0}。
            // - 不读 rs1/rs2。
            `INST_LUI: begin
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `ZeroWord;
            end
            // AUIPC，opcode=7'b0010111：
            // - rd = PC + {inst[31:12], 12'b0}。
            // - 常用于构造 PC-relative 地址。
            `INST_AUIPC: begin
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end
            // NOP/FENCE：
            // - 本项目 INST_NOP=32'h00000001，opcode=7'b0000001。
            // - FENCE opcode=7'b0001111。
            // - 二者在 ID 阶段都不读源寄存器、不写 rd。
            // - FENCE 在 EX 中会触发跳转/flush，达到刷新前端的效果。
            `INST_NOP_OP: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
            end
            `INST_FENCE: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
            end
            // CSR，opcode=7'b1110011：
            // - CSR 地址在 inst[31:20]，即 12-bit CSR number。
            // - rd 写回旧 CSR 值，所以 reg_we_o=1。
            // - CSR 写回值在 EX 阶段根据 funct3 计算。
            // - CSRRW/CSRRS/CSRRC 使用 rs1 数据作为操作数。
            // - CSRRWI/CSRRSI/CSRRCI 使用 uimm=inst[19:15] 作为操作数。
            `INST_CSR: begin
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `ZeroReg;
                csr_raddr_o = {20'h0, inst_i[31:20]};
                csr_waddr_o = {20'h0, inst_i[31:20]};
                csr_rdata_o = csr_rdata_i;
                csr_we_o = `WriteEnable;
                case (funct3)
                    `INST_CSRRW, `INST_CSRRS, `INST_CSRRC: begin
                        op1_o = reg1_data;
                    end
                    `INST_CSRRWI, `INST_CSRRSI, `INST_CSRRCI: begin
                        op1_o = {27'h0, inst_i[19:15]};
                    end
                    default: begin
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        csr_raddr_o = `ZeroWord;
                        csr_waddr_o = `ZeroWord;
                        csr_we_o = `WriteDisable;
                    end
                endcase
            end
            default: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
            end
        endcase

        // reset 或已确认跳转时，当前 ID 指令属于无效路径，输出全清成 NOP。
        if (rst == `RstEnable || ex_jump_flag_i == `JumpEnable) begin
            inst_o = `INST_NOP;
            inst_addr_o = `ZeroWord;
            reg1_raddr_o = `ZeroReg;
            reg2_raddr_o = `ZeroReg;
            reg1_rdata_o = `ZeroWord;
            reg2_rdata_o = `ZeroWord;
            reg_we_o = `WriteDisable;
            reg_waddr_o = `ZeroReg;
            csr_raddr_o = `ZeroWord;
            csr_we_o = `WriteDisable;
            csr_rdata_o = `ZeroWord;
            csr_waddr_o = `ZeroWord;
            op1_o = `ZeroWord;
            op2_o = `ZeroWord;
            op1_jump_o = `ZeroWord;
            op2_jump_o = `ZeroWord;
            predict_taken_o = `False;
            predict_target_o = `ZeroWord;
        end
    end

endmodule
