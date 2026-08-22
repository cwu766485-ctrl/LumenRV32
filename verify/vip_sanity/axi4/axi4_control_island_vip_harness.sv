`timescale 1ns/1ps

// Standard single-port AXI4 VIP attachment point for the 0x2xxx_xxxx control
// aperture.  This is a control-path harness: issue single-beat accesses only
// (AWLEN/ARLEN=0).  The downstream DMA/NPU AXI-Lite ports are deliberately
// exposed so a slave VIP/BFM can return independently controlled responses.
module axi4_control_island_vip_harness (
    input wire clk, input wire rst,
    input wire [3:0] s_axi_awid, input wire [31:0] s_axi_awaddr, input wire [7:0] s_axi_awlen,
    input wire [2:0] s_axi_awsize, input wire [1:0] s_axi_awburst, input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb, input wire s_axi_wlast, input wire s_axi_wvalid, output wire s_axi_wready,
    output wire [3:0] s_axi_bid, output wire [1:0] s_axi_bresp, output wire s_axi_bvalid, input wire s_axi_bready,
    input wire [3:0] s_axi_arid, input wire [31:0] s_axi_araddr, input wire [7:0] s_axi_arlen,
    input wire [2:0] s_axi_arsize, input wire [1:0] s_axi_arburst, input wire s_axi_arvalid, output wire s_axi_arready,
    output wire [3:0] s_axi_rid, output wire [31:0] s_axi_rdata, output wire [1:0] s_axi_rresp,
    output wire s_axi_rlast, output wire s_axi_rvalid, input wire s_axi_rready,
    output wire [31:0] paddr, output wire psel, output wire penable, output wire pwrite,
    output wire [31:0] pwdata, output wire [3:0] pstrb, input wire [31:0] prdata, input wire pready, input wire pslverr,
    output wire [31:0] dma_axil_awaddr, output wire dma_axil_awvalid, input wire dma_axil_awready,
    output wire [31:0] dma_axil_wdata, output wire [3:0] dma_axil_wstrb, output wire dma_axil_wvalid, input wire dma_axil_wready,
    input wire [1:0] dma_axil_bresp, input wire dma_axil_bvalid, output wire dma_axil_bready,
    output wire [31:0] dma_axil_araddr, output wire dma_axil_arvalid, input wire dma_axil_arready,
    input wire [31:0] dma_axil_rdata, input wire [1:0] dma_axil_rresp, input wire dma_axil_rvalid, output wire dma_axil_rready,
    output wire [31:0] reserved_axil_awaddr, output wire reserved_axil_awvalid, input wire reserved_axil_awready,
    output wire [31:0] reserved_axil_wdata, output wire [3:0] reserved_axil_wstrb, output wire reserved_axil_wvalid, input wire reserved_axil_wready,
    input wire [1:0] reserved_axil_bresp, input wire reserved_axil_bvalid, output wire reserved_axil_bready,
    output wire [31:0] reserved_axil_araddr, output wire reserved_axil_arvalid, input wire reserved_axil_arready,
    input wire [31:0] reserved_axil_rdata, input wire [1:0] reserved_axil_rresp, input wire reserved_axil_rvalid, output wire reserved_axil_rready
);
    axi4_control_island u_dut (
        .clk(clk), .rst(rst),
        .s_axi_awid(s_axi_awid), .s_axi_awaddr(s_axi_awaddr), .s_axi_awlen(s_axi_awlen), .s_axi_awsize(s_axi_awsize), .s_axi_awburst(s_axi_awburst),
        .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready), .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bid(s_axi_bid), .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_arid(s_axi_arid), .s_axi_araddr(s_axi_araddr), .s_axi_arlen(s_axi_arlen), .s_axi_arsize(s_axi_arsize), .s_axi_arburst(s_axi_arburst),
        .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready), .s_axi_rid(s_axi_rid), .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp), .s_axi_rlast(s_axi_rlast), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .paddr_o(paddr), .psel_o(psel), .penable_o(penable), .pwrite_o(pwrite), .pwdata_o(pwdata), .pstrb_o(pstrb),
        .prdata_i(prdata), .pready_i(pready), .pslverr_i(pslverr),
        .dma_axil_awaddr(dma_axil_awaddr), .dma_axil_awvalid(dma_axil_awvalid), .dma_axil_awready(dma_axil_awready),
        .dma_axil_wdata(dma_axil_wdata), .dma_axil_wstrb(dma_axil_wstrb), .dma_axil_wvalid(dma_axil_wvalid), .dma_axil_wready(dma_axil_wready),
        .dma_axil_bresp(dma_axil_bresp), .dma_axil_bvalid(dma_axil_bvalid), .dma_axil_bready(dma_axil_bready),
        .dma_axil_araddr(dma_axil_araddr), .dma_axil_arvalid(dma_axil_arvalid), .dma_axil_arready(dma_axil_arready),
        .dma_axil_rdata(dma_axil_rdata), .dma_axil_rresp(dma_axil_rresp), .dma_axil_rvalid(dma_axil_rvalid), .dma_axil_rready(dma_axil_rready),
        .reserved_axil_awaddr(reserved_axil_awaddr), .reserved_axil_awvalid(reserved_axil_awvalid), .reserved_axil_awready(reserved_axil_awready),
        .reserved_axil_wdata(reserved_axil_wdata), .reserved_axil_wstrb(reserved_axil_wstrb), .reserved_axil_wvalid(reserved_axil_wvalid), .reserved_axil_wready(reserved_axil_wready),
        .reserved_axil_bresp(reserved_axil_bresp), .reserved_axil_bvalid(reserved_axil_bvalid), .reserved_axil_bready(reserved_axil_bready),
        .reserved_axil_araddr(reserved_axil_araddr), .reserved_axil_arvalid(reserved_axil_arvalid), .reserved_axil_arready(reserved_axil_arready),
        .reserved_axil_rdata(reserved_axil_rdata), .reserved_axil_rresp(reserved_axil_rresp), .reserved_axil_rvalid(reserved_axil_rvalid), .reserved_axil_rready(reserved_axil_rready)
    );
endmodule
