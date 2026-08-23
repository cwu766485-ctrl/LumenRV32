`timescale 1 ns / 1 ps

`include "../core/defines.v"

// Timing-only microarchitecture harness.  It preserves the real EX -> ID
// forwarding -> ID/EX capture cone while excluding caches and SoC fabric.
// This is not a functional CPU top and must only be used for controlled PPA
// A/B experiments of the JALR feedback path.
module jalr_timing_cone_top(
    input wire clk,
    input wire rst,
    input wire[`InstBus] producer_inst_i,
    input wire[`RegBus] producer_op1_i,
    input wire[`RegBus] producer_op2_i,
    // Models the MEM-stage value available after the one-cycle JALR interlock.
    input wire[`RegBus] late_data_i,
    // Makes the ID/EX capture endpoint observable to synthesis.
    output wire[`MemAddrBus] jalr_target_q
);
    reg[`InstBus] producer_inst_r;
    reg[`RegBus] producer_op1_r;
    reg[`RegBus] producer_op2_r;
    reg[`RegBus] late_data_r;

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            producer_inst_r <= `INST_NOP;
            producer_op1_r <= `ZeroWord;
            producer_op2_r <= `ZeroWord;
            late_data_r <= `ZeroWord;
        end else begin
            producer_inst_r <= producer_inst_i;
            producer_op1_r <= producer_op1_i;
            producer_op2_r <= producer_op2_i;
            late_data_r <= late_data_i;
        end
    end

    wire[`RegBus] ex_reg_wdata;
    wire ex_reg_we;
    wire[`RegAddrBus] ex_reg_waddr;
    wire[`MemAddrBus] unused_mem_addr;
    wire[`MemBus] unused_mem_wdata;
    wire[`MemMaskBus] unused_mem_wmask;
    wire unused_mem_we, unused_mem_req, unused_mem_load;
    wire[2:0] unused_mem_funct3;
    wire[1:0] unused_mem_addr_lsb;
    wire unused_csr_we;
    wire[`MemAddrBus] unused_csr_waddr;
    wire[`RegBus] unused_csr_wdata;
    wire unused_div_start, unused_hold, unused_jump, unused_icache_inv;
    wire[`InstAddrBus] unused_jump_addr;
    wire[`RegBus] unused_dividend, unused_divisor;
    wire[2:0] unused_div_op;
    wire[`RegAddrBus] unused_div_waddr;
    wire unused_bp_hit, unused_bp_miss, unused_branch_valid, unused_branch_taken;
    wire[`InstAddrBus] unused_branch_pc, unused_branch_target;

    ex u_ex(
        .rst(rst), .inst_i(producer_inst_r), .inst_addr_i(`ZeroWord),
        .reg_we_i(`WriteEnable), .reg_waddr_i(5'd5),
        .reg1_rdata_i(producer_op1_r), .reg2_rdata_i(producer_op2_r),
        .csr_we_i(`WriteDisable), .csr_waddr_i(`ZeroWord), .csr_rdata_i(`ZeroWord),
        .int_assert_i(`INT_DEASSERT), .int_addr_i(`ZeroWord),
        .op1_i(producer_op1_r), .op2_i(producer_op2_r),
        .op1_jump_i(`ZeroWord), .op2_jump_i(`ZeroWord),
        .predict_taken_i(`False), .predict_target_i(`ZeroWord),
        .div_ready_i(`DivResultNotReady), .div_result_i(`ZeroWord),
        .div_busy_i(`False), .div_reg_waddr_i(`ZeroReg),
        .mem_addr_o(unused_mem_addr), .mem_wdata_o(unused_mem_wdata),
        .mem_wmask_o(unused_mem_wmask), .mem_we_o(unused_mem_we),
        .mem_req_o(unused_mem_req), .mem_load_o(unused_mem_load),
        .mem_funct3_o(unused_mem_funct3), .mem_addr_lsb_o(unused_mem_addr_lsb),
        .reg_wdata_o(ex_reg_wdata), .reg_we_o(ex_reg_we), .reg_waddr_o(ex_reg_waddr),
        .csr_wdata_o(unused_csr_wdata), .csr_we_o(unused_csr_we), .csr_waddr_o(unused_csr_waddr),
        .div_start_o(unused_div_start), .div_dividend_o(unused_dividend),
        .div_divisor_o(unused_divisor), .div_op_o(unused_div_op),
        .div_reg_waddr_o(unused_div_waddr), .hold_flag_o(unused_hold),
        .jump_flag_o(unused_jump), .jump_addr_o(unused_jump_addr),
        .icache_invalidate_o(unused_icache_inv), .branch_predict_hit_o(unused_bp_hit),
        .branch_predict_miss_o(unused_bp_miss), .branch_resolve_valid_o(unused_branch_valid),
        .branch_resolve_pc_o(unused_branch_pc), .branch_resolve_taken_o(unused_branch_taken),
        .branch_resolve_target_o(unused_branch_target)
    );

    wire[`InstBus] consumer_inst = {12'b0, 5'd5, 3'b000, 5'd1, `INST_JALR};
    wire[`RegBus] id_reg1_data, id_reg2_data;
    wire[`MemAddrBus] id_op1, id_op2, id_op1_jump, id_op2_jump;
    wire id_reg_we, id_csr_we, id_predict_taken;
    wire[`RegAddrBus] id_reg_waddr;
    wire[`MemAddrBus] id_csr_raddr, id_csr_waddr;
    wire[`RegBus] id_csr_data;
    wire[`InstAddrBus] id_inst_addr, id_predict_target;

    id u_id(
        .rst(rst), .inst_i(consumer_inst), .inst_addr_i(`ZeroWord),
        .reg1_rdata_i(`ZeroWord), .reg2_rdata_i(`ZeroWord), .csr_rdata_i(`ZeroWord),
        .ex_reg_we_i(ex_reg_we), .ex_reg_waddr_i(ex_reg_waddr),
        .ex_reg_wdata_i(ex_reg_wdata), .ex_load_i(`False),
        .mem_reg_we_i(`WriteEnable), .mem_reg_waddr_i(5'd5), .mem_reg_wdata_i(late_data_r),
        .wb_reg_we_i(`WriteDisable), .wb_reg_waddr_i(`ZeroReg), .wb_reg_wdata_i(`ZeroWord),
        .ex_jump_flag_i(`False), .branch_predict_taken_i(`False), .branch_predict_target_i(`ZeroWord),
        .reg1_rdata_o(id_reg1_data), .reg2_rdata_o(id_reg2_data), .reg1_raddr_o(), .reg2_raddr_o(),
        .inst_o(), .inst_addr_o(id_inst_addr), .reg_we_o(id_reg_we), .reg_waddr_o(id_reg_waddr),
        .csr_raddr_o(id_csr_raddr), .csr_we_o(id_csr_we), .csr_rdata_o(id_csr_data),
        .csr_waddr_o(id_csr_waddr), .op1_o(id_op1), .op2_o(id_op2),
        .op1_jump_o(id_op1_jump), .op2_jump_o(id_op2_jump),
        .predict_taken_o(id_predict_taken), .predict_target_o(id_predict_target)
    );

    id_ex u_id_ex(
        .clk(clk), .rst(rst), .inst_i(consumer_inst), .inst_addr_i(id_inst_addr),
        .reg_we_i(id_reg_we), .reg_waddr_i(id_reg_waddr), .reg1_rdata_i(id_reg1_data),
        .reg2_rdata_i(id_reg2_data), .csr_we_i(id_csr_we), .csr_waddr_i(id_csr_waddr),
        .csr_rdata_i(id_csr_data), .op1_i(id_op1), .op2_i(id_op2),
        .op1_jump_i(id_op1_jump), .op2_jump_i(id_op2_jump), .predict_taken_i(id_predict_taken),
        .predict_target_i(id_predict_target), .hold_flag_i(`Hold_None),
        .op1_o(), .op2_o(), .op1_jump_o(jalr_target_q), .op2_jump_o(), .predict_taken_o(), .predict_target_o(),
        .inst_o(), .inst_addr_o(), .reg_we_o(), .reg_waddr_o(), .reg1_rdata_o(), .reg2_rdata_o(),
        .csr_we_o(), .csr_waddr_o(), .csr_rdata_o()
    );
endmodule
