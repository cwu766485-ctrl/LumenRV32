`timescale 1ns/1ps

// APB master VIP attaches to paddr/pwdata/pwrite/psel/penable and observes
// prdata/pready/pslverr.  Serial VIPs may attach to the exported pins.
module apb_perips_vip_harness (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    input  wire [3:0]  pstrb,
    input  wire        pwrite,
    input  wire        psel,
    input  wire        penable,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,
    output wire        uart_tx,
    input  wire        uart_rx,
    input  wire        spi_miso,
    output wire        spi_mosi,
    output wire        spi_ss,
    output wire        spi_clk,
    inout  tri         i2c_scl,
    inout  tri         i2c_sda
);
    wire timer_int, dma_int, i2c_int;
    wire [31:0] dma_addr, dma_wdata;
    wire [3:0] dma_wmask;
    wire dma_req, dma_we;
    tri [1:0] gpio;
    tri [3:0] qspi_io;
    wire qspi_cs_n, qspi_clk;

    apb_perips u_dut (
        .clk(clk), .rst(rst), .paddr_i(paddr), .pwdata_i(pwdata), .prdata_o(prdata),
        .pstrb_i(pstrb), .pwrite_i(pwrite), .psel_i(psel), .penable_i(penable),
        .pready_o(pready), .pslverr_o(pslverr),
        .perf_inst_i(32'b0), .perf_hold_flag_i(3'b0), .perf_int_assert_i(1'b0), .perf_div_busy_i(1'b0),
        .perf_icache_hit_i(1'b0), .perf_icache_miss_i(1'b0), .perf_dcache_load_hit_i(1'b0), .perf_dcache_load_miss_i(1'b0),
        .perf_dcache_store_hit_i(1'b0), .perf_dcache_store_miss_i(1'b0), .perf_branch_redirect_i(1'b0), .perf_branch_flush_i(1'b0),
        .perf_prefetch_occupancy_i(3'b0), .perf_prefetch_full_i(1'b0), .perf_prefetch_stall_i(1'b0),
        .perf_branch_predict_hit_i(1'b0), .perf_branch_predict_miss_i(1'b0), .perf_dcache_load_miss_stall_i(1'b0),
        .perf_dcache_store_wait_i(1'b0), .perf_fetch_bus_wait_i(1'b0), .perf_data_bus_wait_i(1'b0), .perf_id_contention_i(1'b0),
        .perf_store_buffer_enqueue_i(1'b0), .perf_store_buffer_full_stall_i(1'b0), .perf_store_buffer_drain_i(1'b0),
        .timer_int_o(timer_int), .dma_int_o(dma_int), .i2c_int_o(i2c_int),
        .dma_addr_o(dma_addr), .dma_data_o(dma_wdata), .dma_wmask_o(dma_wmask), .dma_req_o(dma_req), .dma_we_o(dma_we),
        .dma_data_i(32'b0), .dma_ready_i(1'b1), .uart_tx_pin(uart_tx), .uart_rx_pin(uart_rx), .gpio(gpio),
        .spi_miso(spi_miso), .spi_mosi(spi_mosi), .spi_ss(spi_ss), .spi_clk(spi_clk),
        .qspi_io(qspi_io), .qspi_cs_n(qspi_cs_n), .qspi_clk(qspi_clk), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda)
    );
endmodule
