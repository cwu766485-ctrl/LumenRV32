`timescale 1 ns / 1 ps
`include "../rtl/core/defines.v"

// Directed decode-side test for the timing-oriented JALR interlock contract.
// The full-core ISA regression checks architected execution; this test makes
// the intended forwarding selection observable at the RTL boundary.
module id_jalr_forwarding_tb;
    reg rst;
    reg[`InstBus] inst_i;
    reg[`InstAddrBus] inst_addr_i;
    reg[`RegBus] reg1_rdata_i;
    reg[`RegBus] reg2_rdata_i;
    reg[`RegBus] csr_rdata_i;
    reg ex_reg_we_i;
    reg[`RegAddrBus] ex_reg_waddr_i;
    reg[`RegBus] ex_reg_wdata_i;
    reg ex_load_i;
    reg mem_reg_we_i;
    reg[`RegAddrBus] mem_reg_waddr_i;
    reg[`RegBus] mem_reg_wdata_i;
    reg wb_reg_we_i;
    reg[`RegAddrBus] wb_reg_waddr_i;
    reg[`RegBus] wb_reg_wdata_i;
    reg branch_predict_taken_i;
    reg[`InstAddrBus] branch_predict_target_i;

    wire[`RegBus] reg1_rdata_o;
    wire[`MemAddrBus] op1_jump_o;
    wire[`MemAddrBus] op1_o;

    id dut(
        .rst(rst), .inst_i(inst_i), .inst_addr_i(inst_addr_i),
        .reg1_rdata_i(reg1_rdata_i), .reg2_rdata_i(reg2_rdata_i),
        .csr_rdata_i(csr_rdata_i),
        .ex_reg_we_i(ex_reg_we_i), .ex_reg_waddr_i(ex_reg_waddr_i),
        .ex_reg_wdata_i(ex_reg_wdata_i), .ex_load_i(ex_load_i),
        .mem_reg_we_i(mem_reg_we_i), .mem_reg_waddr_i(mem_reg_waddr_i),
        .mem_reg_wdata_i(mem_reg_wdata_i),
        .wb_reg_we_i(wb_reg_we_i), .wb_reg_waddr_i(wb_reg_waddr_i),
        .wb_reg_wdata_i(wb_reg_wdata_i),
        .ex_jump_flag_i(`False),
        .branch_predict_taken_i(branch_predict_taken_i),
        .branch_predict_target_i(branch_predict_target_i),
        .reg1_rdata_o(reg1_rdata_o), .op1_jump_o(op1_jump_o), .op1_o(op1_o),
        .reg2_rdata_o(), .reg1_raddr_o(), .reg2_raddr_o(), .inst_o(),
        .inst_addr_o(), .reg_we_o(), .reg_waddr_o(), .csr_raddr_o(),
        .csr_we_o(), .csr_rdata_o(), .csr_waddr_o(), .op2_o(),
        .op2_jump_o(), .predict_taken_o(), .predict_target_o()
    );

    task automatic expect_jalr_base;
        input[31:0] expected;
        input[255:0] name;
        begin
            #1;
            if (op1_jump_o !== expected)
                $fatal(1, "%0s: got=%h expected=%h", name, op1_jump_o, expected);
        end
    endtask

    task automatic expect_reg1;
        input[31:0] expected;
        input[255:0] name;
        begin
            #1;
            if (reg1_rdata_o !== expected)
                $fatal(1, "%0s: got=%h expected=%h", name, reg1_rdata_o, expected);
        end
    endtask

    initial begin
        rst = `RstDisable;
        inst_addr_i = 32'h100;
        reg1_rdata_i = 32'h11111111;
        reg2_rdata_i = 0;
        csr_rdata_i = 0;
        ex_reg_we_i = `WriteEnable;
        ex_reg_waddr_i = 5'd5;
        ex_reg_wdata_i = 32'heeeeeeee;
        ex_load_i = `False;
        mem_reg_we_i = `WriteEnable;
        mem_reg_waddr_i = 5'd5;
        mem_reg_wdata_i = 32'h22222222;
        wb_reg_we_i = `WriteEnable;
        wb_reg_waddr_i = 5'd5;
        wb_reg_wdata_i = 32'h33333333;
        branch_predict_taken_i = `False;
        branch_predict_target_i = 0;

        // jalr x1, x5, 0: EX value must not feed the timing-relieved target.
        inst_i = {12'h000, 5'd5, 3'b000, 5'd1, `INST_JALR};
        expect_jalr_base(32'h22222222, "JALR uses MEM forwarding");
        expect_reg1(32'h22222222, "JALR capture uses MEM forwarding");

        mem_reg_we_i = `WriteDisable;
        expect_jalr_base(32'h33333333, "JALR uses WB forwarding");

        wb_reg_we_i = `WriteDisable;
        expect_jalr_base(32'h11111111, "JALR uses register file");

        // A non-JALR consumer must retain the original zero-bubble EX bypass.
        inst_i = {7'b0000000, 5'd0, 5'd5, 3'b000, 5'd6, `INST_TYPE_R_M};
        expect_reg1(32'heeeeeeee, "ALU retains EX forwarding");

        $display("ID_JALR_FORWARDING_TB_PASS");
        $finish;
    end
endmodule
