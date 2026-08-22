`timescale 1ns/1ps

// AXI-Lite master VIP drives the s_axi_* ports.  APB signals remain visible
// so an APB monitor/slave VIP can check the conversion transaction by transaction.
module axi_lite_to_apb_vip_harness (
    input wire clk, input wire rst,
    input wire [31:0] s_axi_awaddr, input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb, input wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0] s_axi_bresp, output wire s_axi_bvalid, input wire s_axi_bready,
    input wire [31:0] s_axi_araddr, input wire s_axi_arvalid, output wire s_axi_arready,
    output wire [31:0] s_axi_rdata, output wire [1:0] s_axi_rresp, output wire s_axi_rvalid, input wire s_axi_rready,
    output wire [31:0] paddr, output wire psel, output wire penable, output wire pwrite,
    output wire [31:0] pwdata, output wire [3:0] pstrb,
    input wire [31:0] prdata, input wire pready, input wire pslverr,
    input wire [3:0] wait_cycles
);
    axi_lite_apb_bridge u_dut (
        .clk(clk), .rst(rst), .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .paddr_o(paddr), .psel_o(psel), .penable_o(penable), .pwrite_o(pwrite), .pwdata_o(pwdata), .pstrb_o(pstrb),
        .prdata_i(prdata), .pready_i(pready), .pslverr_i(pslverr), .wait_cycles_i(wait_cycles)
    );
endmodule
