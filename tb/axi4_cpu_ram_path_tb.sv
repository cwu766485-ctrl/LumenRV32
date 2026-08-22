`timescale 1ns/1ps
`include "../rtl/core/defines.v"

// Regression for the real CPU data-side chain used by C startup code:
// native_to_axi4_master -> Stage B/C crossbar -> native RAM slave -> RAM.
// A write completion is mandatory before the next BSS-clear store can retire.
module axi4_cpu_ram_path_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst = `RstEnable;

    reg [31:0] native_addr, native_wdata;
    reg [3:0] native_wmask;
    reg native_req, native_we;
    wire [31:0] native_rdata;
    wire native_ready;

    wire [3:0] s_awid, s_arid, s_awvalid, s_wvalid, s_wlast, s_bready, s_arvalid, s_rready;
    wire [127:0] s_awaddr, s_wdata, s_araddr;
    wire [31:0] s_awlen, s_arlen;
    wire [11:0] s_awsize, s_arsize;
    wire [7:0] s_awburst, s_arburst;
    wire [15:0] s_wstrb;
    wire [3:0] s_awready, s_wready, s_bid, s_bvalid, s_arready, s_rid, s_rlast, s_rvalid;
    wire [7:0] s_bresp, s_rresp;
    wire [127:0] s_rdata;

    wire [15:0] m_awid, m_bid, m_arid, m_rid;
    wire [127:0] m_awaddr, m_wdata, m_araddr, m_rdata;
    wire [31:0] m_awlen, m_arlen;
    wire [11:0] m_awsize, m_arsize;
    wire [7:0] m_awburst, m_arburst;
    wire [15:0] m_wstrb;
    wire [3:0] m_awvalid, m_awready, m_wvalid, m_wready, m_wlast, m_bvalid, m_bready;
    wire [3:0] m_arvalid, m_arready, m_rvalid, m_rready, m_rlast;
    wire [7:0] m_bresp, m_rresp;

    wire [3:0] ram_awid, ram_bid, ram_arid, ram_rid;
    wire [31:0] ram_awaddr, ram_wdata, ram_araddr, ram_rdata;
    wire [7:0] ram_awlen, ram_arlen;
    wire [2:0] ram_awsize, ram_arsize;
    wire [1:0] ram_awburst, ram_arburst, ram_bresp, ram_rresp;
    wire [3:0] ram_wstrb;
    wire ram_awvalid, ram_awready, ram_wvalid, ram_wready, ram_wlast;
    wire ram_bvalid, ram_bready, ram_arvalid, ram_arready, ram_rvalid, ram_rready, ram_rlast;
    wire [31:0] ram_mem_addr, ram_mem_wdata, ram_mem_rdata;
    wire [3:0] ram_mem_wmask;
    wire ram_mem_req, ram_mem_we, ram_mem_ready;

    native_to_axi4_master u_cpu_data (
        .clk(clk), .rst(rst), .native_addr_i(native_addr), .native_wdata_i(native_wdata),
        .native_wmask_i(native_wmask), .native_req_i(native_req), .native_we_i(native_we),
        .native_burst_len_i(8'd0), .native_rdata_o(native_rdata), .native_ready_o(native_ready),
        .m_axi_awaddr(s_awaddr[31:0]), .m_axi_awlen(s_awlen[7:0]), .m_axi_awsize(s_awsize[2:0]),
        .m_axi_awburst(s_awburst[1:0]), .m_axi_awvalid(s_awvalid[0]), .m_axi_awready(s_awready[0]),
        .m_axi_wdata(s_wdata[31:0]), .m_axi_wstrb(s_wstrb[3:0]), .m_axi_wlast(s_wlast[0]),
        .m_axi_wvalid(s_wvalid[0]), .m_axi_wready(s_wready[0]), .m_axi_bresp(s_bresp[1:0]),
        .m_axi_bvalid(s_bvalid[0]), .m_axi_bready(s_bready[0]), .m_axi_araddr(s_araddr[31:0]),
        .m_axi_arlen(s_arlen[7:0]), .m_axi_arsize(s_arsize[2:0]), .m_axi_arburst(s_arburst[1:0]),
        .m_axi_arvalid(s_arvalid[0]), .m_axi_arready(s_arready[0]), .m_axi_rdata(s_rdata[31:0]),
        .m_axi_rresp(s_rresp[1:0]), .m_axi_rlast(s_rlast[0]), .m_axi_rvalid(s_rvalid[0]),
        .m_axi_rready(s_rready[0])
    );
    assign s_awid = 4'b0;
    assign s_arid = 4'b0;
    assign s_awaddr[127:32] = 96'b0; assign s_awlen[31:8] = 24'b0;
    assign s_awsize[11:3] = 9'b0; assign s_awburst[7:2] = 6'b0; assign s_awvalid[3:1] = 3'b0;
    assign s_wdata[127:32] = 96'b0; assign s_wstrb[7:4] = 4'b0; assign s_wlast[3:1] = 3'b0; assign s_wvalid[3:1] = 3'b0;
    assign s_bready[3:1] = 3'b0;
    assign s_araddr[127:32] = 96'b0; assign s_arlen[31:8] = 24'b0;
    assign s_arsize[11:3] = 9'b0; assign s_arburst[7:2] = 6'b0; assign s_arvalid[3:1] = 3'b0;
    assign s_rready[3:1] = 3'b0;

    axi4_crossbar u_xbar (
        .clk(clk), .rst(rst), .s_axi_awid(s_awid), .s_axi_awaddr(s_awaddr), .s_axi_awlen(s_awlen),
        .s_axi_awsize(s_awsize), .s_axi_awburst(s_awburst), .s_axi_awvalid(s_awvalid), .s_axi_awready(s_awready),
        .s_axi_wdata(s_wdata), .s_axi_wstrb(s_wstrb), .s_axi_wlast(s_wlast), .s_axi_wvalid(s_wvalid), .s_axi_wready(s_wready),
        .s_axi_bid(s_bid), .s_axi_bresp(s_bresp), .s_axi_bvalid(s_bvalid), .s_axi_bready(s_bready),
        .s_axi_arid(s_arid), .s_axi_araddr(s_araddr), .s_axi_arlen(s_arlen), .s_axi_arsize(s_arsize),
        .s_axi_arburst(s_arburst), .s_axi_arvalid(s_arvalid), .s_axi_arready(s_arready), .s_axi_rid(s_rid),
        .s_axi_rdata(s_rdata), .s_axi_rresp(s_rresp), .s_axi_rlast(s_rlast), .s_axi_rvalid(s_rvalid), .s_axi_rready(s_rready),
        .m_axi_awid(m_awid), .m_axi_awaddr(m_awaddr), .m_axi_awlen(m_awlen), .m_axi_awsize(m_awsize), .m_axi_awburst(m_awburst),
        .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready), .m_axi_wdata(m_wdata), .m_axi_wstrb(m_wstrb), .m_axi_wlast(m_wlast),
        .m_axi_wvalid(m_wvalid), .m_axi_wready(m_wready), .m_axi_bid(m_bid), .m_axi_bresp(m_bresp), .m_axi_bvalid(m_bvalid), .m_axi_bready(m_bready),
        .m_axi_arid(m_arid), .m_axi_araddr(m_araddr), .m_axi_arlen(m_arlen), .m_axi_arsize(m_arsize), .m_axi_arburst(m_arburst),
        .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready), .m_axi_rid(m_rid), .m_axi_rdata(m_rdata), .m_axi_rresp(m_rresp),
        .m_axi_rlast(m_rlast), .m_axi_rvalid(m_rvalid), .m_axi_rready(m_rready), .active_master_o(), .active_slave_o(), .busy_o()
    );
    assign m_awready = {2'b00, ram_awready, 1'b0}; assign m_wready = {2'b00, ram_wready, 1'b0};
    assign m_bid = {8'b0, ram_bid, 4'b0}; assign m_bresp = {4'b0, ram_bresp, 2'b0}; assign m_bvalid = {2'b00, ram_bvalid, 1'b0};
    assign m_arready = {2'b00, ram_arready, 1'b0}; assign m_rid = {8'b0, ram_rid, 4'b0};
    assign m_rdata = {64'b0, ram_rdata, 32'b0}; assign m_rresp = {4'b0, ram_rresp, 2'b0};
    assign m_rlast = {2'b00, ram_rlast, 1'b0}; assign m_rvalid = {2'b00, ram_rvalid, 1'b0};

    assign ram_awid=m_awid[7:4]; assign ram_awaddr=m_awaddr[63:32]; assign ram_awlen=m_awlen[15:8];
    assign ram_awsize=m_awsize[5:3]; assign ram_awburst=m_awburst[3:2]; assign ram_awvalid=m_awvalid[1];
    assign ram_wdata=m_wdata[63:32]; assign ram_wstrb=m_wstrb[7:4]; assign ram_wlast=m_wlast[1]; assign ram_wvalid=m_wvalid[1]; assign ram_bready=m_bready[1];
    assign ram_arid=m_arid[7:4]; assign ram_araddr=m_araddr[63:32]; assign ram_arlen=m_arlen[15:8];
    assign ram_arsize=m_arsize[5:3]; assign ram_arburst=m_arburst[3:2]; assign ram_arvalid=m_arvalid[1]; assign ram_rready=m_rready[1];
    axi4_to_native_slave u_ram_axi (
        .clk(clk), .rst(rst), .s_axi_awid(ram_awid), .s_axi_awaddr(ram_awaddr), .s_axi_awlen(ram_awlen), .s_axi_awsize(ram_awsize), .s_axi_awburst(ram_awburst), .s_axi_awvalid(ram_awvalid), .s_axi_awready(ram_awready),
        .s_axi_wdata(ram_wdata), .s_axi_wstrb(ram_wstrb), .s_axi_wlast(ram_wlast), .s_axi_wvalid(ram_wvalid), .s_axi_wready(ram_wready), .s_axi_bid(ram_bid), .s_axi_bresp(ram_bresp), .s_axi_bvalid(ram_bvalid), .s_axi_bready(ram_bready),
        .s_axi_arid(ram_arid), .s_axi_araddr(ram_araddr), .s_axi_arlen(ram_arlen), .s_axi_arsize(ram_arsize), .s_axi_arburst(ram_arburst), .s_axi_arvalid(ram_arvalid), .s_axi_arready(ram_arready), .s_axi_rid(ram_rid), .s_axi_rdata(ram_rdata), .s_axi_rresp(ram_rresp), .s_axi_rlast(ram_rlast), .s_axi_rvalid(ram_rvalid), .s_axi_rready(ram_rready),
        .mem_addr_o(ram_mem_addr), .mem_wdata_o(ram_mem_wdata), .mem_wmask_o(ram_mem_wmask), .mem_req_o(ram_mem_req), .mem_we_o(ram_mem_we), .mem_rdata_i(ram_mem_rdata), .mem_ready_i(ram_mem_ready)
    );
    ram #(.WAIT_CYCLES(0)) u_ram (.clk(clk), .rst(rst), .req_i(ram_mem_req), .we_i(ram_mem_we), .wmask_i(ram_mem_wmask), .addr_i(ram_mem_addr), .data_i(ram_mem_wdata), .data_o(ram_mem_rdata), .ready_o(ram_mem_ready));

    initial begin
        native_addr=0; native_wdata=0; native_wmask=0; native_req=0; native_we=0;
        repeat (4) @(posedge clk); rst=`RstDisable;
        @(negedge clk); native_addr=32'h1000_0000; native_wdata=32'h5a17_c0de; native_wmask=4'hf; native_we=1; native_req=1;
        wait(native_ready); @(negedge clk); native_req=0;
        repeat (2) @(posedge clk);
        @(negedge clk); native_we=0; native_req=1;
        wait(native_ready); if (native_rdata !== 32'h5a17_c0de) begin $display("AXI4_CPU_RAM_PATH_FAIL read=%08x", native_rdata); $finish(1); end
        $display("AXI4_CPU_RAM_PATH_PASS"); $finish;
    end
    initial begin #5000; $display("AXI4_CPU_RAM_PATH_TIMEOUT native_state=%0d bvalid=%b ram_bvalid=%b", u_cpu_data.state_r, s_bvalid, ram_bvalid); $finish(1); end
endmodule
