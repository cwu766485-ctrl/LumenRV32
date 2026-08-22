`timescale 1 ns / 1 ps

`include "../core/defines.v"

// AXI4 control-window decoder.
//
// The SoC keeps the 0x2xxx_xxxx control aperture as one crossbar slave, but
// routes high-value accelerators directly to AXI4-Lite while low-speed
// peripherals continue through APB:
//   0x2000_5000 - 0x2000_5fff : DMA AXI4-Lite regs
//   0x2000_6000 - 0x2000_6fff : reserved accelerator AXI4-Lite regs
//   all other 0x2xxx_xxxx     : AXI4-to-APB bridge
module axi4_control_island(
    input wire clk,
    input wire rst,

    input wire[3:0] s_axi_awid, input wire[31:0] s_axi_awaddr, input wire[7:0] s_axi_awlen,
    input wire[2:0] s_axi_awsize, input wire[1:0] s_axi_awburst,
    input wire s_axi_awvalid, output wire s_axi_awready,
    input wire[31:0] s_axi_wdata, input wire[3:0] s_axi_wstrb,
    input wire s_axi_wlast, input wire s_axi_wvalid, output wire s_axi_wready,
    output wire[3:0] s_axi_bid, output wire[1:0] s_axi_bresp, output wire s_axi_bvalid, input wire s_axi_bready,
    input wire[3:0] s_axi_arid, input wire[31:0] s_axi_araddr, input wire[7:0] s_axi_arlen,
    input wire[2:0] s_axi_arsize, input wire[1:0] s_axi_arburst,
    input wire s_axi_arvalid, output wire s_axi_arready,
    output wire[3:0] s_axi_rid, output wire[31:0] s_axi_rdata, output wire[1:0] s_axi_rresp,
    output wire s_axi_rlast, output wire s_axi_rvalid, input wire s_axi_rready,

    output wire[31:0] paddr_o, output wire psel_o, output wire penable_o,
    output wire pwrite_o, output wire[31:0] pwdata_o, output wire[3:0] pstrb_o,
    input wire[31:0] prdata_i, input wire pready_i, input wire pslverr_i,

    output wire[31:0] dma_axil_awaddr, output wire dma_axil_awvalid, input wire dma_axil_awready,
    output wire[31:0] dma_axil_wdata, output wire[3:0] dma_axil_wstrb,
    output wire dma_axil_wvalid, input wire dma_axil_wready,
    input wire[1:0] dma_axil_bresp, input wire dma_axil_bvalid, output wire dma_axil_bready,
    output wire[31:0] dma_axil_araddr, output wire dma_axil_arvalid, input wire dma_axil_arready,
    input wire[31:0] dma_axil_rdata, input wire[1:0] dma_axil_rresp,
    input wire dma_axil_rvalid, output wire dma_axil_rready,

    output wire[31:0] reserved_axil_awaddr, output wire reserved_axil_awvalid, input wire reserved_axil_awready,
    output wire[31:0] reserved_axil_wdata, output wire[3:0] reserved_axil_wstrb,
    output wire reserved_axil_wvalid, input wire reserved_axil_wready,
    input wire[1:0] reserved_axil_bresp, input wire reserved_axil_bvalid, output wire reserved_axil_bready,
    output wire[31:0] reserved_axil_araddr, output wire reserved_axil_arvalid, input wire reserved_axil_arready,
    input wire[31:0] reserved_axil_rdata, input wire[1:0] reserved_axil_rresp,
    input wire reserved_axil_rvalid, output wire reserved_axil_rready
);

    wire write_dma = (s_axi_awaddr[15:12] == 4'h5);
    wire write_reserved = (s_axi_awaddr[15:12] == 4'h6);
    wire read_dma = (s_axi_araddr[15:12] == 4'h5);
    wire read_reserved = (s_axi_araddr[15:12] == 4'h6);
    wire write_apb = !write_dma && !write_reserved;
    wire read_apb = !read_dma && !read_reserved;
    localparam [1:0] ROUTE_APB = 2'd0;
    localparam [1:0] ROUTE_DMA = 2'd1;
    localparam [1:0] ROUTE_RESERVED = 2'd2;
    reg write_route_valid_r;
    reg[1:0] write_route_r;
    reg[3:0] write_id_r;
    reg read_route_valid_r;
    reg[1:0] read_route_r;
    reg[3:0] read_id_r;
    wire[1:0] write_route_now = write_dma ? ROUTE_DMA :
                                 write_reserved ? ROUTE_RESERVED :
                                 ROUTE_APB;
    wire[1:0] read_route_now = read_dma ? ROUTE_DMA :
                                read_reserved ? ROUTE_RESERVED :
                                ROUTE_APB;
    wire[1:0] write_route = write_route_valid_r ? write_route_r : write_route_now;
    wire[1:0] read_route = read_route_valid_r ? read_route_r : read_route_now;
    wire route_dma_w = (write_route == ROUTE_DMA);
    wire route_reserved_w = (write_route == ROUTE_RESERVED);
    wire route_apb_w = (write_route == ROUTE_APB);
    wire route_dma_r = (read_route == ROUTE_DMA);
    wire route_reserved_r = (read_route == ROUTE_RESERVED);
    wire route_apb_r = (read_route == ROUTE_APB);

    wire apb_awready;
    wire apb_wready;
    wire[1:0] apb_bresp;
    wire apb_bvalid;
    wire apb_arready;
    wire[31:0] apb_rdata;
    wire[1:0] apb_rresp;
    wire apb_rvalid;

    assign s_axi_awready = route_dma_w ? dma_axil_awready :
                           route_reserved_w ? reserved_axil_awready :
                           apb_awready;
    assign s_axi_wready = route_dma_w ? dma_axil_wready :
                          route_reserved_w ? reserved_axil_wready :
                          apb_wready;
    assign s_axi_bresp = route_dma_w ? dma_axil_bresp :
                         route_reserved_w ? reserved_axil_bresp :
                         apb_bresp;
    assign s_axi_bvalid = route_dma_w ? dma_axil_bvalid :
                          route_reserved_w ? reserved_axil_bvalid :
                          apb_bvalid;
    assign s_axi_bid = write_id_r;
    assign s_axi_arready = route_dma_r ? dma_axil_arready :
                           route_reserved_r ? reserved_axil_arready :
                           apb_arready;
    assign s_axi_rdata = route_dma_r ? dma_axil_rdata :
                         route_reserved_r ? reserved_axil_rdata :
                         apb_rdata;
    assign s_axi_rresp = route_dma_r ? dma_axil_rresp :
                         route_reserved_r ? reserved_axil_rresp :
                         apb_rresp;
    assign s_axi_rid = read_id_r;
    assign s_axi_rlast = s_axi_rvalid;
    assign s_axi_rvalid = route_dma_r ? dma_axil_rvalid :
                          route_reserved_r ? reserved_axil_rvalid :
                          apb_rvalid;

    // Sub-window slaves see local AXI4-Lite offsets.  The system-level
    // address remains 0x2000_5000/0x2000_6000 on the crossbar side, but the
    // DMA/reserved accelerator register banks decode from 0x0000_0000.
    assign dma_axil_awaddr = {20'd0, s_axi_awaddr[11:0]};
    assign dma_axil_awvalid = s_axi_awvalid && route_dma_w;
    assign dma_axil_wdata = s_axi_wdata;
    assign dma_axil_wstrb = s_axi_wstrb;
    assign dma_axil_wvalid = s_axi_wvalid && route_dma_w;
    assign dma_axil_bready = s_axi_bready && route_dma_w;
    assign dma_axil_araddr = {20'd0, s_axi_araddr[11:0]};
    assign dma_axil_arvalid = s_axi_arvalid && route_dma_r;
    assign dma_axil_rready = s_axi_rready && route_dma_r;

    assign reserved_axil_awaddr = {20'd0, s_axi_awaddr[11:0]};
    assign reserved_axil_awvalid = s_axi_awvalid && route_reserved_w;
    assign reserved_axil_wdata = s_axi_wdata;
    assign reserved_axil_wstrb = s_axi_wstrb;
    assign reserved_axil_wvalid = s_axi_wvalid && route_reserved_w;
    assign reserved_axil_bready = s_axi_bready && route_reserved_w;
    assign reserved_axil_araddr = {20'd0, s_axi_araddr[11:0]};
    assign reserved_axil_arvalid = s_axi_arvalid && route_reserved_r;
    assign reserved_axil_rready = s_axi_rready && route_reserved_r;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            write_route_valid_r <= 1'b0;
            write_route_r <= ROUTE_APB;
            write_id_r <= 4'b0;
            read_route_valid_r <= 1'b0;
            read_route_r <= ROUTE_APB;
            read_id_r <= 4'b0;
        end else begin
            if (!write_route_valid_r && s_axi_awvalid && s_axi_awready) begin
                write_route_valid_r <= 1'b1;
                write_route_r <= write_route_now;
                write_id_r <= s_axi_awid;
            end else if (write_route_valid_r && s_axi_bvalid && s_axi_bready) begin
                write_route_valid_r <= 1'b0;
            end

            if (!read_route_valid_r && s_axi_arvalid && s_axi_arready) begin
                read_route_valid_r <= 1'b1;
                read_route_r <= read_route_now;
                read_id_r <= s_axi_arid;
            end else if (read_route_valid_r && s_axi_rvalid && s_axi_rready) begin
                read_route_valid_r <= 1'b0;
            end
        end
    end

    axi4_to_apb_bridge u_apb_bridge(
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize), .s_axi_awburst(s_axi_awburst),
        .s_axi_awvalid(s_axi_awvalid && route_apb_w), .s_axi_awready(apb_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid && route_apb_w), .s_axi_wready(apb_wready),
        .s_axi_bresp(apb_bresp), .s_axi_bvalid(apb_bvalid), .s_axi_bready(s_axi_bready && route_apb_w),
        .s_axi_araddr(s_axi_araddr), .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize), .s_axi_arburst(s_axi_arburst),
        .s_axi_arvalid(s_axi_arvalid && route_apb_r), .s_axi_arready(apb_arready),
        .s_axi_rdata(apb_rdata), .s_axi_rresp(apb_rresp),
        .s_axi_rlast(), .s_axi_rvalid(apb_rvalid), .s_axi_rready(s_axi_rready && route_apb_r),
        .paddr_o(paddr_o), .psel_o(psel_o), .penable_o(penable_o),
        .pwrite_o(pwrite_o), .pwdata_o(pwdata_o), .pstrb_o(pstrb_o),
        .prdata_i(prdata_i), .pready_i(pready_i), .pslverr_i(pslverr_i)
    );

endmodule
