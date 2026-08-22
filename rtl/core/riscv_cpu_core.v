/*
Copyright 2019 Blue Liang, liangkangnan@163.com
Copyright 2026 project contributors

Modified by Chenkun Wu for:
- explicit five-stage pipeline integration
- I-Cache / D-Cache integration
- PMU observation hooks
- interrupt / debug / memory interface interface cleanup

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

`ifndef TinyriscvBranchPredictorEntries
`define TinyriscvBranchPredictorEntries 32
`endif

// RISC-V CPU core top with explicit MEM stage.
// -----------------------------------------------------------------------------
// TinyRISC-V CPU core 顶层
// -----------------------------------------------------------------------------
// 这个文件只集成 CPU core 内部模块，不直接实例化 SoC 外设。
//
// 五级流水线：
// - IF：pc_reg + ifetch + icache，产生指令和 PC。
// - ID：if_id + id + regs/csr read，完成译码、立即数生成、寄存器读和旁路。
// - EX：ex + div，执行 ALU/branch/jump/CSR 计算，并生成 load/store 请求。
// - MEM：ex_mem + mem + dcache，等待数据存储访问完成，完成 load 数据扩展。
// - WB：mem_wb，把寄存器/CSR 写回提交到 regs/csr_reg。
//
// 对外接口：
// - mem_pc_*：取指侧 memory interface master，通常接 SoC memory interface 的 instruction master。
// - mem_ex_*：数据侧 memory interface master，承载 load/store 和 D-cache miss/store/bypass。
// - jtag_reg_*：调试器直接读写通用寄存器。
// - int_i：SoC 外设汇总后的中断输入。
// - perf_*：给 PMU/验证环境观察 committed instruction、stall、中断和除法状态。
//
// 面试重点：
// - 本文件是理解 CPU 数据通路的入口，重点看实例化顺序和 hold/jump 信号如何贯穿。
// - 外设、APB、DDR、NPU 不在这里；它们挂在 CPU core 外面的 SoC/memory interface 层。
// -----------------------------------------------------------------------------
module riscv_cpu_core #(
    // A larger direct-mapped predictor reduces destructive aliases between
    // independent loop/if branch PCs without changing the architectural ISA.
    parameter integer BRANCH_PREDICTOR_ENTRIES = `TinyriscvBranchPredictorEntries
)(

    input wire clk,
    input wire rst,

    output wire[`MemAddrBus] mem_ex_addr_o,
    input wire[`MemBus] mem_ex_data_i,
    output wire[`MemBus] mem_ex_data_o,
    output wire[`MemMaskBus] mem_ex_wmask_o,
    output wire mem_ex_req_o,
    output wire mem_ex_we_o,
    output wire[7:0] mem_ex_burst_len_o,
    input wire mem_ex_ready_i,

    output wire[`MemAddrBus] mem_pc_addr_o,
    input wire[`MemBus] mem_pc_data_i,
    output wire mem_pc_req_o,
    output wire[7:0] mem_pc_burst_len_o,
    input wire mem_pc_ready_i,

    input wire[`RegAddrBus] jtag_reg_addr_i,
    input wire[`RegBus] jtag_reg_data_i,
    input wire jtag_reg_we_i,
    output wire[`RegBus] jtag_reg_data_o,

    input wire jtag_halt_flag_i,
    input wire jtag_reset_flag_i,

    input wire[`INT_BUS] int_i,

    output wire[`InstBus] perf_inst_o,
    output wire[`Hold_Flag_Bus] perf_hold_flag_o,
    output wire perf_int_assert_o,
    output wire perf_div_busy_o,
    output wire perf_icache_hit_o,
    output wire perf_icache_miss_o,
    output wire perf_dcache_load_hit_o,
    output wire perf_dcache_load_miss_o,
    output wire perf_dcache_store_hit_o,
    output wire perf_dcache_store_miss_o,
    output wire perf_branch_redirect_o,
    output wire perf_branch_flush_o,
    output wire[2:0] perf_prefetch_occupancy_o,
    output wire perf_prefetch_full_o,
    output wire perf_prefetch_stall_o,
    output wire perf_branch_predict_hit_o,
    output wire perf_branch_predict_miss_o,
    output wire perf_dcache_load_miss_stall_o,
    output wire perf_dcache_store_wait_o,
    output wire perf_id_contention_o,
    output wire perf_store_buffer_enqueue_o,
    output wire perf_store_buffer_full_stall_o,
    output wire perf_store_buffer_drain_o

    );

    wire[`InstAddrBus] pc_pc_o;

    wire[`InstBus] if_inst_o;
    wire[`InstAddrBus] if_inst_addr_o;
    wire[`INT_BUS] if_int_flag_o;
    wire if_replay_hold_o;

    wire[`InstBus] fetch_resp_inst_o;
    wire[`InstAddrBus] fetch_resp_addr_o;
    wire fetch_resp_valid_o;
    wire fetch_hold_flag_o;
    wire[2:0] fetch_queue_occupancy_o;
    wire fetch_queue_full_o;
    wire fetch_queue_stall_o;
    wire fetch_resp_ready_o;
    wire[`InstBus] fetch_backend_inst_o;
    wire fetch_backend_hold_o;
    wire[`MemAddrBus] fetch_mem_addr_o;
    wire fetch_mem_req_o;
    wire[7:0] fetch_mem_burst_len_o;
    wire[`MemAddrBus] if_bus_addr_o;
    wire if_bus_req_o;

    wire[`RegAddrBus] id_reg1_raddr_o;
    wire[`RegAddrBus] id_reg2_raddr_o;
    wire[`InstBus] id_inst_o;
    wire[`InstAddrBus] id_inst_addr_o;
    wire[`RegBus] id_reg1_rdata_o;
    wire[`RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`RegAddrBus] id_reg_waddr_o;
    wire[`MemAddrBus] id_csr_raddr_o;
    wire id_csr_we_o;
    wire[`RegBus] id_csr_rdata_o;
    wire[`MemAddrBus] id_csr_waddr_o;
    wire[`MemAddrBus] id_op1_o;
    wire[`MemAddrBus] id_op2_o;
    wire[`MemAddrBus] id_op1_jump_o;
    wire[`MemAddrBus] id_op2_jump_o;
    wire id_predict_taken_o;
    wire[`InstAddrBus] id_predict_target_o;
    wire branch_predict_taken;
    wire[`InstAddrBus] branch_predict_target;
    wire branch_lookup_valid = (if_inst_o[6:0] == `INST_TYPE_B);
    wire[`InstAddrBus] branch_lookup_imm = {{20{if_inst_o[31]}}, if_inst_o[7], if_inst_o[30:25], if_inst_o[11:8], 1'b0};

    wire[`InstBus] ie_inst_o;
    wire[`InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`RegAddrBus] ie_reg_waddr_o;
    wire[`RegBus] ie_reg1_rdata_o;
    wire[`RegBus] ie_reg2_rdata_o;
    wire ie_csr_we_o;
    wire[`MemAddrBus] ie_csr_waddr_o;
    wire[`RegBus] ie_csr_rdata_o;
    wire[`MemAddrBus] ie_op1_o;
    wire[`MemAddrBus] ie_op2_o;
    wire[`MemAddrBus] ie_op1_jump_o;
    wire[`MemAddrBus] ie_op2_jump_o;
    wire ie_predict_taken_o;
    wire[`InstAddrBus] ie_predict_target_o;

    wire[`MemAddrBus] ex_mem_addr_o;
    wire[`MemBus] ex_mem_wdata_o;
    wire[`MemMaskBus] ex_mem_wmask_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire ex_mem_load_o;
    wire[2:0] ex_mem_funct3_o;
    wire[1:0] ex_mem_addr_lsb_o;
    wire[`RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`RegAddrBus] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[`InstAddrBus] ex_jump_addr_o;
    wire ex_icache_invalidate_o;
    wire ex_branch_predict_hit_o;
    wire ex_branch_predict_miss_o;
    wire branch_resolve_valid;
    wire[`InstAddrBus] branch_resolve_pc;
    wire branch_resolve_taken;
    wire[`InstAddrBus] branch_resolve_target;
    wire ex_div_start_o;
    wire[`RegBus] ex_div_dividend_o;
    wire[`RegBus] ex_div_divisor_o;
    wire[2:0] ex_div_op_o;
    wire[`RegAddrBus] ex_div_reg_waddr_o;
    wire[`RegBus] ex_csr_wdata_o;
    wire ex_csr_we_o;
    wire[`MemAddrBus] ex_csr_waddr_o;

    wire[`InstBus] em_inst_o;
    wire[`RegBus] em_reg_wdata_o;
    wire em_reg_we_o;
    wire[`RegAddrBus] em_reg_waddr_o;
    wire[`RegBus] em_csr_wdata_o;
    wire em_csr_we_o;
    wire[`MemAddrBus] em_csr_waddr_o;
    wire[`MemAddrBus] em_mem_addr_o;
    wire[`MemBus] em_mem_wdata_o;
    wire[`MemMaskBus] em_mem_wmask_o;
    wire em_mem_we_o;
    wire em_mem_req_o;
    wire em_mem_load_o;
    wire[2:0] em_mem_funct3_o;
    wire[1:0] em_mem_addr_lsb_o;

    wire[`MemAddrBus] mem_cpu_addr_o;
    wire[`MemBus] mem_cpu_wdata_o;
    wire[`MemMaskBus] mem_cpu_wmask_o;
    wire mem_cpu_we_o;
    wire mem_cpu_req_o;
    wire[`MemBus] mem_cpu_rdata_i;
    wire mem_cpu_ready_i;
    wire[`MemBus] dcache_cpu_rdata_o;
    wire dcache_cpu_ready_o;
    wire[`MemAddrBus] mem_bus_addr_o;
    wire[`MemBus] mem_bus_wdata_o;
    wire[`MemMaskBus] mem_bus_wmask_o;
    wire mem_bus_we_o;
    wire mem_bus_req_o;
    wire[`InstBus] mem_inst_o;
    wire[`RegBus] mem_reg_wdata_o;
    wire mem_reg_we_o;
    wire[`RegAddrBus] mem_reg_waddr_o;
    wire[`RegBus] mem_csr_wdata_o;
    wire mem_csr_we_o;
    wire[`MemAddrBus] mem_csr_waddr_o;
    wire mem_hold_flag_o;

    wire[`InstBus] wb_inst_o;
    wire[`RegBus] wb_reg_wdata_o;
    wire wb_reg_we_o;
    wire[`RegAddrBus] wb_reg_waddr_o;
    wire[`RegBus] wb_csr_wdata_o;
    wire wb_csr_we_o;
    wire[`MemAddrBus] wb_csr_waddr_o;

    wire[`RegBus] regs_rdata1_o;
    wire[`RegBus] regs_rdata2_o;

    wire[`RegBus] csr_data_o;
    wire[`RegBus] csr_clint_data_o;
    wire csr_global_int_en_o;
    wire[`RegBus] csr_clint_csr_mtvec;
    wire[`RegBus] csr_clint_csr_mepc;
    wire[`RegBus] csr_clint_csr_mstatus;

    wire[`Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`InstAddrBus] ctrl_jump_addr_o;

    wire[`RegBus] div_result_o;
    wire div_ready_o;
    wire div_busy_o;
    wire[`RegAddrBus] div_reg_waddr_o;

    wire clint_we_o;
    wire[`MemAddrBus] clint_waddr_o;
    wire[`MemAddrBus] clint_raddr_o;
    wire[`RegBus] clint_data_o;
    wire[`InstAddrBus] clint_int_addr_o;
    wire clint_int_assert_o;
    wire clint_hold_flag_o;

    // load-use hazard：
    // 当前 EX 指令是 load，且 ID 指令需要读取同一个 rd 时，load 数据还没到 MEM/WB，
    // EX->ID 旁路无法提供结果，因此插入一拍气泡。
    wire load_hazard_flag = ex_mem_load_o && (ex_reg_we_o == `WriteEnable) && (ex_reg_waddr_o != `ZeroReg) &&
        (((id_reg1_raddr_o != `ZeroReg) && (id_reg1_raddr_o == ex_reg_waddr_o)) ||
         ((id_reg2_raddr_o != `ZeroReg) && (id_reg2_raddr_o == ex_reg_waddr_o)));

    // Do not gate an ID-stage prediction with ctrl_hold_flag_o.  ctrl consumes
    // fetch_hold_flag_o, while a prediction redirect flushes ifetch; using the
    // aggregated ctrl output here formed a combinational loop:
    //
    //   ifetch hold -> ctrl -> prediction redirect/flush -> ifetch hold
    //
    // Only the independent backend blockers are relevant to accepting a new
    // prediction.  The actual EX/trap redirect still has priority below.
    wire id_predict_blocked = mem_hold_flag_o || load_hazard_flag ||
                              ex_hold_flag_o || clint_hold_flag_o ||
                              jtag_halt_flag_i || ex_jump_flag_o;
    wire id_predict_accept = id_predict_taken_o && !id_predict_blocked;
    wire frontend_jump_flag = ctrl_jump_flag_o || id_predict_accept;
    wire[`InstAddrBus] frontend_jump_addr = (ctrl_jump_flag_o == `JumpEnable) ? ctrl_jump_addr_o : id_predict_target_o;
    wire[`Hold_Flag_Bus] if_id_hold_flag = (id_predict_accept == `True) ? `Hold_Id : ctrl_hold_flag_o;

// D-cache 可通过 DisableDCache 编译宏关闭。
// 开启时，MEM 先访问 dcache，dcache 再决定 hit/miss/bypass 后访问 memory interface。
// 关闭时，MEM 直接把 load/store 请求接到 mem_ex_*。
`ifndef DisableDCache
    assign mem_ex_addr_o = mem_bus_addr_o;
    assign mem_ex_data_o = mem_bus_wdata_o;
    assign mem_ex_wmask_o = mem_bus_wmask_o;
    assign mem_ex_req_o = mem_bus_req_o;
    assign mem_ex_we_o = mem_bus_we_o;
    assign mem_cpu_rdata_i = dcache_cpu_rdata_o;
    assign mem_cpu_ready_i = dcache_cpu_ready_o;
`else
    assign mem_ex_addr_o = mem_cpu_addr_o;
    assign mem_ex_data_o = mem_cpu_wdata_o;
    assign mem_ex_wmask_o = mem_cpu_wmask_o;
    assign mem_ex_req_o = mem_cpu_req_o;
    assign mem_ex_we_o = mem_cpu_we_o;
    assign mem_cpu_rdata_i = mem_ex_data_i;
    assign mem_cpu_ready_i = mem_ex_ready_i;
`endif
    // 取指侧 memory interface 接口来自 ifetch/icache 后端。
    assign mem_pc_addr_o = if_bus_addr_o;
    assign mem_pc_req_o = if_bus_req_o;
`ifdef DisableICache
    assign mem_pc_burst_len_o = 8'd0;
`else
    assign mem_pc_burst_len_o = fetch_mem_burst_len_o;
`endif

    // PMU/验证观测信号，不参与 CPU 功能决策。
    assign perf_inst_o = wb_inst_o;
    assign perf_hold_flag_o = ctrl_hold_flag_o;
    assign perf_int_assert_o = clint_int_assert_o && (clint_int_addr_o == csr_clint_csr_mtvec);
    assign perf_div_busy_o = div_busy_o;
    assign perf_branch_redirect_o = ex_jump_flag_o;
    assign perf_branch_flush_o = (ctrl_hold_flag_o == `Hold_Id);

    // IF stage：PC 只根据 ctrl 输出的 hold/jump 更新。
    pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        .jtag_reset_flag_i(jtag_reset_flag_i),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(frontend_jump_flag),
        .jump_addr_i(frontend_jump_addr)
    );

    // 全局流水线控制：统一仲裁跳转、取指等待、访存等待、load-use、JTAG halt、trap。
    ctrl u_ctrl(
        .rst(rst),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .hold_flag_ex_i(ex_hold_flag_o),
        .hold_flag_mem_i(mem_hold_flag_o),
        .hold_flag_load_i(load_hazard_flag),
        .hold_flag_if_i(fetch_hold_flag_o || if_replay_hold_o),
        .hold_flag_o(ctrl_hold_flag_o),
        .hold_flag_clint_i(clint_hold_flag_o),
        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o),
        .jtag_halt_flag_i(jtag_halt_flag_i)
    );

    // 取指请求适配：稳定 outstanding PC，并把返回指令缓存到 IF/ID 可接收。
    // Only consume a fetch response when the pipeline can advance the PC too.
    // This prevents a response captured during a backend stall from being
    // consumed once with a frozen PC and then fetched a second time.
    assign fetch_resp_ready_o = (~if_replay_hold_o) &&
                                (~mem_hold_flag_o) &&
                                (~load_hazard_flag);

    ifetch u_ifetch(
        .clk(clk),
        .rst(rst),
        .flush_i(frontend_jump_flag),
        .freeze_i(mem_hold_flag_o),
        .pc_i(pc_pc_o),
        .resp_ready_i(fetch_resp_ready_o),
        .backend_inst_i(fetch_backend_inst_o),
        .backend_hold_i(fetch_backend_hold_o),
        .backend_addr_o(fetch_mem_addr_o),
        .backend_req_o(fetch_mem_req_o),
        .resp_inst_o(fetch_resp_inst_o),
        .resp_addr_o(fetch_resp_addr_o),
        .resp_valid_o(fetch_resp_valid_o),
        .hold_flag_o(fetch_hold_flag_o),
        .perf_queue_occupancy_o(fetch_queue_occupancy_o),
        .perf_queue_full_o(fetch_queue_full_o),
        .perf_queue_stall_o(fetch_queue_stall_o)
    );

// I-cache 可通过 DisableICache 编译宏关闭。
// 开启时，ifetch 的 backend 是 icache；关闭时，ifetch 直接访问 mem_pc_*。
`ifndef DisableICache
    icache u_icache(
        .clk(clk),
        .rst(rst),
        .cpu_addr_i(fetch_mem_addr_o),
        .cpu_req_i(fetch_mem_req_o),
        .invalidate_i(ex_icache_invalidate_o),
        .cpu_inst_o(fetch_backend_inst_o),
        .hold_flag_o(fetch_backend_hold_o),
        .perf_hit_o(perf_icache_hit_o),
        .perf_miss_o(perf_icache_miss_o),
        .mem_addr_o(if_bus_addr_o),
        .mem_req_o(if_bus_req_o),
        .mem_burst_len_o(fetch_mem_burst_len_o),
        .mem_data_i(mem_pc_data_i),
        .mem_ready_i(mem_pc_ready_i)
    );
`else
    assign fetch_backend_inst_o = mem_pc_data_i;
    assign fetch_backend_hold_o = if_bus_req_o && (~mem_pc_ready_i);
    assign if_bus_addr_o = fetch_mem_addr_o;
    assign if_bus_req_o = fetch_mem_req_o;
    assign fetch_mem_burst_len_o = 8'd0;
    assign perf_icache_hit_o = `False;
    assign perf_icache_miss_o = `False;
`endif

    // 通用寄存器堆：WB 写回，ID 双读，JTAG 调试读写。
    regs u_regs(
        .clk(clk),
        .rst(rst),
        .we_i(wb_reg_we_o),
        .waddr_i(wb_reg_waddr_o),
        .wdata_i(wb_reg_wdata_o),
        .raddr1_i(id_reg1_raddr_o),
        .rdata1_o(regs_rdata1_o),
        .raddr2_i(id_reg2_raddr_o),
        .rdata2_o(regs_rdata2_o),
        .jtag_we_i(jtag_reg_we_i),
        .jtag_addr_i(jtag_reg_addr_i),
        .jtag_data_i(jtag_reg_data_i),
        .jtag_data_o(jtag_reg_data_o)
    );

    // CSR 文件：普通 CSR 指令和 CLINT trap 流程共享。
    csr_reg u_csr_reg(
        .clk(clk),
        .rst(rst),
        .we_i(wb_csr_we_o),
        .raddr_i(id_csr_raddr_o),
        .waddr_i(wb_csr_waddr_o),
        .data_i(wb_csr_wdata_o),
        .data_o(csr_data_o),
        .global_int_en_o(csr_global_int_en_o),
        .clint_we_i(clint_we_o),
        .clint_raddr_i(clint_raddr_o),
        .clint_waddr_i(clint_waddr_o),
        .clint_data_i(clint_data_o),
        .clint_data_o(csr_clint_data_o),
        .clint_csr_mtvec(csr_clint_csr_mtvec),
        .clint_csr_mepc(csr_clint_csr_mepc),
        .clint_csr_mstatus(csr_clint_csr_mstatus)
    );

    // IF/ID：带两项 skid buffer，解决取指响应与译码消费速率不一致。
    if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(fetch_resp_inst_o),
        .inst_addr_i(fetch_resp_addr_o),
        .inst_valid_i(fetch_resp_valid_o && fetch_resp_ready_o),
        .int_flag_i(int_i),
        .int_flag_o(if_int_flag_o),
        .replay_hold_o(if_replay_hold_o),
        .hold_flag_i(if_id_hold_flag),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    // ID：译码、立即数生成、寄存器/CSR 读结果整理、EX/MEM/WB 旁路。
    id u_id(
        .rst(rst),
        .inst_i(if_inst_o),
        .inst_addr_i(if_inst_addr_o),
        .reg1_rdata_i(regs_rdata1_o),
        .reg2_rdata_i(regs_rdata2_o),
        .ex_jump_flag_i(ex_jump_flag_o),
        .branch_predict_taken_i(branch_predict_taken),
        .branch_predict_target_i(branch_predict_target),
        .ex_reg_we_i(ex_reg_we_o),
        .ex_reg_waddr_i(ex_reg_waddr_o),
        .ex_reg_wdata_i(ex_reg_wdata_o),
        .ex_load_i(ex_mem_load_o),
        .mem_reg_we_i(mem_reg_we_o),
        .mem_reg_waddr_i(mem_reg_waddr_o),
        .mem_reg_wdata_i(mem_reg_wdata_o),
        .wb_reg_we_i(wb_reg_we_o),
        .wb_reg_waddr_i(wb_reg_waddr_o),
        .wb_reg_wdata_i(wb_reg_wdata_o),
        .reg1_raddr_o(id_reg1_raddr_o),
        .reg2_raddr_o(id_reg2_raddr_o),
        .inst_o(id_inst_o),
        .inst_addr_o(id_inst_addr_o),
        .reg1_rdata_o(id_reg1_rdata_o),
        .reg2_rdata_o(id_reg2_rdata_o),
        .reg_we_o(id_reg_we_o),
        .reg_waddr_o(id_reg_waddr_o),
        .op1_o(id_op1_o),
        .op2_o(id_op2_o),
        .op1_jump_o(id_op1_jump_o),
        .op2_jump_o(id_op2_jump_o),
        .predict_taken_o(id_predict_taken_o),
        .predict_target_o(id_predict_target_o),
        .csr_rdata_i(csr_data_o),
        .csr_raddr_o(id_csr_raddr_o),
        .csr_we_o(id_csr_we_o),
        .csr_rdata_o(id_csr_rdata_o),
        .csr_waddr_o(id_csr_waddr_o)
    );

    branch_predictor #(.ENTRY_COUNT(BRANCH_PREDICTOR_ENTRIES)) u_branch_predictor(
        .clk(clk), .rst(rst),
        .lookup_valid_i(branch_lookup_valid),
        .lookup_pc_i(if_inst_addr_o),
        .fallback_taken_i(if_inst_o[31]),
        .fallback_target_i(if_inst_addr_o + branch_lookup_imm),
        .predict_taken_o(branch_predict_taken),
        .predict_target_o(branch_predict_target),
        .update_valid_i(branch_resolve_valid),
        .update_pc_i(branch_resolve_pc),
        .update_taken_i(branch_resolve_taken),
        .update_target_i(branch_resolve_target)
    );

    // ID/EX：把译码结果推进 EX，必要时插入气泡。
    id_ex u_id_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .reg_we_i(id_reg_we_o),
        .reg_waddr_i(id_reg_waddr_o),
        .reg1_rdata_i(id_reg1_rdata_o),
        .reg2_rdata_i(id_reg2_rdata_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(ie_inst_o),
        .inst_addr_o(ie_inst_addr_o),
        .reg_we_o(ie_reg_we_o),
        .reg_waddr_o(ie_reg_waddr_o),
        .reg1_rdata_o(ie_reg1_rdata_o),
        .reg2_rdata_o(ie_reg2_rdata_o),
        .op1_i(id_op1_o),
        .op2_i(id_op2_o),
        .op1_jump_i(id_op1_jump_o),
        .op2_jump_i(id_op2_jump_o),
        .predict_taken_i(id_predict_taken_o),
        .predict_target_i(id_predict_target_o),
        .op1_o(ie_op1_o),
        .op2_o(ie_op2_o),
        .op1_jump_o(ie_op1_jump_o),
        .op2_jump_o(ie_op2_jump_o),
        .predict_taken_o(ie_predict_taken_o),
        .predict_target_o(ie_predict_target_o),
        .csr_we_i(id_csr_we_o),
        .csr_waddr_i(id_csr_waddr_o),
        .csr_rdata_i(id_csr_rdata_o),
        .csr_we_o(ie_csr_we_o),
        .csr_waddr_o(ie_csr_waddr_o),
        .csr_rdata_o(ie_csr_rdata_o)
    );

    // EX：ALU/branch/jump/mul/div 控制、CSR 写值、load/store 请求生成。
    ex u_ex(
        .rst(rst),
        .inst_i(ie_inst_o),
        .inst_addr_i(ie_inst_addr_o),
        .reg_we_i(ie_reg_we_o),
        .reg_waddr_i(ie_reg_waddr_o),
        .reg1_rdata_i(ie_reg1_rdata_o),
        .reg2_rdata_i(ie_reg2_rdata_o),
        .op1_i(ie_op1_o),
        .op2_i(ie_op2_o),
        .op1_jump_i(ie_op1_jump_o),
        .op2_jump_i(ie_op2_jump_o),
        .predict_taken_i(ie_predict_taken_o),
        .predict_target_i(ie_predict_target_o),
        .mem_addr_o(ex_mem_addr_o),
        .mem_wdata_o(ex_mem_wdata_o),
        .mem_wmask_o(ex_mem_wmask_o),
        .mem_we_o(ex_mem_we_o),
        .mem_req_o(ex_mem_req_o),
        .mem_load_o(ex_mem_load_o),
        .mem_funct3_o(ex_mem_funct3_o),
        .mem_addr_lsb_o(ex_mem_addr_lsb_o),
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o),
        .icache_invalidate_o(ex_icache_invalidate_o),
        .branch_predict_hit_o(ex_branch_predict_hit_o),
        .branch_predict_miss_o(ex_branch_predict_miss_o),
        .branch_resolve_valid_o(branch_resolve_valid),
        .branch_resolve_pc_o(branch_resolve_pc),
        .branch_resolve_taken_o(branch_resolve_taken),
        .branch_resolve_target_o(branch_resolve_target),
        .int_assert_i(clint_int_assert_o),
        .int_addr_i(clint_int_addr_o),
        .div_ready_i(div_ready_o),
        .div_result_i(div_result_o),
        .div_busy_i(div_busy_o),
        .div_reg_waddr_i(div_reg_waddr_o),
        .div_start_o(ex_div_start_o),
        .div_dividend_o(ex_div_dividend_o),
        .div_divisor_o(ex_div_divisor_o),
        .div_op_o(ex_div_op_o),
        .div_reg_waddr_o(ex_div_reg_waddr_o),
        .csr_we_i(ie_csr_we_o),
        .csr_waddr_i(ie_csr_waddr_o),
        .csr_rdata_i(ie_csr_rdata_o),
        .csr_wdata_o(ex_csr_wdata_o),
        .csr_we_o(ex_csr_we_o),
        .csr_waddr_o(ex_csr_waddr_o)
    );

    // EX/MEM：固化访存事务，后端等待时保持请求稳定。
    ex_mem u_ex_mem(
        .clk(clk),
        .rst(rst),
        .inst_i(ie_inst_o),
        .reg_wdata_i(ex_reg_wdata_o),
        .reg_we_i(ex_reg_we_o),
        .reg_waddr_i(ex_reg_waddr_o),
        .csr_wdata_i(ex_csr_wdata_o),
        .csr_we_i(ex_csr_we_o),
        .csr_waddr_i(ex_csr_waddr_o),
        .mem_addr_i(ex_mem_addr_o),
        .mem_wdata_i(ex_mem_wdata_o),
        .mem_wmask_i(ex_mem_wmask_o),
        .mem_we_i(ex_mem_we_o),
        .mem_req_i(ex_mem_req_o),
        .mem_load_i(ex_mem_load_o),
        .mem_funct3_i(ex_mem_funct3_o),
        .mem_addr_lsb_i(ex_mem_addr_lsb_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(em_inst_o),
        .reg_wdata_o(em_reg_wdata_o),
        .reg_we_o(em_reg_we_o),
        .reg_waddr_o(em_reg_waddr_o),
        .csr_wdata_o(em_csr_wdata_o),
        .csr_we_o(em_csr_we_o),
        .csr_waddr_o(em_csr_waddr_o),
        .mem_addr_o(em_mem_addr_o),
        .mem_wdata_o(em_mem_wdata_o),
        .mem_wmask_o(em_mem_wmask_o),
        .mem_we_o(em_mem_we_o),
        .mem_req_o(em_mem_req_o),
        .mem_load_o(em_mem_load_o),
        .mem_funct3_o(em_mem_funct3_o),
        .mem_addr_lsb_o(em_mem_addr_lsb_o)
    );

    // MEM：等待 memory ready，完成 load 数据对齐/符号扩展。
    mem u_mem(
        .rst(rst),
        .inst_i(em_inst_o),
        .reg_wdata_i(em_reg_wdata_o),
        .reg_we_i(em_reg_we_o),
        .reg_waddr_i(em_reg_waddr_o),
        .csr_wdata_i(em_csr_wdata_o),
        .csr_we_i(em_csr_we_o),
        .csr_waddr_i(em_csr_waddr_o),
        .mem_addr_i(em_mem_addr_o),
        .mem_wdata_i(em_mem_wdata_o),
        .mem_wmask_i(em_mem_wmask_o),
        .mem_we_i(em_mem_we_o),
        .mem_req_i(em_mem_req_o),
        .mem_load_i(em_mem_load_o),
        .mem_funct3_i(em_mem_funct3_o),
        .mem_addr_lsb_i(em_mem_addr_lsb_o),
        .mem_rdata_i(mem_cpu_rdata_i),
        .mem_ready_i(mem_cpu_ready_i),
        .mem_addr_o(mem_cpu_addr_o),
        .mem_wdata_o(mem_cpu_wdata_o),
        .mem_wmask_o(mem_cpu_wmask_o),
        .mem_we_o(mem_cpu_we_o),
        .mem_req_o(mem_cpu_req_o),
        .inst_o(mem_inst_o),
        .reg_wdata_o(mem_reg_wdata_o),
        .reg_we_o(mem_reg_we_o),
        .reg_waddr_o(mem_reg_waddr_o),
        .csr_wdata_o(mem_csr_wdata_o),
        .csr_we_o(mem_csr_we_o),
        .csr_waddr_o(mem_csr_waddr_o),
        .hold_flag_o(mem_hold_flag_o)
    );

    // D-cache：direct-mapped，write-through，默认只缓存 RAM 空间。
`ifndef DisableDCache
    dcache u_dcache(
        .clk(clk),
        .rst(rst),
        .cpu_addr_i(mem_cpu_addr_o),
        .cpu_wdata_i(mem_cpu_wdata_o),
        .cpu_wmask_i(mem_cpu_wmask_o),
        .cpu_req_i(mem_cpu_req_o),
        .cpu_we_i(mem_cpu_we_o),
        .invalidate_i(`False),
        .cpu_rdata_o(dcache_cpu_rdata_o),
        .cpu_ready_o(dcache_cpu_ready_o),
        .perf_load_hit_o(perf_dcache_load_hit_o),
        .perf_load_miss_o(perf_dcache_load_miss_o),
        .perf_store_hit_o(perf_dcache_store_hit_o),
        .perf_store_miss_o(perf_dcache_store_miss_o),
        .perf_load_miss_stall_o(perf_dcache_load_miss_stall_o),
        .perf_store_wait_o(perf_dcache_store_wait_o),
        .perf_store_buffer_enqueue_o(perf_store_buffer_enqueue_o),
        .perf_store_buffer_full_stall_o(perf_store_buffer_full_stall_o),
        .perf_store_buffer_drain_o(perf_store_buffer_drain_o),
        .mem_addr_o(mem_bus_addr_o),
        .mem_wdata_o(mem_bus_wdata_o),
        .mem_wmask_o(mem_bus_wmask_o),
        .mem_req_o(mem_bus_req_o),
        .mem_we_o(mem_bus_we_o),
        .mem_burst_len_o(mem_ex_burst_len_o),
        .mem_rdata_i(mem_ex_data_i),
        .mem_ready_i(mem_ex_ready_i)
    );
`else
    assign mem_bus_addr_o = `ZeroWord;
    assign mem_bus_wdata_o = `ZeroWord;
    assign mem_bus_wmask_o = 4'b1111;
    assign mem_bus_req_o = `MEM_NREQ;
    assign mem_bus_we_o = `WriteDisable;
    assign mem_ex_burst_len_o = 8'd0;
    assign perf_dcache_load_hit_o = `False;
    assign perf_dcache_load_miss_o = `False;
    assign perf_dcache_store_hit_o = `False;
    assign perf_dcache_store_miss_o = `False;
    assign perf_dcache_load_miss_stall_o = `False;
    assign perf_dcache_store_wait_o = `False;
    assign perf_store_buffer_enqueue_o = `False;
    assign perf_store_buffer_full_stall_o = `False;
    assign perf_store_buffer_drain_o = `False;
`endif

    assign perf_prefetch_occupancy_o = fetch_queue_occupancy_o;
    assign perf_prefetch_full_o = fetch_queue_full_o;
    assign perf_prefetch_stall_o = fetch_queue_stall_o;
    assign perf_branch_predict_hit_o = ex_branch_predict_hit_o;
    assign perf_branch_predict_miss_o = ex_branch_predict_miss_o;
    assign perf_id_contention_o = if_bus_req_o && mem_bus_req_o;

    // MEM/WB：最终提交到寄存器堆和 CSR 文件前的最后一级流水线寄存器。
    mem_wb u_mem_wb(
        .clk(clk),
        .rst(rst),
        .inst_i(mem_inst_o),
        .reg_wdata_i(mem_reg_wdata_o),
        .reg_we_i(mem_reg_we_o),
        .reg_waddr_i(mem_reg_waddr_o),
        .csr_wdata_i(mem_csr_wdata_o),
        .csr_we_i(mem_csr_we_o),
        .csr_waddr_i(mem_csr_waddr_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(wb_inst_o),
        .reg_wdata_o(wb_reg_wdata_o),
        .reg_we_o(wb_reg_we_o),
        .reg_waddr_o(wb_reg_waddr_o),
        .csr_wdata_o(wb_csr_wdata_o),
        .csr_we_o(wb_csr_we_o),
        .csr_waddr_o(wb_csr_waddr_o)
    );

    // 多周期除法单元，EX 通过 busy/ready 与它握手。
    div u_div(
        .clk(clk),
        .rst(rst),
        .dividend_i(ex_div_dividend_o),
        .divisor_i(ex_div_divisor_o),
        .start_i(ex_div_start_o),
        .op_i(ex_div_op_o),
        .reg_waddr_i(ex_div_reg_waddr_o),
        .result_o(div_result_o),
        .ready_o(div_ready_o),
        .busy_o(div_busy_o),
        .reg_waddr_o(div_reg_waddr_o)
    );

    // CLINT/trap 控制：处理 ECALL/EBREAK/MRET/外部中断，并驱动 CSR 更新和 PC 重定向。
    clint u_clint(
        .clk(clk),
        .rst(rst),
        .int_flag_i(if_int_flag_o),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .div_started_i(ex_div_start_o),
        .data_i(csr_clint_data_o),
        .csr_mtvec(csr_clint_csr_mtvec),
        .csr_mepc(csr_clint_csr_mepc),
        .csr_mstatus(csr_clint_csr_mstatus),
        .we_o(clint_we_o),
        .waddr_o(clint_waddr_o),
        .raddr_o(clint_raddr_o),
        .data_o(clint_data_o),
        .hold_flag_o(clint_hold_flag_o),
        .global_int_en_i(csr_global_int_en_o),
        .int_addr_o(clint_int_addr_o),
        .int_assert_o(clint_int_assert_o)
    );

endmodule
