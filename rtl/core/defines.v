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

// -----------------------------------------------------------------------------
// 全局宏定义文件
// -----------------------------------------------------------------------------
// 这个文件是整个 CPU core 的“公共词典”，所有模块都会 `include "defines.v"`。
// 面试阅读时可以按下面几类理解：
// - 复位/使能/握手常量：统一所有模块的 True/False、WriteEnable、MEM_REQ 等语义。
// - 中断与暂停编码：ctrl、pc_reg、流水线寄存器、clint 都通过这些宏协调 flush/stall。
// - RV32I/M/CSR 指令编码：id.v 用它们译码，ex.v/mem.v 用它们执行和访存。
// - 数据通路宽度：32-bit 指令、32-bit 通用寄存器、32-bit memory/memory interface 数据宽度。
// - ROM/RAM/cache 参数：仿真和综合时可通过编译宏覆盖默认深度/line 数。
// -----------------------------------------------------------------------------

`define CpuResetAddr 32'h0

// 基本控制常量：注意本项目复位为低有效，rst == RstEnable 表示正在复位。
`define RstEnable 1'b0
`define RstDisable 1'b1
`define ZeroWord 32'h0
`define ZeroReg 5'h0
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define True 1'b1
`define False 1'b0
`define ChipEnable 1'b1
`define ChipDisable 1'b0
`define JumpEnable 1'b1
`define JumpDisable 1'b0
`define DivResultNotReady 1'b0
`define DivResultReady 1'b1
`define DivStart 1'b1
`define DivStop 1'b0
`define HoldEnable 1'b1
`define HoldDisable 1'b0
`define Stop 1'b1
`define NoStop 1'b0
`define MEM_ACK 1'b1
`define MEM_NACK 1'b0
`define MEM_REQ 1'b1
`define MEM_NREQ 1'b0
`define INT_ASSERT 1'b1
`define INT_DEASSERT 1'b0

// 外部中断编码。当前 core 只看 int_flag_i 是否非 0，具体来源由 SoC 顶层映射。
`define INT_BUS 7:0
`define INT_NONE 8'h0
`define INT_RET 8'hff
`define INT_TIMER0 8'b00000001
`define INT_DMA0 8'b00000010
`define INT_TIMER0_ENTRY_ADDR 32'h4

// 流水线暂停级别：数值越“靠后”，表示需要冻结越深的流水级。
// ctrl.v 统一仲裁后输出给 pc_reg/if_id/id_ex/ex_mem/mem_wb。
`define Hold_Flag_Bus   2:0
`define Hold_None 3'b000
`define Hold_Pc   3'b001
`define Hold_If   3'b010
`define Hold_Id   3'b011
`define Hold_Load 3'b100
`define Hold_Ex   3'b101

// RV32I I-type 算术/逻辑立即数指令。
`define INST_TYPE_I 7'b0010011
`define INST_ADDI   3'b000
`define INST_SLTI   3'b010
`define INST_SLTIU  3'b011
`define INST_XORI   3'b100
`define INST_ORI    3'b110
`define INST_ANDI   3'b111
`define INST_SLLI   3'b001
`define INST_SRI    3'b101

// RV32I load 指令，EX 计算地址，MEM 负责按 funct3 做符号/零扩展。
`define INST_TYPE_L 7'b0000011
`define INST_LB     3'b000
`define INST_LH     3'b001
`define INST_LW     3'b010
`define INST_LBU    3'b100
`define INST_LHU    3'b101

// RV32I store 指令，EX 根据地址低两位生成 wmask/wdata。
`define INST_TYPE_S 7'b0100011
`define INST_SB     3'b000
`define INST_SH     3'b001
`define INST_SW     3'b010

// RV32I R-type 和 RV32M 扩展共用 opcode，通过 funct7 区分普通 ALU 与乘除。
`define INST_TYPE_R_M 7'b0110011
// R-type 普通 ALU funct3。
`define INST_ADD_SUB 3'b000
`define INST_SLL    3'b001
`define INST_SLT    3'b010
`define INST_SLTU   3'b011
`define INST_XOR    3'b100
`define INST_SR     3'b101
`define INST_OR     3'b110
`define INST_AND    3'b111
// M 扩展 funct3：乘法在 EX 组合完成，除法走 div.v 多周期单元。
`define INST_MUL    3'b000
`define INST_MULH   3'b001
`define INST_MULHSU 3'b010
`define INST_MULHU  3'b011
`define INST_DIV    3'b100
`define INST_DIVU   3'b101
`define INST_REM    3'b110
`define INST_REMU   3'b111

// 跳转/上位立即数/系统类指令。
`define INST_JAL    7'b1101111
`define INST_JALR   7'b1100111

`define INST_LUI    7'b0110111
`define INST_AUIPC  7'b0010111
`define INST_NOP    32'h00000001
`define INST_NOP_OP 7'b0000001
`define INST_MRET   32'h30200073
`define INST_RET    32'h00008067

`define INST_FENCE  7'b0001111
`define INST_FENCE_I_FUNCT3 3'b001
`define INST_ECALL  32'h73
`define INST_EBREAK 32'h00100073

// B-type 条件分支指令。
`define INST_TYPE_B 7'b1100011
`define INST_BEQ    3'b000
`define INST_BNE    3'b001
`define INST_BLT    3'b100
`define INST_BGE    3'b101
`define INST_BLTU   3'b110
`define INST_BGEU   3'b111

// CSR 指令。ID 读 CSR，EX 计算 CSR 写值，WB 统一提交。
`define INST_CSR    7'b1110011
`define INST_CSRRW  3'b001
`define INST_CSRRS  3'b010
`define INST_CSRRC  3'b011
`define INST_CSRRWI 3'b101
`define INST_CSRRSI 3'b110
`define INST_CSRRCI 3'b111

// 当前实现支持的 machine-mode CSR 地址。
`define CSR_CYCLE   12'hc00
`define CSR_CYCLEH  12'hc80
`define CSR_MTVEC   12'h305
`define CSR_MCAUSE  12'h342
`define CSR_MEPC    12'h341
`define CSR_MIE     12'h304
`define CSR_MSTATUS 12'h300
`define CSR_MSCRATCH 12'h340

// ROM/RAM/cache 默认参数。外部 Makefile/Vivado 工程可以通过 `define 覆盖。
`ifndef RomNum
`define RomNum 4096  // rom depth(how many words)
`endif

`ifndef MemNum
`define MemNum 4096  // memory depth(how many words)
`endif
`define MemBus 31:0
`define MemAddrBus 31:0
`define MemMaskBus 3:0

`define InstBus 31:0
`define InstAddrBus 31:0

// common regs
`define RegAddrBus 4:0
`define RegBus 31:0
`define DoubleRegBus 63:0
`define RegWidth 32
`define RegNum 32        // reg num
`define RegNumLog2 5

`ifndef RomWaitCycles
`define RomWaitCycles 0
`endif

`ifndef RamWaitCycles
`define RamWaitCycles 0
`endif

`ifndef ICacheLineWords
`define ICacheLineWords 8
`endif

`ifndef ICacheLineCount
`define ICacheLineCount 256
`endif

`ifndef DCacheLineCount
`define DCacheLineCount 128
`endif

`ifndef DCacheLineWords
`define DCacheLineWords 8
`endif
