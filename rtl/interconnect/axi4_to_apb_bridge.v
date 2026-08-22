`timescale 1 ns / 1 ps

// AXI4 single-beat slave to APB bridge. AXI burst fields are accepted at the
// boundary; the current peripheral subsystem intentionally supports len=0.
module axi4_to_apb_bridge(
    input wire clk, input wire rst,
    input wire[31:0] s_axi_awaddr, input wire[7:0] s_axi_awlen,
    input wire[2:0] s_axi_awsize, input wire[1:0] s_axi_awburst,
    input wire s_axi_awvalid, output wire s_axi_awready,
    input wire[31:0] s_axi_wdata, input wire[3:0] s_axi_wstrb,
    input wire s_axi_wlast, input wire s_axi_wvalid, output wire s_axi_wready,
    output wire[1:0] s_axi_bresp, output wire s_axi_bvalid, input wire s_axi_bready,
    input wire[31:0] s_axi_araddr, input wire[7:0] s_axi_arlen,
    input wire[2:0] s_axi_arsize, input wire[1:0] s_axi_arburst,
    input wire s_axi_arvalid, output wire s_axi_arready,
    output wire[31:0] s_axi_rdata, output wire[1:0] s_axi_rresp,
    output wire s_axi_rlast, output wire s_axi_rvalid, input wire s_axi_rready,
    output wire[31:0] paddr_o, output wire psel_o, output wire penable_o,
    output wire pwrite_o, output wire[31:0] pwdata_o, output wire[3:0] pstrb_o,
    input wire[31:0] prdata_i, input wire pready_i, input wire pslverr_i
);
    assign s_axi_rlast = s_axi_rvalid;
    axi_lite_apb_bridge u_bridge(
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .paddr_o(paddr_o), .psel_o(psel_o), .penable_o(penable_o), .pwrite_o(pwrite_o),
        .pwdata_o(pwdata_o), .pstrb_o(pstrb_o), .prdata_i(prdata_i), .pready_i(pready_i),
        .pslverr_i(pslverr_i), .wait_cycles_i(4'h0)
    );
endmodule
