`timescale 1 ns / 1 ps

// ZU15EG board wrapper for the frozen heterogeneous SoC.
//
// The vendor-derived block design owns PS initialization, SmartConnect and
// the fully generated DDR4 MIG.  The SoC contributes one 32-bit AXI4 master;
// an AXI Clock Converter crosses 25->100 MHz, then SmartConnect performs the
// 32->256-bit width conversion and crossing into the MIG UI clock domain.
module zu15eg_heterogeneous_soc_ddr4_top (
    input  wire        ddr4_diff_clk_clk_n,
    input  wire        ddr4_diff_clk_clk_p,
    output wire        ddr4_rtl_0_act_n,
    output wire [16:0] ddr4_rtl_0_adr,
    output wire [1:0]  ddr4_rtl_0_ba,
    output wire [0:0]  ddr4_rtl_0_bg,
    output wire [0:0]  ddr4_rtl_0_ck_c,
    output wire [0:0]  ddr4_rtl_0_ck_t,
    output wire [0:0]  ddr4_rtl_0_cke,
    output wire [0:0]  ddr4_rtl_0_cs_n,
    inout  wire [3:0]  ddr4_rtl_0_dm_n,
    inout  wire [31:0] ddr4_rtl_0_dq,
    inout  wire [3:0]  ddr4_rtl_0_dqs_c,
    inout  wire [3:0]  ddr4_rtl_0_dqs_t,
    output wire [0:0]  ddr4_rtl_0_odt,
    output wire        ddr4_rtl_0_reset_n
);

    wire raw_soc_clk;
    wire soc_clk;
    wire ps_resetn;
    wire calib_done;
    reg [15:0] release_count;
    reg soc_resetn;

    wire soc_over;
    wire soc_succ;
    wire halted_ind;
    wire uart_tx_unused;
    wire [1:0] gpio_unused;
    wire spi_mosi_unused;
    wire spi_ss_unused;
    wire spi_clk_unused;
    wire [3:0] qspi_io_unused;
    wire qspi_cs_n_unused;
    wire qspi_clk_unused;

    wire [3:0]  axi_awid;
    wire [31:0] axi_awaddr;
    wire [7:0]  axi_awlen;
    wire [2:0]  axi_awsize;
    wire [1:0]  axi_awburst;
    wire        axi_awvalid;
    wire        axi_awready;
    wire [31:0] axi_wdata;
    wire [3:0]  axi_wstrb;
    wire        axi_wlast;
    wire        axi_wvalid;
    wire        axi_wready;
    wire [3:0]  axi_bid;
    wire [1:0]  axi_bresp;
    wire        axi_bvalid;
    wire        axi_bready;
    wire [3:0]  axi_arid;
    wire [31:0] axi_araddr;
    wire [7:0]  axi_arlen;
    wire [2:0]  axi_arsize;
    wire [1:0]  axi_arburst;
    wire        axi_arvalid;
    wire        axi_arready;
    wire [3:0]  axi_rid;
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;
    wire        axi_rlast;
    wire        axi_rvalid;
    wire        axi_rready;

    // The vendor FSBL leaves pl_clk0 at approximately 100 MHz.  Run the
    // LUT-heavy SoC at one quarter of that rate; the block design contains
    // an AXI Clock Converter between this domain and SmartConnect.
    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(4),
        .IS_CE_INVERTED(1'b0),
        .IS_CLR_INVERTED(1'b0)
    ) u_soc_clk_div (
        .I(raw_soc_clk),
        .CE(1'b1),
        .CLR(!ps_resetn),
        .O(soc_clk)
    );

    // Keep the SoC in reset until both PS PL-reset and MIG calibration are
    // released, then add a deterministic 65536-cycle settling interval.
    always @(posedge soc_clk) begin
        if (!ps_resetn || !calib_done) begin
            release_count <= 16'h0000;
            soc_resetn <= 1'b0;
        end else if (release_count != 16'hffff) begin
            release_count <= release_count + 1'b1;
            soc_resetn <= 1'b0;
        end else begin
            soc_resetn <= 1'b1;
        end
    end

    design_1_wrapper u_ddr4_bd (
        .SOC_AXI_araddr(axi_araddr),
        .SOC_AXI_arburst(axi_arburst),
        .SOC_AXI_arcache(4'b0000),
        .SOC_AXI_arid(axi_arid),
        .SOC_AXI_arlen(axi_arlen),
        .SOC_AXI_arlock(1'b0),
        .SOC_AXI_arprot(3'b000),
        .SOC_AXI_arqos(4'b0000),
        .SOC_AXI_arready(axi_arready),
        .SOC_AXI_arsize(axi_arsize),
        .SOC_AXI_arvalid(axi_arvalid),
        .SOC_AXI_awaddr(axi_awaddr),
        .SOC_AXI_awburst(axi_awburst),
        .SOC_AXI_awcache(4'b0000),
        .SOC_AXI_awid(axi_awid),
        .SOC_AXI_awlen(axi_awlen),
        .SOC_AXI_awlock(1'b0),
        .SOC_AXI_awprot(3'b000),
        .SOC_AXI_awqos(4'b0000),
        .SOC_AXI_awready(axi_awready),
        .SOC_AXI_awsize(axi_awsize),
        .SOC_AXI_awvalid(axi_awvalid),
        .SOC_AXI_bid(axi_bid),
        .SOC_AXI_bready(axi_bready),
        .SOC_AXI_bresp(axi_bresp),
        .SOC_AXI_bvalid(axi_bvalid),
        .SOC_AXI_rdata(axi_rdata),
        .SOC_AXI_rid(axi_rid),
        .SOC_AXI_rlast(axi_rlast),
        .SOC_AXI_rready(axi_rready),
        .SOC_AXI_rresp(axi_rresp),
        .SOC_AXI_rvalid(axi_rvalid),
        .SOC_AXI_wdata(axi_wdata),
        .SOC_AXI_wlast(axi_wlast),
        .SOC_AXI_wready(axi_wready),
        .SOC_AXI_wstrb(axi_wstrb),
        .SOC_AXI_wvalid(axi_wvalid),
        .calib_done(calib_done),
        .ddr4_diff_clk_clk_n(ddr4_diff_clk_clk_n),
        .ddr4_diff_clk_clk_p(ddr4_diff_clk_clk_p),
        .ddr4_rtl_0_act_n(ddr4_rtl_0_act_n),
        .ddr4_rtl_0_adr(ddr4_rtl_0_adr),
        .ddr4_rtl_0_ba(ddr4_rtl_0_ba),
        .ddr4_rtl_0_bg(ddr4_rtl_0_bg),
        .ddr4_rtl_0_ck_c(ddr4_rtl_0_ck_c),
        .ddr4_rtl_0_ck_t(ddr4_rtl_0_ck_t),
        .ddr4_rtl_0_cke(ddr4_rtl_0_cke),
        .ddr4_rtl_0_cs_n(ddr4_rtl_0_cs_n),
        .ddr4_rtl_0_dm_n(ddr4_rtl_0_dm_n),
        .ddr4_rtl_0_dq(ddr4_rtl_0_dq),
        .ddr4_rtl_0_dqs_c(ddr4_rtl_0_dqs_c),
        .ddr4_rtl_0_dqs_t(ddr4_rtl_0_dqs_t),
        .ddr4_rtl_0_odt(ddr4_rtl_0_odt),
        .ddr4_rtl_0_reset_n(ddr4_rtl_0_reset_n),
        .soc_axi_clk(soc_clk),
        .soc_clk(raw_soc_clk),
        .soc_over_i(soc_over),
        .soc_resetn(ps_resetn),
        .soc_succ_i(soc_succ)
    );

    heterogeneous_soc_top u_soc (
        .clk(soc_clk),
        .rst(soc_resetn),
        .over(soc_over),
        .succ(soc_succ),
        .halted_ind(halted_ind),
        .uart_debug_pin(1'b1),
        .uart_tx_pin(uart_tx_unused),
        .uart_rx_pin(1'b1),
        .gpio(gpio_unused),
        .jtag_TCK(1'b0),
        .jtag_TMS(1'b1),
        .jtag_TDI(1'b0),
        .jtag_TDO(),
        .spi_miso(1'b0),
        .spi_mosi(spi_mosi_unused),
        .spi_ss(spi_ss_unused),
        .spi_clk(spi_clk_unused),
        .qspi_io(qspi_io_unused),
        .qspi_cs_n(qspi_cs_n_unused),
        .qspi_clk(qspi_clk_unused),
        .extmem_axi_awid_o(axi_awid),
        .extmem_axi_awaddr_o(axi_awaddr),
        .extmem_axi_awlen_o(axi_awlen),
        .extmem_axi_awsize_o(axi_awsize),
        .extmem_axi_awburst_o(axi_awburst),
        .extmem_axi_awvalid_o(axi_awvalid),
        .extmem_axi_awready_i(axi_awready),
        .extmem_axi_wdata_o(axi_wdata),
        .extmem_axi_wstrb_o(axi_wstrb),
        .extmem_axi_wlast_o(axi_wlast),
        .extmem_axi_wvalid_o(axi_wvalid),
        .extmem_axi_wready_i(axi_wready),
        .extmem_axi_bid_i(axi_bid),
        .extmem_axi_bresp_i(axi_bresp),
        .extmem_axi_bvalid_i(axi_bvalid),
        .extmem_axi_bready_o(axi_bready),
        .extmem_axi_arid_o(axi_arid),
        .extmem_axi_araddr_o(axi_araddr),
        .extmem_axi_arlen_o(axi_arlen),
        .extmem_axi_arsize_o(axi_arsize),
        .extmem_axi_arburst_o(axi_arburst),
        .extmem_axi_arvalid_o(axi_arvalid),
        .extmem_axi_arready_i(axi_arready),
        .extmem_axi_rid_i(axi_rid),
        .extmem_axi_rdata_i(axi_rdata),
        .extmem_axi_rresp_i(axi_rresp),
        .extmem_axi_rlast_i(axi_rlast),
        .extmem_axi_rvalid_i(axi_rvalid),
        .extmem_axi_rready_o(axi_rready)
    );

endmodule
