`timescale 1 ns / 1 ps

`include "../rtl/core/defines.v"

module axi4_mem_model_tb;

    reg clk;
    reg rst;

    reg[31:0] awaddr;
    reg[7:0] awlen;
    reg[2:0] awsize;
    reg[1:0] awburst;
    reg awvalid;
    wire awready;

    reg[31:0] wdata;
    reg[3:0] wstrb;
    reg wlast;
    reg wvalid;
    wire wready;

    wire[1:0] bresp;
    wire bvalid;
    reg bready;

    reg[31:0] araddr;
    reg[7:0] arlen;
    reg[2:0] arsize;
    reg[1:0] arburst;
    reg arvalid;
    wire arready;

    wire[31:0] rdata;
    wire[1:0] rresp;
    wire rlast;
    wire rvalid;
    reg rready;

    integer beat;
    integer cycle_count;
    reg[31:0] burst_expect[0:3];

    axi4_mem_model #(
        .DEPTH_WORDS(256),
        .WAIT_CYCLES(2)
    ) dut(
        .clk(clk),
        .rst(rst),
        .s_axi_awaddr(awaddr),
        .s_axi_awlen(awlen),
        .s_axi_awsize(awsize),
        .s_axi_awburst(awburst),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wlast(wlast),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr),
        .s_axi_arlen(arlen),
        .s_axi_arsize(arsize),
        .s_axi_arburst(arburst),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rlast(rlast),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready)
    );

    always #5 clk = ~clk;

    always @ (posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count > 2000) begin
                $display("AXI4_MEM_MODEL_TB_TIMEOUT awv=%0d awr=%0d wv=%0d wr=%0d bv=%0d br=%0d arv=%0d arr=%0d rv=%0d rr=%0d rlast=%0d",
                    awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready, rlast);
                $finish(1);
            end
        end
    end

    task automatic wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task automatic axi_wait_aw_handshake;
        begin
            while (1'b1) begin
                @(posedge clk);
                if (awvalid == 1'b1 && awready == 1'b1) begin
                    disable axi_wait_aw_handshake;
                end
            end
        end
    endtask

    task automatic axi_wait_w_handshake;
        begin
            while (1'b1) begin
                @(posedge clk);
                if (wvalid == 1'b1 && wready == 1'b1) begin
                    disable axi_wait_w_handshake;
                end
            end
        end
    endtask

    task automatic axi_wait_b_handshake;
        begin
            while (1'b1) begin
                @(posedge clk);
                if (bvalid == 1'b1 && bready == 1'b1) begin
                    disable axi_wait_b_handshake;
                end
            end
        end
    endtask

    task automatic axi_wait_ar_handshake;
        begin
            while (1'b1) begin
                @(posedge clk);
                if (arvalid == 1'b1 && arready == 1'b1) begin
                    disable axi_wait_ar_handshake;
                end
            end
        end
    endtask

    task automatic burst_write4;
        input [31:0] base;
        begin
            @(negedge clk);
            awaddr = base;
            awlen = 8'd3;
            awsize = 3'd2;
            awburst = 2'b01;
            awvalid = 1'b1;
            axi_wait_aw_handshake();
            @(negedge clk);
            awvalid = 1'b0;

            for (beat = 0; beat < 4; beat = beat + 1) begin
                @(negedge clk);
                wdata = burst_expect[beat];
                wstrb = 4'hf;
                wlast = (beat == 3);
                wvalid = 1'b1;
                axi_wait_w_handshake();
                @(negedge clk);
                wvalid = 1'b0;
                wlast = 1'b0;
            end

            @(negedge clk);
            bready = 1'b1;
            axi_wait_b_handshake();
            @(negedge clk);
            bready = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        awaddr = 32'h0;
        awlen = 8'h0;
        awsize = 3'd2;
        awburst = 2'b01;
        awvalid = 1'b0;
        wdata = 32'h0;
        wstrb = 4'h0;
        wlast = 1'b0;
        wvalid = 1'b0;
        bready = 1'b0;
        araddr = 32'h0;
        arlen = 8'h0;
        arsize = 3'd2;
        arburst = 2'b01;
        arvalid = 1'b0;
        rready = 1'b0;
        cycle_count = 0;

        burst_expect[0] = 32'h1122_3344;
        burst_expect[1] = 32'ha5a5_5a5a;
        burst_expect[2] = 32'h5566_7788;
        burst_expect[3] = 32'hdead_beef;

        repeat (8) @(posedge clk);
        rst = `RstDisable;

        burst_write4(32'h3000_0100);

        @(negedge clk);
        araddr = 32'h3000_0100;
        arlen = 8'd3;
        arsize = 3'd2;
        arburst = 2'b01;
        arvalid = 1'b1;
        axi_wait_ar_handshake();
        @(negedge clk);
        arvalid = 1'b0;

        @(negedge clk);
        rready = 1'b1;
        beat = 0;
        while (beat < 4) begin
            @(posedge clk);
            if (rvalid == 1'b1) begin
                if (rdata !== burst_expect[beat]) begin
                    $display("AXI4_MEM_MODEL_TB_FAIL beat=%0d got=%h expect=%h", beat, rdata, burst_expect[beat]);
                    $finish(1);
                end
                if ((beat == 3) && (rlast !== 1'b1)) begin
                    $display("AXI4_MEM_MODEL_TB_FAIL missing rlast");
                    $finish(1);
                end
                beat = beat + 1;
            end
        end

        $display("AXI4_MEM_MODEL_TB_PASS");
        $finish;
    end

endmodule
