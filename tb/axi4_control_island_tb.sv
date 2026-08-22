`timescale 1 ns / 1 ps

`include "../rtl/core/defines.v"

module axi4_control_island_tb;
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

    wire[31:0] paddr;
    wire psel;
    wire penable;
    wire pwrite;
    wire[31:0] pwdata;
    wire[3:0] pstrb;
    reg[31:0] prdata;
    wire pready;
    wire pslverr;

    wire[31:0] dma_awaddr;
    wire dma_awvalid;
    reg dma_awready;
    wire[31:0] dma_wdata;
    wire[3:0] dma_wstrb;
    wire dma_wvalid;
    reg dma_wready;
    reg[1:0] dma_bresp;
    reg dma_bvalid;
    wire dma_bready;
    wire[31:0] dma_araddr;
    wire dma_arvalid;
    reg dma_arready;
    reg[31:0] dma_rdata;
    reg[1:0] dma_rresp;
    reg dma_rvalid;
    wire dma_rready;

    wire[31:0] reserved_awaddr;
    wire reserved_awvalid;
    reg reserved_awready;
    wire[31:0] reserved_wdata;
    wire[3:0] reserved_wstrb;
    wire reserved_wvalid;
    reg reserved_wready;
    reg[1:0] reserved_bresp;
    reg reserved_bvalid;
    wire reserved_bready;
    wire[31:0] reserved_araddr;
    wire reserved_arvalid;
    reg reserved_arready;
    reg[31:0] reserved_rdata;
    reg[1:0] reserved_rresp;
    reg reserved_rvalid;
    wire reserved_rready;

    integer apb_write_seen;
    integer dma_write_seen;
    integer reserved_write_seen;
    reg[31:0] rd;

    assign pready = 1'b1;
    assign pslverr = 1'b0;

    always #5 clk = ~clk;

    axi4_control_island u_dut(
        .clk(clk), .rst(rst),
        .s_axi_awaddr(awaddr), .s_axi_awlen(awlen), .s_axi_awsize(awsize), .s_axi_awburst(awburst),
        .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
        .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arlen(arlen), .s_axi_arsize(arsize), .s_axi_arburst(arburst),
        .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rlast(rlast),
        .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .paddr_o(paddr), .psel_o(psel), .penable_o(penable), .pwrite_o(pwrite),
        .pwdata_o(pwdata), .pstrb_o(pstrb), .prdata_i(prdata), .pready_i(pready), .pslverr_i(pslverr),
        .dma_axil_awaddr(dma_awaddr), .dma_axil_awvalid(dma_awvalid), .dma_axil_awready(dma_awready),
        .dma_axil_wdata(dma_wdata), .dma_axil_wstrb(dma_wstrb), .dma_axil_wvalid(dma_wvalid), .dma_axil_wready(dma_wready),
        .dma_axil_bresp(dma_bresp), .dma_axil_bvalid(dma_bvalid), .dma_axil_bready(dma_bready),
        .dma_axil_araddr(dma_araddr), .dma_axil_arvalid(dma_arvalid), .dma_axil_arready(dma_arready),
        .dma_axil_rdata(dma_rdata), .dma_axil_rresp(dma_rresp), .dma_axil_rvalid(dma_rvalid), .dma_axil_rready(dma_rready),
        .reserved_axil_awaddr(reserved_awaddr), .reserved_axil_awvalid(reserved_awvalid), .reserved_axil_awready(reserved_awready),
        .reserved_axil_wdata(reserved_wdata), .reserved_axil_wstrb(reserved_wstrb), .reserved_axil_wvalid(reserved_wvalid), .reserved_axil_wready(reserved_wready),
        .reserved_axil_bresp(reserved_bresp), .reserved_axil_bvalid(reserved_bvalid), .reserved_axil_bready(reserved_bready),
        .reserved_axil_araddr(reserved_araddr), .reserved_axil_arvalid(reserved_arvalid), .reserved_axil_arready(reserved_arready),
        .reserved_axil_rdata(reserved_rdata), .reserved_axil_rresp(reserved_rresp), .reserved_axil_rvalid(reserved_rvalid), .reserved_axil_rready(reserved_rready)
    );

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            dma_bvalid <= 1'b0;
            reserved_bvalid <= 1'b0;
            dma_rvalid <= 1'b0;
            reserved_rvalid <= 1'b0;
            apb_write_seen <= 0;
            dma_write_seen <= 0;
            reserved_write_seen <= 0;
        end else begin
            if (dma_awvalid && dma_awready && dma_wvalid && dma_wready) begin
                dma_write_seen <= dma_write_seen + 1;
                dma_bvalid <= 1'b1;
            end else if (dma_bvalid && dma_bready) begin
                dma_bvalid <= 1'b0;
            end
            if (reserved_awvalid && reserved_awready && reserved_wvalid && reserved_wready) begin
                reserved_write_seen <= reserved_write_seen + 1;
                reserved_bvalid <= 1'b1;
            end else if (reserved_bvalid && reserved_bready) begin
                reserved_bvalid <= 1'b0;
            end
            if (dma_arvalid && dma_arready) begin
                dma_rvalid <= 1'b1;
                dma_rdata <= 32'hd00d_5000;
            end else if (dma_rvalid && dma_rready) begin
                dma_rvalid <= 1'b0;
            end
            if (reserved_arvalid && reserved_arready) begin
                reserved_rvalid <= 1'b1;
                reserved_rdata <= 32'hcafe_6000;
            end else if (reserved_rvalid && reserved_rready) begin
                reserved_rvalid <= 1'b0;
            end
            if (psel && penable && pwrite) begin
                apb_write_seen <= apb_write_seen + 1;
            end
        end
    end

    task automatic axi_write;
        input[31:0] addr;
        input[31:0] data;
        integer timeout;
        begin
            @(posedge clk);
            awaddr <= addr;
            wdata <= data;
            awvalid <= 1'b1;
            wvalid <= 1'b1;
            bready <= 1'b0;
            timeout = 0;
            while (!(awready && wready) && timeout < 50) begin
                timeout = timeout + 1;
                @(posedge clk);
            end
            if (timeout >= 50) $fatal(1, "AXI write address/data timeout addr=%08x", addr);
            @(posedge clk);
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            timeout = 0;
            while (!bvalid && timeout < 80) begin
                timeout = timeout + 1;
                @(posedge clk);
            end
            if (timeout >= 80) $fatal(1, "AXI write response timeout addr=%08x", addr);
            bready <= 1'b1;
            @(posedge clk);
            bready <= 1'b0;
        end
    endtask

    task automatic axi_read;
        input[31:0] addr;
        output[31:0] data;
        integer timeout;
        begin
            @(posedge clk);
            araddr <= addr;
            arvalid <= 1'b1;
            rready <= 1'b0;
            timeout = 0;
            while (!arready && timeout < 50) begin
                timeout = timeout + 1;
                @(posedge clk);
            end
            if (timeout >= 50) $fatal(1, "AXI read address timeout addr=%08x", addr);
            @(posedge clk);
            arvalid <= 1'b0;
            timeout = 0;
            while (!rvalid && timeout < 80) begin
                timeout = timeout + 1;
                @(posedge clk);
            end
            if (timeout >= 80) $fatal(1, "AXI read response timeout addr=%08x", addr);
            data = rdata;
            rready <= 1'b1;
            @(posedge clk);
            rready <= 1'b0;
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
        wstrb = 4'hf;
        wlast = 1'b1;
        wvalid = 1'b0;
        bready = 1'b0;
        araddr = 32'h0;
        arlen = 8'h0;
        arsize = 3'd2;
        arburst = 2'b01;
        arvalid = 1'b0;
        rready = 1'b0;
        prdata = 32'ha5a5_0000;
        dma_awready = 1'b1;
        dma_wready = 1'b1;
        dma_bresp = 2'b00;
        dma_arready = 1'b1;
        dma_rresp = 2'b00;
        reserved_awready = 1'b1;
        reserved_wready = 1'b1;
        reserved_bresp = 2'b00;
        reserved_arready = 1'b1;
        reserved_rresp = 2'b00;

        repeat (5) @(posedge clk);
        rst = `RstDisable;

        axi_write(32'h2000_0000, 32'h1111_0000);
        axi_write(32'h2000_5008, 32'h2222_5008);
        axi_write(32'h2000_6008, 32'h3333_6008);
        axi_read(32'h2000_5014, rd);
        if (rd != 32'hd00d_5000) $fatal(1, "DMA read route failed: %08x", rd);
        axi_read(32'h2000_6004, rd);
        if (rd != 32'hcafe_6000) $fatal(1, "NPU read route failed: %08x", rd);

        if (apb_write_seen != 1 || dma_write_seen != 1 || reserved_write_seen != 1) begin
            $fatal(1, "route count mismatch apb=%0d dma=%0d npu=%0d",
                   apb_write_seen, dma_write_seen, reserved_write_seen);
        end

        $display("AXI4_CONTROL_ISLAND_TB_PASS apb=%0d dma=%0d reserved=%0d",
                 apb_write_seen, dma_write_seen, reserved_write_seen);
        $finish;
    end
endmodule
