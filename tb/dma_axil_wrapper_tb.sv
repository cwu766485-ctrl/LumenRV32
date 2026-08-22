`timescale 1 ns / 1 ps

`include "../rtl/core/defines.v"

module dma_axil_wrapper_tb;

    localparam DMA_CTRL   = 32'h0000_0000;
    localparam DMA_STATUS = 32'h0000_0004;
    localparam DMA_SRC    = 32'h0000_0008;
    localparam DMA_DST    = 32'h0000_000c;
    localparam DMA_LEN    = 32'h0000_0010;
    localparam DMA_COUNT  = 32'h0000_0014;

    reg clk;
    reg rst;

    reg[31:0] awaddr;
    reg awvalid;
    wire awready;
    reg[31:0] wdata;
    reg[3:0] wstrb;
    reg wvalid;
    wire wready;
    wire[1:0] bresp;
    wire bvalid;
    reg bready;
    reg[31:0] araddr;
    reg arvalid;
    wire arready;
    wire[31:0] rdata;
    wire[1:0] rresp;
    wire rvalid;
    reg rready;

    wire[31:0] mem_addr;
    wire[31:0] mem_wdata;
    wire[3:0] mem_wmask;
    wire mem_req;
    wire mem_we;
    reg[31:0] mem_rdata;
    wire mem_ready;
    wire busy;
    wire done;
    wire error;
    wire irq;

    reg[31:0] mem[0:255];
    integer i;
    reg[31:0] rd;
    reg done_seen;

    assign mem_ready = 1'b1;

    always #5 clk = ~clk;

    always @ (*) begin
        mem_rdata = mem[mem_addr[9:2]];
    end

    always @ (posedge clk) begin
        if (mem_req && mem_we) begin
            if (mem_wmask[0]) mem[mem_addr[9:2]][7:0] <= mem_wdata[7:0];
            if (mem_wmask[1]) mem[mem_addr[9:2]][15:8] <= mem_wdata[15:8];
            if (mem_wmask[2]) mem[mem_addr[9:2]][23:16] <= mem_wdata[23:16];
            if (mem_wmask[3]) mem[mem_addr[9:2]][31:24] <= mem_wdata[31:24];
        end
    end

    dma_axil_wrapper u_dut(
        .clk(clk),
        .rst(rst),
        .s_axi_awaddr(awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),
        .mem_addr_o(mem_addr),
        .mem_data_o(mem_wdata),
        .mem_wmask_o(mem_wmask),
        .mem_req_o(mem_req),
        .mem_we_o(mem_we),
        .mem_data_i(mem_rdata),
        .mem_ready_i(mem_ready),
        .busy_o(busy),
        .done_o(done),
        .error_o(error),
        .irq_o(irq)
    );

    task automatic axil_write;
        input[31:0] addr;
        input[31:0] data;
        begin
            @(posedge clk);
            awaddr <= addr;
            wdata <= data;
            wstrb <= 4'hf;
            awvalid <= 1'b1;
            wvalid <= 1'b1;
            bready <= 1'b1;
            while (!(awready && wready)) begin
                @(posedge clk);
            end
            @(posedge clk);
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            while (!bvalid) begin
                @(posedge clk);
            end
            if (bresp != 2'b00) begin
                $fatal(1, "AXIL write error addr=%08x bresp=%0d", addr, bresp);
            end
            @(posedge clk);
            bready <= 1'b0;
        end
    endtask

    task automatic axil_read;
        input[31:0] addr;
        output[31:0] data;
        begin
            @(posedge clk);
            araddr <= addr;
            arvalid <= 1'b1;
            rready <= 1'b1;
            while (!arready) begin
                @(posedge clk);
            end
            @(posedge clk);
            arvalid <= 1'b0;
            while (!rvalid) begin
                @(posedge clk);
            end
            data = rdata;
            if (rresp != 2'b00) begin
                $fatal(1, "AXIL read error addr=%08x rresp=%0d", addr, rresp);
            end
            @(posedge clk);
            rready <= 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        awaddr = 32'h0;
        awvalid = 1'b0;
        wdata = 32'h0;
        wstrb = 4'h0;
        wvalid = 1'b0;
        bready = 1'b0;
        araddr = 32'h0;
        arvalid = 1'b0;
        rready = 1'b0;
        done_seen = 1'b0;

        for (i = 0; i < 256; i = i + 1) begin
            mem[i] = 32'h0;
        end
        mem[16] = 32'h1111_0001;
        mem[17] = 32'h2222_0002;
        mem[18] = 32'h3333_0003;
        mem[19] = 32'h4444_0004;

        repeat (8) @(posedge clk);
        rst = `RstDisable;
        repeat (2) @(posedge clk);

        axil_write(DMA_SRC, 32'h0000_0040);
        axil_write(DMA_DST, 32'h0000_0080);
        axil_write(DMA_LEN, 32'd4);
        axil_write(DMA_CTRL, 32'h0000_0001);

        repeat (80) begin
            axil_read(DMA_STATUS, rd);
            if (rd[1]) begin
                done_seen = 1'b1;
            end
        end

        axil_read(DMA_STATUS, rd);
        if (!done_seen || !rd[1] || rd[3]) begin
            $fatal(1, "DMA did not complete cleanly: status=%08x", rd);
        end
        axil_read(DMA_COUNT, rd);
        if (rd != 32'd4) begin
            $fatal(1, "DMA count mismatch: count=%08x", rd);
        end
        if (mem[32] != 32'h1111_0001 || mem[33] != 32'h2222_0002 ||
            mem[34] != 32'h3333_0003 || mem[35] != 32'h4444_0004) begin
            $fatal(1, "DMA copy mismatch dst=%08x %08x %08x %08x",
                   mem[32], mem[33], mem[34], mem[35]);
        end

        $display("DMA_AXIL_WRAPPER_TB_PASS status=%08x count=%0d", rd, rd);
        $finish;
    end

endmodule
