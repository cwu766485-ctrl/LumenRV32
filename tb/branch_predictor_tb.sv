`timescale 1 ns / 1 ps
`include "../rtl/core/defines.v"

module branch_predictor_tb;
    reg clk;
    reg rst;
    reg lookup_valid;
    reg[31:0] lookup_pc;
    reg fallback_taken;
    reg[31:0] fallback_target;
    wire predict_taken;
    wire[31:0] predict_target;
    reg update_valid;
    reg[31:0] update_pc;
    reg update_taken;
    reg[31:0] update_target;

    branch_predictor #(.ENTRY_COUNT(32)) dut(
        .clk(clk), .rst(rst),
        .lookup_valid_i(lookup_valid), .lookup_pc_i(lookup_pc),
        .fallback_taken_i(fallback_taken), .fallback_target_i(fallback_target),
        .predict_taken_o(predict_taken), .predict_target_o(predict_target),
        .update_valid_i(update_valid), .update_pc_i(update_pc),
        .update_taken_i(update_taken), .update_target_i(update_target)
    );

    always #5 clk = ~clk;

    task automatic train;
        input[31:0] pc;
        input taken;
        input[31:0] target;
        begin
            @(negedge clk);
            update_pc = pc;
            update_taken = taken;
            update_target = target;
            update_valid = `True;
            @(posedge clk);
            @(negedge clk);
            update_valid = `False;
        end
    endtask

    task automatic expect_prediction;
        input taken;
        input[31:0] target;
        input[255:0] name;
        begin
            #1;
            if (predict_taken !== taken || predict_target !== target)
                $fatal(1, "%0s: got taken=%b target=%h", name, predict_taken, predict_target);
        end
    endtask

    initial begin
        clk = 0;
        rst = `RstEnable;
        lookup_valid = `True;
        lookup_pc = 32'h00000100;
        fallback_taken = `True;
        fallback_target = 32'h000000f0;
        update_valid = `False;
        update_pc = 0;
        update_taken = `False;
        update_target = 0;

        repeat (3) @(posedge clk);
        rst = `RstDisable;

        // Cold BTB miss must preserve static backward-taken behavior.
        expect_prediction(`True, 32'h000000f0, "cold fallback");

        // Allocate weak-taken entry, then drive it to weak-not-taken.
        train(32'h00000100, `True, 32'h00000080);
        expect_prediction(`True, 32'h00000080, "allocated taken target");
        train(32'h00000100, `False, 32'h00000080);
        expect_prediction(`False, 32'h00000080, "weak not taken");

        // Saturate upward and verify target replacement/update is retained.
        train(32'h00000100, `True, 32'h00000084);
        train(32'h00000100, `True, 32'h00000084);
        expect_prediction(`True, 32'h00000084, "saturating taken");

        // PC 0x180 aliases index [6:2] with 0x100 in a 32-entry table.
        train(32'h00000180, `False, 32'h00000160);
        lookup_pc = 32'h00000180;
        fallback_taken = `True;
        fallback_target = 32'h00000160;
        expect_prediction(`False, 32'h00000160, "direct mapped replacement");

        // Replaced entry must fall back rather than use stale target/counter.
        lookup_pc = 32'h00000100;
        fallback_taken = `True;
        fallback_target = 32'h000000f0;
        expect_prediction(`True, 32'h000000f0, "replaced entry fallback");

        $display("BRANCH_PREDICTOR_TB_PASS");
        $finish;
    end
endmodule
