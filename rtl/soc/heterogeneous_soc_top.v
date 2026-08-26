/*
Copyright 2020 Blue Liang, liangkangnan@163.com

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

`timescale 1 ns / 1 ps

`include "../core/defines.v"

`ifndef ExtMemDepthWords
`define ExtMemDepthWords 16384
`endif

// The public edition intentionally omits the unlicensed accelerator RTL.
// Keep the legacy control/master slot quiescent so the CPU/DMA SoC remains
// source-compatible with its existing memory-map and testbench boundary.
module heterogeneous_soc_top #(
    parameter USE_BSCAN_USER2 = 1'b0
)(

    input wire clk,
    input wire rst,

    output reg over,
    output reg succ,

    output wire halted_ind,

    input wire uart_debug_pin,

    output wire uart_tx_pin,
    input wire uart_rx_pin,
    inout wire[1:0] gpio,

    input wire jtag_TCK,
    input wire jtag_TMS,
    input wire jtag_TDI,
    output wire jtag_TDO,

    input wire spi_miso,
    output wire spi_mosi,
    output wire spi_ss,
    output wire spi_clk,
    inout wire[3:0] qspi_io,
    output wire qspi_cs_n,
    output wire qspi_clk
`ifdef SOC_I2C_EXTERNAL_PINS
    ,
    inout wire i2c_scl,
    inout wire i2c_sda
`endif
`ifdef SOC_EXTMEM_AXI_PORTS
    ,
    output wire[3:0] extmem_axi_awid_o,
    output wire[31:0] extmem_axi_awaddr_o,
    output wire[7:0] extmem_axi_awlen_o,
    output wire[2:0] extmem_axi_awsize_o,
    output wire[1:0] extmem_axi_awburst_o,
    output wire extmem_axi_awvalid_o,
    input wire extmem_axi_awready_i,
    output wire[31:0] extmem_axi_wdata_o,
    output wire[3:0] extmem_axi_wstrb_o,
    output wire extmem_axi_wlast_o,
    output wire extmem_axi_wvalid_o,
    input wire extmem_axi_wready_i,
    input wire[3:0] extmem_axi_bid_i,
    input wire[1:0] extmem_axi_bresp_i,
    input wire extmem_axi_bvalid_i,
    output wire extmem_axi_bready_o,
    output wire[3:0] extmem_axi_arid_o,
    output wire[31:0] extmem_axi_araddr_o,
    output wire[7:0] extmem_axi_arlen_o,
    output wire[2:0] extmem_axi_arsize_o,
    output wire[1:0] extmem_axi_arburst_o,
    output wire extmem_axi_arvalid_o,
    input wire extmem_axi_arready_i,
    input wire[3:0] extmem_axi_rid_i,
    input wire[31:0] extmem_axi_rdata_i,
    input wire[1:0] extmem_axi_rresp_i,
    input wire extmem_axi_rlast_i,
    input wire extmem_axi_rvalid_i,
    output wire extmem_axi_rready_o
`endif

    );

    // master 0 interface
    wire[`MemAddrBus] m0_addr_i;
    wire[`MemBus] m0_data_i;
    wire[`MemMaskBus] m0_wmask_i;
    wire[`MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;
    wire[7:0] m0_burst_len_i;
    wire m0_ready_o;

    // master 1 interface
    wire[`MemAddrBus] m1_addr_i;
    wire[`MemBus] m1_data_i;
    wire[`MemMaskBus] m1_wmask_i;
    wire[`MemBus] m1_data_o;
    wire m1_req_i;
    wire m1_we_i;
    wire[7:0] m1_burst_len_i;
    wire m1_ready_o;

    // master 2 interface
    wire[`MemAddrBus] m2_addr_i;
    wire[`MemBus] m2_data_i;
    wire[`MemMaskBus] m2_wmask_i;
    wire[`MemBus] m2_data_o;
    wire m2_req_i;
    wire m2_we_i;
    wire m2_ready_o;

    // master 3 interface
    wire[`MemAddrBus] m3_addr_i;
    wire[`MemBus] m3_data_i;
    wire[`MemMaskBus] m3_wmask_i;
    wire[`MemBus] m3_data_o;
    wire m3_req_i;
    wire m3_we_i;
    wire m3_ready_o;
    wire[`MemAddrBus] jtag_mem_addr;
    wire[`MemBus] jtag_mem_wdata;
    wire[`MemBus] jtag_mem_rdata;
    wire jtag_mem_req;
    wire jtag_mem_we;
`ifndef SOC_I2C_EXTERNAL_PINS
    // Keep the APB I2C controller available in generic and existing board
    // builds without introducing unconstrained package pins. Define
    // SOC_I2C_EXTERNAL_PINS only with verified board XDC pin assignments.
    tri i2c_scl;
    tri i2c_sda;
`endif

    wire[`MemAddrBus] dma_addr;
    wire[`MemBus] dma_wdata;
    wire[`MemMaskBus] dma_wmask;
    wire[`MemBus] dma_rdata;
    wire dma_req;
    wire dma_we;
    wire dma_ready;
    wire dma_int;
    wire apb_legacy_dma_int;
    wire[`MemAddrBus] apb_legacy_dma_addr;
    wire[`MemBus] apb_legacy_dma_wdata;
    wire[`MemMaskBus] apb_legacy_dma_wmask;
    wire[`MemBus] apb_legacy_dma_rdata;
    wire apb_legacy_dma_req;
    wire apb_legacy_dma_we;
    wire apb_legacy_dma_ready;
    wire[`MemAddrBus] uart_dbg_addr;
    wire[`MemBus] uart_dbg_wdata;
    wire[`MemBus] uart_dbg_rdata;
    wire uart_dbg_req;
    wire uart_dbg_we;

    // slave 0 interface
    wire[`MemAddrBus] s0_addr_o;
    wire[`MemBus] s0_data_o;
    wire[`MemMaskBus] s0_wmask_o;
    wire[`MemBus] s0_data_i;
    wire s0_req_o;
    wire s0_we_o;
    wire s0_ready_i;

    // slave 1 interface
    wire[`MemAddrBus] s1_addr_o;
    wire[`MemBus] s1_data_o;
    wire[`MemMaskBus] s1_wmask_o;
    wire[`MemBus] s1_data_i;
    wire s1_req_o;
    wire s1_we_o;
    wire s1_ready_i;

    // slave 2 interface
    wire[`MemAddrBus] s2_addr_o;
    wire[`MemBus] s2_data_o;
    wire[`MemMaskBus] s2_wmask_o;
    wire[`MemBus] s2_data_i;
    wire s2_req_o;
    wire s2_we_o;
    wire s2_ready_i;
    wire s2_sel_o;

    // slave 3-6 interface
    wire[`MemAddrBus] s3_addr_o;
    wire[`MemBus] s3_data_o;
    wire[`MemMaskBus] s3_wmask_o;
    wire[`MemBus] s3_data_i;
    wire s3_req_o;
    wire s3_we_o;
    wire s3_ready_i;
    wire mig_ui_clk;
    wire mig_ui_rst;
    wire mig_init_calib_complete;
    wire[27:0] mig_app_addr;
    wire[2:0] mig_app_cmd;
    wire mig_app_en;
    wire[127:0] mig_app_wdf_data;
    wire[15:0] mig_app_wdf_mask;
    wire mig_app_wdf_end;
    wire mig_app_wdf_wren;
    wire mig_app_rdy;
    wire mig_app_wdf_rdy;
    wire[127:0] mig_app_rd_data;
    wire mig_app_rd_data_valid;
    wire[3:0] ext_axi_awid;
    wire[31:0] ext_axi_awaddr;
    wire[7:0] ext_axi_awlen;
    wire[2:0] ext_axi_awsize;
    wire[1:0] ext_axi_awburst;
    wire ext_axi_awvalid;
    wire ext_axi_awready;
    wire[31:0] ext_axi_wdata;
    wire[3:0] ext_axi_wstrb;
    wire ext_axi_wlast;
    wire ext_axi_wvalid;
    wire ext_axi_wready;
    wire[3:0] ext_axi_bid;
    wire[1:0] ext_axi_bresp;
    wire ext_axi_bvalid;
    wire ext_axi_bready;
    wire[3:0] ext_axi_arid;
    wire[31:0] ext_axi_araddr;
    wire[7:0] ext_axi_arlen;
    wire[2:0] ext_axi_arsize;
    wire[1:0] ext_axi_arburst;
    wire ext_axi_arvalid;
    wire ext_axi_arready;
    wire[3:0] ext_axi_rid;
    wire[31:0] ext_axi_rdata;
    wire[1:0] ext_axi_rresp;
    wire ext_axi_rlast;
    wire ext_axi_rvalid;
    wire ext_axi_rready;

    wire[`MemAddrBus] s4_addr_o;
    wire[`MemBus] s4_data_o;
    wire[`MemMaskBus] s4_wmask_o;
    wire[`MemBus] s4_data_i;
    wire s4_req_o;
    wire s4_we_o;
    wire s4_ready_i;

    wire[`MemAddrBus] s5_addr_o;
    wire[`MemBus] s5_data_o;
    wire[`MemMaskBus] s5_wmask_o;
    wire[`MemBus] s5_data_i;
    wire s5_req_o;
    wire s5_we_o;
    wire s5_ready_i;

    wire[`MemAddrBus] s6_addr_o;
    wire[`MemBus] s6_data_o;
    wire[`MemMaskBus] s6_wmask_o;
    wire[`MemBus] s6_data_i;
    wire s6_req_o;
    wire s6_we_o;
    wire s6_ready_i;

    // AXI-Lite peripheral control bus
    wire[`MemAddrBus] axil_awaddr;
    wire axil_awvalid;
    wire axil_awready;
    wire[`MemBus] axil_wdata;
    wire[3:0] axil_wstrb;
    wire axil_wvalid;
    wire axil_wready;
    wire[1:0] axil_bresp;
    wire axil_bvalid;
    wire axil_bready;
    wire[`MemAddrBus] axil_araddr;
    wire axil_arvalid;
    wire axil_arready;
    wire[`MemBus] axil_rdata;
    wire[1:0] axil_rresp;
    wire axil_rvalid;
    wire axil_rready;

    wire[`MemAddrBus] dma_axil_awaddr;
    wire dma_axil_awvalid;
    wire dma_axil_awready;
    wire[`MemBus] dma_axil_wdata;
    wire[3:0] dma_axil_wstrb;
    wire dma_axil_wvalid;
    wire dma_axil_wready;
    wire[1:0] dma_axil_bresp;
    wire dma_axil_bvalid;
    wire dma_axil_bready;
    wire[`MemAddrBus] dma_axil_araddr;
    wire dma_axil_arvalid;
    wire dma_axil_arready;
    wire[`MemBus] dma_axil_rdata;
    wire[1:0] dma_axil_rresp;
    wire dma_axil_rvalid;
    wire dma_axil_rready;

    wire[`MemAddrBus] reserved_axil_awaddr;
    wire reserved_axil_awvalid;
    wire reserved_axil_awready;
    wire[`MemBus] reserved_axil_wdata;
    wire[3:0] reserved_axil_wstrb;
    wire reserved_axil_wvalid;
    wire reserved_axil_wready;
    wire[1:0] reserved_axil_bresp;
    wire reserved_axil_bvalid;
    wire reserved_axil_bready;
    wire[`MemAddrBus] reserved_axil_araddr;
    wire reserved_axil_arvalid;
    wire reserved_axil_arready;
    wire[`MemBus] reserved_axil_rdata;
    wire[1:0] reserved_axil_rresp;
    wire reserved_axil_rvalid;
    wire reserved_axil_rready;
    wire reserved_accel_irq;
    wire reserved_accel_axi_awid;
    wire[`MemAddrBus] reserved_accel_axi_awaddr;
    wire[7:0] reserved_accel_axi_awlen;
    wire[2:0] reserved_accel_axi_awsize;
    wire[1:0] reserved_accel_axi_awburst;
    wire reserved_accel_axi_awvalid;
    wire reserved_accel_axi_awready;
    wire[`MemBus] reserved_accel_axi_wdata;
    wire[`MemMaskBus] reserved_accel_axi_wstrb;
    wire reserved_accel_axi_wlast;
    wire reserved_accel_axi_wvalid;
    wire reserved_accel_axi_wready;
    wire reserved_accel_axi_bid;
    wire[1:0] reserved_accel_axi_bresp;
    wire reserved_accel_axi_bvalid;
    wire reserved_accel_axi_bready;
    wire reserved_accel_axi_arid;
    wire[`MemAddrBus] reserved_accel_axi_araddr;
    wire[7:0] reserved_accel_axi_arlen;
    wire[2:0] reserved_accel_axi_arsize;
    wire[1:0] reserved_accel_axi_arburst;
    wire reserved_accel_axi_arvalid;
    wire reserved_accel_axi_arready;
    wire reserved_accel_axi_rid;
    wire[`MemBus] reserved_accel_axi_rdata;
    wire[1:0] reserved_accel_axi_rresp;
    wire reserved_accel_axi_rlast;
    wire reserved_accel_axi_rvalid;
    wire reserved_accel_axi_rready;

    // APB peripheral bus
    wire[`MemAddrBus] apb_paddr;
    wire apb_psel;
    wire apb_penable;
    wire apb_pwrite;
    wire[`MemBus] apb_pwdata;
    wire[3:0] apb_pstrb;
    wire[`MemBus] apb_prdata;
    wire apb_pready;
    wire apb_pslverr;

    // AXI4 main interconnect
    wire[3:0] axi_awid;
    wire[127:0] axi_awaddr;
    wire[31:0] axi_awlen;
    wire[11:0] axi_awsize;
    wire[7:0] axi_awburst;
    wire[3:0] axi_awvalid;
    wire[3:0] axi_awready;
    wire[127:0] axi_wdata;
    wire[15:0] axi_wstrb;
    wire[3:0] axi_wlast;
    wire[3:0] axi_wvalid;
    wire[3:0] axi_wready;
    wire[3:0] axi_bid;
    wire[7:0] axi_bresp;
    wire[3:0] axi_bvalid;
    wire[3:0] axi_bready;
    wire[3:0] axi_arid;
    wire[127:0] axi_araddr;
    wire[31:0] axi_arlen;
    wire[11:0] axi_arsize;
    wire[7:0] axi_arburst;
    wire[3:0] axi_arvalid;
    wire[3:0] axi_arready;
    wire[3:0] axi_rid;
    wire[127:0] axi_rdata;
    wire[7:0] axi_rresp;
    wire[3:0] axi_rlast;
    wire[3:0] axi_rvalid;
    wire[3:0] axi_rready;
    wire[15:0] axi_slave_awid;
    wire[127:0] axi_slave_awaddr;
    wire[31:0] axi_slave_awlen;
    wire[11:0] axi_slave_awsize;
    wire[7:0] axi_slave_awburst;
    wire[3:0] axi_slave_awvalid;
    wire[3:0] axi_slave_awready;
    wire[127:0] axi_slave_wdata;
    wire[15:0] axi_slave_wstrb;
    wire[3:0] axi_slave_wlast;
    wire[3:0] axi_slave_wvalid;
    wire[3:0] axi_slave_wready;
    wire[15:0] axi_slave_bid;
    wire[7:0] axi_slave_bresp;
    wire[3:0] axi_slave_bvalid;
    wire[3:0] axi_slave_bready;
    wire[15:0] axi_slave_arid;
    wire[127:0] axi_slave_araddr;
    wire[31:0] axi_slave_arlen;
    wire[11:0] axi_slave_arsize;
    wire[7:0] axi_slave_arburst;
    wire[3:0] axi_slave_arvalid;
    wire[3:0] axi_slave_arready;
    wire[15:0] axi_slave_rid;
    wire[127:0] axi_slave_rdata;
    wire[7:0] axi_slave_rresp;
    wire[3:0] axi_slave_rlast;
    wire[3:0] axi_slave_rvalid;
    wire[3:0] axi_slave_rready;
    wire[1:0] axi_active_master;
    wire[1:0] axi_active_slave;
    wire axi_busy;

    // jtag
    wire jtag_halt_req_o;
    wire jtag_reset_req_o;
    wire bscan_jtag_halt_req_o;
    wire bscan_jtag_reset_req_o;
    // JTAG DM is a control-plane source.  Do not feed its raw request directly
    // into the CPU's combinational hold/flush network: debug memory reads use
    // the shared data path and otherwise create a JTAG -> frontend/cache ->
    // JTAG combinational feedback loop.  These registers deliberately add at
    // most one CPU clock of halt/reset latency and make the boundary synchronous.
    reg jtag_halt_req_r;
    reg jtag_reset_req_r;
    wire[`RegAddrBus] jtag_reg_addr_o;
    wire[`RegBus] jtag_reg_data_o;
    wire jtag_reg_we_o;
    wire[`RegBus] jtag_reg_data_i;
    wire[`RegAddrBus] bscan_jtag_reg_addr_o;
    wire[`RegBus] bscan_jtag_reg_data_o;
    wire bscan_jtag_reg_we_o;
    wire bscan_jtag_mem_we;
    wire[`MemAddrBus] bscan_jtag_mem_addr;
    wire[`MemBus] bscan_jtag_mem_wdata;
    wire bscan_jtag_mem_req;
    wire[`MemBus] bscan_jtag_mem_rdata;
    wire jtag_halt_req = USE_BSCAN_USER2 ? bscan_jtag_halt_req_o : jtag_halt_req_o;
    wire jtag_reset_req = USE_BSCAN_USER2 ? bscan_jtag_reset_req_o : jtag_reset_req_o;
    wire[`RegAddrBus] jtag_reg_addr = USE_BSCAN_USER2 ? bscan_jtag_reg_addr_o : jtag_reg_addr_o;
    wire[`RegBus] jtag_reg_data = USE_BSCAN_USER2 ? bscan_jtag_reg_data_o : jtag_reg_data_o;
    wire jtag_reg_we = USE_BSCAN_USER2 ? bscan_jtag_reg_we_o : jtag_reg_we_o;
    wire jtag_mem_we_selected = USE_BSCAN_USER2 ? bscan_jtag_mem_we : jtag_mem_we;
    wire[`MemAddrBus] jtag_mem_addr_selected = USE_BSCAN_USER2 ? bscan_jtag_mem_addr : jtag_mem_addr;
    wire[`MemBus] jtag_mem_wdata_selected = USE_BSCAN_USER2 ? bscan_jtag_mem_wdata : jtag_mem_wdata;
    wire jtag_mem_req_selected = USE_BSCAN_USER2 ? bscan_jtag_mem_req : jtag_mem_req;

    // RISC-V CPU core
    wire[`INT_BUS] int_flag;
    wire[`InstBus] perf_inst;
    wire[`Hold_Flag_Bus] perf_hold_flag;
    wire perf_int_assert;
    wire perf_div_busy;
    wire perf_icache_hit;
    wire perf_icache_miss;
    wire perf_dcache_load_hit;
    wire perf_dcache_load_miss;
    wire perf_dcache_store_hit;
    wire perf_dcache_store_miss;
    wire perf_branch_redirect;
    wire perf_branch_flush;
    wire[2:0] perf_prefetch_occupancy;
    wire perf_prefetch_full;
    wire perf_prefetch_stall;
    wire perf_branch_predict_hit;
    wire perf_branch_predict_miss;
    wire perf_dcache_load_miss_stall;
    wire perf_dcache_store_wait;
    wire perf_fetch_bus_wait;
    wire perf_data_bus_wait;
    wire perf_id_contention;
    wire perf_store_buffer_enqueue;
    wire perf_store_buffer_full_stall;
    wire perf_store_buffer_drain;

    // timer0
    wire timer0_int;
    wire i2c_int;

    assign int_flag = {4'h0, reserved_accel_irq, i2c_int, dma_int, timer0_int};
    assign axil_awaddr = axi_slave_awaddr[95:64];
    assign axil_awvalid = axi_slave_awvalid[2];
    assign axil_awready = axi_slave_awready[2];
    assign axil_wdata = axi_slave_wdata[95:64];
    assign axil_wstrb = axi_slave_wstrb[11:8];
    assign axil_wvalid = axi_slave_wvalid[2];
    assign axil_wready = axi_slave_wready[2];
    assign axil_bresp = axi_slave_bresp[5:4];
    assign axil_bvalid = axi_slave_bvalid[2];
    assign axil_bready = axi_slave_bready[2];
    assign axil_araddr = axi_slave_araddr[95:64];
    assign axil_arvalid = axi_slave_arvalid[2];
    assign axil_arready = axi_slave_arready[2];
    assign axil_rdata = axi_slave_rdata[95:64];
    assign axil_rresp = axi_slave_rresp[5:4];
    assign axil_rvalid = axi_slave_rvalid[2];
    assign axil_rready = axi_slave_rready[2];
    assign halted_ind = ~jtag_halt_req_r;
    assign m1_data_i = `ZeroWord;
    assign m1_wmask_i = 4'b1111;
    assign m1_we_i = `WriteDisable;
    assign m2_addr_i = (jtag_mem_req_selected == `True) ? jtag_mem_addr_selected : dma_addr;
    assign m2_data_i = (jtag_mem_req_selected == `True) ? jtag_mem_wdata_selected : dma_wdata;
    assign m2_wmask_i = (jtag_mem_req_selected == `True) ? 4'hf : dma_wmask;
    assign m2_req_i = (jtag_mem_req_selected == `True) ? jtag_mem_req_selected : dma_req;
    assign m2_we_i = (jtag_mem_req_selected == `True) ? jtag_mem_we_selected : dma_we;
    assign jtag_mem_rdata = m2_data_o;
    assign bscan_jtag_mem_rdata = m2_data_o;
    assign dma_rdata = m2_data_o;
    assign dma_ready = (jtag_mem_req_selected == `True) ? `False : m2_ready_o;
    assign apb_legacy_dma_rdata = `ZeroWord;
    assign apb_legacy_dma_ready = `True;
    assign m3_addr_i = uart_dbg_addr;
    assign m3_data_i = uart_dbg_wdata;
    assign m3_wmask_i = 4'hf;
    assign m3_req_i = uart_dbg_req;
    assign m3_we_i = uart_dbg_we;
    assign uart_dbg_rdata = m3_data_o;
    assign s4_data_i = `ZeroWord;
    assign s5_data_i = `ZeroWord;
    assign s6_data_i = `ZeroWord;
    assign s4_ready_i = `True;
    assign s5_ready_i = `True;
    assign s6_ready_i = `True;
    assign s2_sel_o = s2_req_o;
    assign perf_fetch_bus_wait = m1_req_i && !m1_ready_o;
    assign perf_data_bus_wait = m0_req_i && !m0_ready_o;
    assign mig_ui_clk = clk;
    assign mig_ui_rst = rst;
    assign mig_init_calib_complete = `False;
    assign mig_app_rdy = `False;
    assign mig_app_wdf_rdy = `False;
    assign mig_app_rd_data = 128'h0;
    assign mig_app_rd_data_valid = `False;
`ifdef SOC_EXTMEM_AXI_PORTS
    assign extmem_axi_awid_o = ext_axi_awid;
    assign extmem_axi_awaddr_o = ext_axi_awaddr;
    assign extmem_axi_awlen_o = ext_axi_awlen;
    assign extmem_axi_awsize_o = ext_axi_awsize;
    assign extmem_axi_awburst_o = ext_axi_awburst;
    assign extmem_axi_awvalid_o = ext_axi_awvalid;
    assign ext_axi_awready = extmem_axi_awready_i;
    assign extmem_axi_wdata_o = ext_axi_wdata;
    assign extmem_axi_wstrb_o = ext_axi_wstrb;
    assign extmem_axi_wlast_o = ext_axi_wlast;
    assign extmem_axi_wvalid_o = ext_axi_wvalid;
    assign ext_axi_wready = extmem_axi_wready_i;
    assign ext_axi_bid = extmem_axi_bid_i;
    assign ext_axi_bresp = extmem_axi_bresp_i;
    assign ext_axi_bvalid = extmem_axi_bvalid_i;
    assign extmem_axi_bready_o = ext_axi_bready;
    assign extmem_axi_arid_o = ext_axi_arid;
    assign extmem_axi_araddr_o = ext_axi_araddr;
    assign extmem_axi_arlen_o = ext_axi_arlen;
    assign extmem_axi_arsize_o = ext_axi_arsize;
    assign extmem_axi_arburst_o = ext_axi_arburst;
    assign extmem_axi_arvalid_o = ext_axi_arvalid;
    assign ext_axi_arready = extmem_axi_arready_i;
    assign ext_axi_rid = extmem_axi_rid_i;
    assign ext_axi_rdata = extmem_axi_rdata_i;
    assign ext_axi_rresp = extmem_axi_rresp_i;
    assign ext_axi_rlast = extmem_axi_rlast_i;
    assign ext_axi_rvalid = extmem_axi_rvalid_i;
    assign extmem_axi_rready_o = ext_axi_rready;
`endif

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
            jtag_halt_req_r <= 1'b0;
            jtag_reset_req_r <= 1'b0;
        end else begin
`ifdef ASIC_DC
            // DC's Verilog front-end rejects this legacy cross-module probe.
            // The profile remains observable through its dynamic JTAG ports.
            over <= 1'b1;
            succ <= 1'b1;
`else
            over <= ~u_riscv_cpu.u_regs.regs[26];
            succ <= ~u_riscv_cpu.u_regs.regs[27];
`endif
            jtag_halt_req_r <= jtag_halt_req;
            jtag_reset_req_r <= jtag_reset_req;
        end
    end

    riscv_cpu_core u_riscv_cpu(
        .clk(clk),
        .rst(rst),
        .mem_ex_addr_o(m0_addr_i),
        .mem_ex_data_i(m0_data_o),
        .mem_ex_data_o(m0_data_i),
        .mem_ex_wmask_o(m0_wmask_i),
        .mem_ex_req_o(m0_req_i),
        .mem_ex_we_o(m0_we_i),
        .mem_ex_burst_len_o(m0_burst_len_i),
        .mem_ex_ready_i(m0_ready_o),
        .mem_pc_addr_o(m1_addr_i),
        .mem_pc_data_i(m1_data_o),
        .mem_pc_req_o(m1_req_i),
        .mem_pc_burst_len_o(m1_burst_len_i),
        .mem_pc_ready_i(m1_ready_o),
        .jtag_reg_addr_i(jtag_reg_addr),
        .jtag_reg_data_i(jtag_reg_data),
        .jtag_reg_we_i(jtag_reg_we),
        .jtag_reg_data_o(jtag_reg_data_i),
        .jtag_halt_flag_i(jtag_halt_req_r),
        .jtag_reset_flag_i(jtag_reset_req_r),
        .int_i(int_flag),
        .perf_inst_o(perf_inst),
        .perf_hold_flag_o(perf_hold_flag),
        .perf_int_assert_o(perf_int_assert),
        .perf_div_busy_o(perf_div_busy),
        .perf_icache_hit_o(perf_icache_hit),
        .perf_icache_miss_o(perf_icache_miss),
        .perf_dcache_load_hit_o(perf_dcache_load_hit),
        .perf_dcache_load_miss_o(perf_dcache_load_miss),
        .perf_dcache_store_hit_o(perf_dcache_store_hit),
        .perf_dcache_store_miss_o(perf_dcache_store_miss),
        .perf_branch_redirect_o(perf_branch_redirect),
        .perf_branch_flush_o(perf_branch_flush),
        .perf_prefetch_occupancy_o(perf_prefetch_occupancy),
        .perf_prefetch_full_o(perf_prefetch_full),
        .perf_prefetch_stall_o(perf_prefetch_stall),
        .perf_branch_predict_hit_o(perf_branch_predict_hit),
        .perf_branch_predict_miss_o(perf_branch_predict_miss),
        .perf_dcache_load_miss_stall_o(perf_dcache_load_miss_stall),
        .perf_dcache_store_wait_o(perf_dcache_store_wait),
        .perf_id_contention_o(perf_id_contention),
        .perf_store_buffer_enqueue_o(perf_store_buffer_enqueue),
        .perf_store_buffer_full_stall_o(perf_store_buffer_full_stall),
        .perf_store_buffer_drain_o(perf_store_buffer_drain)
    );

    rom #(
        .WAIT_CYCLES(`RomWaitCycles)
    ) u_rom(
        .clk(clk),
        .rst(rst),
        .req_i(s0_req_o),
        .we_i(s0_we_o),
        .wmask_i(s0_wmask_o),
        .addr_i(s0_addr_o),
        .data_i(s0_data_o),
        .data_o(s0_data_i),
        .ready_o(s0_ready_i)
    );

    ram #(
        .WAIT_CYCLES(`RamWaitCycles)
    ) u_ram(
        .clk(clk),
        .rst(rst),
        .req_i(s1_req_o),
        .we_i(s1_we_o),
        .wmask_i(s1_wmask_o),
        .addr_i(s1_addr_o),
        .data_i(s1_data_o),
        .data_o(s1_data_i),
        .ready_o(s1_ready_i)
    );

    axi4_to_native_slave u_axi4_rom_slave(
        .clk(clk), .rst(rst),
        .s_axi_awid(axi_slave_awid[3:0]),
        .s_axi_awaddr(axi_slave_awaddr[31:0]), .s_axi_awlen(axi_slave_awlen[7:0]),
        .s_axi_awsize(axi_slave_awsize[2:0]), .s_axi_awburst(axi_slave_awburst[1:0]),
        .s_axi_awvalid(axi_slave_awvalid[0]), .s_axi_awready(axi_slave_awready[0]),
        .s_axi_wdata(axi_slave_wdata[31:0]), .s_axi_wstrb(axi_slave_wstrb[3:0]),
        .s_axi_wlast(axi_slave_wlast[0]), .s_axi_wvalid(axi_slave_wvalid[0]), .s_axi_wready(axi_slave_wready[0]),
        .s_axi_bid(axi_slave_bid[3:0]), .s_axi_bresp(axi_slave_bresp[1:0]), .s_axi_bvalid(axi_slave_bvalid[0]), .s_axi_bready(axi_slave_bready[0]),
        .s_axi_arid(axi_slave_arid[3:0]),
        .s_axi_araddr(axi_slave_araddr[31:0]), .s_axi_arlen(axi_slave_arlen[7:0]),
        .s_axi_arsize(axi_slave_arsize[2:0]), .s_axi_arburst(axi_slave_arburst[1:0]),
        .s_axi_arvalid(axi_slave_arvalid[0]), .s_axi_arready(axi_slave_arready[0]),
        .s_axi_rid(axi_slave_rid[3:0]), .s_axi_rdata(axi_slave_rdata[31:0]), .s_axi_rresp(axi_slave_rresp[1:0]),
        .s_axi_rlast(axi_slave_rlast[0]), .s_axi_rvalid(axi_slave_rvalid[0]), .s_axi_rready(axi_slave_rready[0]),
        .mem_addr_o(s0_addr_o), .mem_wdata_o(s0_data_o), .mem_wmask_o(s0_wmask_o),
        .mem_req_o(s0_req_o), .mem_we_o(s0_we_o), .mem_rdata_i(s0_data_i), .mem_ready_i(s0_ready_i)
    );

    axi4_to_native_slave u_axi4_ram_slave(
        .clk(clk), .rst(rst),
        .s_axi_awid(axi_slave_awid[7:4]),
        .s_axi_awaddr(axi_slave_awaddr[63:32]), .s_axi_awlen(axi_slave_awlen[15:8]),
        .s_axi_awsize(axi_slave_awsize[5:3]), .s_axi_awburst(axi_slave_awburst[3:2]),
        .s_axi_awvalid(axi_slave_awvalid[1]), .s_axi_awready(axi_slave_awready[1]),
        .s_axi_wdata(axi_slave_wdata[63:32]), .s_axi_wstrb(axi_slave_wstrb[7:4]),
        .s_axi_wlast(axi_slave_wlast[1]), .s_axi_wvalid(axi_slave_wvalid[1]), .s_axi_wready(axi_slave_wready[1]),
        .s_axi_bid(axi_slave_bid[7:4]), .s_axi_bresp(axi_slave_bresp[3:2]), .s_axi_bvalid(axi_slave_bvalid[1]), .s_axi_bready(axi_slave_bready[1]),
        .s_axi_arid(axi_slave_arid[7:4]),
        .s_axi_araddr(axi_slave_araddr[63:32]), .s_axi_arlen(axi_slave_arlen[15:8]),
        .s_axi_arsize(axi_slave_arsize[5:3]), .s_axi_arburst(axi_slave_arburst[3:2]),
        .s_axi_arvalid(axi_slave_arvalid[1]), .s_axi_arready(axi_slave_arready[1]),
        .s_axi_rid(axi_slave_rid[7:4]), .s_axi_rdata(axi_slave_rdata[63:32]), .s_axi_rresp(axi_slave_rresp[3:2]),
        .s_axi_rlast(axi_slave_rlast[1]), .s_axi_rvalid(axi_slave_rvalid[1]), .s_axi_rready(axi_slave_rready[1]),
        .mem_addr_o(s1_addr_o), .mem_wdata_o(s1_data_o), .mem_wmask_o(s1_wmask_o),
        .mem_req_o(s1_req_o), .mem_we_o(s1_we_o), .mem_rdata_i(s1_data_i), .mem_ready_i(s1_ready_i)
    );

    axi4_control_island u_axi4_control_island(
        .clk(clk), .rst(rst),
        .s_axi_awid(axi_slave_awid[11:8]),
        .s_axi_awaddr(axi_slave_awaddr[95:64]), .s_axi_awlen(axi_slave_awlen[23:16]),
        .s_axi_awsize(axi_slave_awsize[8:6]), .s_axi_awburst(axi_slave_awburst[5:4]),
        .s_axi_awvalid(axi_slave_awvalid[2]), .s_axi_awready(axi_slave_awready[2]),
        .s_axi_wdata(axi_slave_wdata[95:64]), .s_axi_wstrb(axi_slave_wstrb[11:8]),
        .s_axi_wlast(axi_slave_wlast[2]), .s_axi_wvalid(axi_slave_wvalid[2]), .s_axi_wready(axi_slave_wready[2]),
        .s_axi_bid(axi_slave_bid[11:8]), .s_axi_bresp(axi_slave_bresp[5:4]), .s_axi_bvalid(axi_slave_bvalid[2]), .s_axi_bready(axi_slave_bready[2]),
        .s_axi_arid(axi_slave_arid[11:8]),
        .s_axi_araddr(axi_slave_araddr[95:64]), .s_axi_arlen(axi_slave_arlen[23:16]),
        .s_axi_arsize(axi_slave_arsize[8:6]), .s_axi_arburst(axi_slave_arburst[5:4]),
        .s_axi_arvalid(axi_slave_arvalid[2]), .s_axi_arready(axi_slave_arready[2]),
        .s_axi_rid(axi_slave_rid[11:8]), .s_axi_rdata(axi_slave_rdata[95:64]), .s_axi_rresp(axi_slave_rresp[5:4]),
        .s_axi_rlast(axi_slave_rlast[2]), .s_axi_rvalid(axi_slave_rvalid[2]), .s_axi_rready(axi_slave_rready[2]),
        .paddr_o(apb_paddr),
        .psel_o(apb_psel),
        .penable_o(apb_penable),
        .pwrite_o(apb_pwrite),
        .pwdata_o(apb_pwdata),
        .pstrb_o(apb_pstrb),
        .prdata_i(apb_prdata),
        .pready_i(apb_pready),
        .pslverr_i(apb_pslverr),
        .dma_axil_awaddr(dma_axil_awaddr),
        .dma_axil_awvalid(dma_axil_awvalid),
        .dma_axil_awready(dma_axil_awready),
        .dma_axil_wdata(dma_axil_wdata),
        .dma_axil_wstrb(dma_axil_wstrb),
        .dma_axil_wvalid(dma_axil_wvalid),
        .dma_axil_wready(dma_axil_wready),
        .dma_axil_bresp(dma_axil_bresp),
        .dma_axil_bvalid(dma_axil_bvalid),
        .dma_axil_bready(dma_axil_bready),
        .dma_axil_araddr(dma_axil_araddr),
        .dma_axil_arvalid(dma_axil_arvalid),
        .dma_axil_arready(dma_axil_arready),
        .dma_axil_rdata(dma_axil_rdata),
        .dma_axil_rresp(dma_axil_rresp),
        .dma_axil_rvalid(dma_axil_rvalid),
        .dma_axil_rready(dma_axil_rready),
        .reserved_axil_awaddr(reserved_axil_awaddr),
        .reserved_axil_awvalid(reserved_axil_awvalid),
        .reserved_axil_awready(reserved_axil_awready),
        .reserved_axil_wdata(reserved_axil_wdata),
        .reserved_axil_wstrb(reserved_axil_wstrb),
        .reserved_axil_wvalid(reserved_axil_wvalid),
        .reserved_axil_wready(reserved_axil_wready),
        .reserved_axil_bresp(reserved_axil_bresp),
        .reserved_axil_bvalid(reserved_axil_bvalid),
        .reserved_axil_bready(reserved_axil_bready),
        .reserved_axil_araddr(reserved_axil_araddr),
        .reserved_axil_arvalid(reserved_axil_arvalid),
        .reserved_axil_arready(reserved_axil_arready),
        .reserved_axil_rdata(reserved_axil_rdata),
        .reserved_axil_rresp(reserved_axil_rresp),
        .reserved_axil_rvalid(reserved_axil_rvalid),
        .reserved_axil_rready(reserved_axil_rready)
    );

`ifndef SOC_CPU_AXI_DEBUG_PROFILE
    dma_axil_wrapper u_dma_axil_wrapper(
        .clk(clk),
        .rst(rst),
        .s_axi_awaddr(dma_axil_awaddr),
        .s_axi_awvalid(dma_axil_awvalid),
        .s_axi_awready(dma_axil_awready),
        .s_axi_wdata(dma_axil_wdata),
        .s_axi_wstrb(dma_axil_wstrb),
        .s_axi_wvalid(dma_axil_wvalid),
        .s_axi_wready(dma_axil_wready),
        .s_axi_bresp(dma_axil_bresp),
        .s_axi_bvalid(dma_axil_bvalid),
        .s_axi_bready(dma_axil_bready),
        .s_axi_araddr(dma_axil_araddr),
        .s_axi_arvalid(dma_axil_arvalid),
        .s_axi_arready(dma_axil_arready),
        .s_axi_rdata(dma_axil_rdata),
        .s_axi_rresp(dma_axil_rresp),
        .s_axi_rvalid(dma_axil_rvalid),
        .s_axi_rready(dma_axil_rready),
        .mem_addr_o(dma_addr),
        .mem_data_o(dma_wdata),
        .mem_wmask_o(dma_wmask),
        .mem_req_o(dma_req),
        .mem_we_o(dma_we),
        .mem_data_i(dma_rdata),
        .mem_ready_i(dma_ready),
        .busy_o(),
        .done_o(),
        .error_o(),
        .irq_o(dma_int)
    );
`else
    // Keep the control-island ABI deterministic while removing the DMA
    // datapath from the focused CPU/AXI/PMU/JTAG synthesis profile.
    assign dma_axil_awready = 1'b1;
    assign dma_axil_wready  = 1'b1;
    assign dma_axil_bresp   = 2'b00;
    assign dma_axil_bvalid  = 1'b0;
    assign dma_axil_arready = 1'b1;
    assign dma_axil_rdata   = `ZeroWord;
    assign dma_axil_rresp   = 2'b00;
    assign dma_axil_rvalid  = 1'b0;
    assign dma_addr = `ZeroWord;
    assign dma_wdata = `ZeroWord;
    assign dma_wmask = 4'b0000;
    assign dma_req = 1'b0;
    assign dma_we = 1'b0;
    assign dma_int = 1'b0;
`endif

    // The reserved accelerator control window and AXI4 master slot are tied
    // off in this public CPU/DMA edition.
    // Public CPU/DMA edition: reserve the fourth crossbar slot without attaching an accelerator.
    assign reserved_axil_awready = 1'b1;
    assign reserved_axil_wready  = 1'b1;
    assign reserved_axil_bresp   = 2'b00;
    assign reserved_axil_bvalid  = 1'b0;
    assign reserved_axil_arready = 1'b1;
    assign reserved_axil_rdata   = `ZeroWord;
    assign reserved_axil_rresp   = 2'b00;
    assign reserved_axil_rvalid  = 1'b0;
    assign reserved_accel_irq = 1'b0;
    assign reserved_accel_axi_awid = 1'b0;
    assign reserved_accel_axi_awaddr = `ZeroWord;
    assign reserved_accel_axi_awlen = 8'h00;
    assign reserved_accel_axi_awsize = 3'b010;
    assign reserved_accel_axi_awburst = 2'b01;
    assign reserved_accel_axi_awvalid = 1'b0;
    assign reserved_accel_axi_wdata = `ZeroWord;
    assign reserved_accel_axi_wstrb = 4'h0;
    assign reserved_accel_axi_wlast = 1'b0;
    assign reserved_accel_axi_wvalid = 1'b0;
    assign reserved_accel_axi_bready = 1'b1;
    assign reserved_accel_axi_arid = 1'b0;
    assign reserved_accel_axi_araddr = `ZeroWord;
    assign reserved_accel_axi_arlen = 8'h00;
    assign reserved_accel_axi_arsize = 3'b010;
    assign reserved_accel_axi_arburst = 2'b01;
    assign reserved_accel_axi_arvalid = 1'b0;
    assign reserved_accel_axi_rready = 1'b1;

    apb_perips u_apb_perips(
        .clk(clk),
        .rst(rst),
        .paddr_i(apb_paddr),
        .pwdata_i(apb_pwdata),
        .prdata_o(apb_prdata),
        .pstrb_i(apb_pstrb),
        .pwrite_i(apb_pwrite),
        .psel_i(apb_psel),
        .penable_i(apb_penable),
        .pready_o(apb_pready),
        .pslverr_o(apb_pslverr),
        .perf_inst_i(perf_inst),
        .perf_hold_flag_i(perf_hold_flag),
        .perf_int_assert_i(perf_int_assert),
        .perf_div_busy_i(perf_div_busy),
        .perf_icache_hit_i(perf_icache_hit),
        .perf_icache_miss_i(perf_icache_miss),
        .perf_dcache_load_hit_i(perf_dcache_load_hit),
        .perf_dcache_load_miss_i(perf_dcache_load_miss),
        .perf_dcache_store_hit_i(perf_dcache_store_hit),
        .perf_dcache_store_miss_i(perf_dcache_store_miss),
        .perf_branch_redirect_i(perf_branch_redirect),
        .perf_branch_flush_i(perf_branch_flush),
        .perf_prefetch_occupancy_i(perf_prefetch_occupancy),
        .perf_prefetch_full_i(perf_prefetch_full),
        .perf_prefetch_stall_i(perf_prefetch_stall),
        .perf_branch_predict_hit_i(perf_branch_predict_hit),
        .perf_branch_predict_miss_i(perf_branch_predict_miss),
        .perf_dcache_load_miss_stall_i(perf_dcache_load_miss_stall),
        .perf_dcache_store_wait_i(perf_dcache_store_wait),
        .perf_fetch_bus_wait_i(perf_fetch_bus_wait),
        .perf_data_bus_wait_i(perf_data_bus_wait),
        .perf_id_contention_i(perf_id_contention),
        .perf_store_buffer_enqueue_i(perf_store_buffer_enqueue),
        .perf_store_buffer_full_stall_i(perf_store_buffer_full_stall),
        .perf_store_buffer_drain_i(perf_store_buffer_drain),
        .timer_int_o(timer0_int),
        .dma_int_o(apb_legacy_dma_int),
        .i2c_int_o(i2c_int),
        .dma_addr_o(apb_legacy_dma_addr),
        .dma_data_o(apb_legacy_dma_wdata),
        .dma_wmask_o(apb_legacy_dma_wmask),
        .dma_req_o(apb_legacy_dma_req),
        .dma_we_o(apb_legacy_dma_we),
        .dma_data_i(apb_legacy_dma_rdata),
        .dma_ready_i(apb_legacy_dma_ready),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .gpio(gpio),
        .spi_miso(spi_miso),
        .spi_mosi(spi_mosi),
        .spi_ss(spi_ss),
        .spi_clk(spi_clk),
        .qspi_io(qspi_io),
        .qspi_cs_n(qspi_cs_n),
        .qspi_clk(qspi_clk),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    assign ext_axi_awid = axi_slave_awid[15:12];
    assign ext_axi_awaddr = axi_slave_awaddr[127:96];
    assign ext_axi_awlen = axi_slave_awlen[31:24];
    assign ext_axi_awsize = axi_slave_awsize[11:9];
    assign ext_axi_awburst = axi_slave_awburst[7:6];
    assign ext_axi_awvalid = axi_slave_awvalid[3];
    assign axi_slave_awready[3] = ext_axi_awready;
    assign ext_axi_wdata = axi_slave_wdata[127:96];
    assign ext_axi_wstrb = axi_slave_wstrb[15:12];
    assign ext_axi_wlast = axi_slave_wlast[3];
    assign ext_axi_wvalid = axi_slave_wvalid[3];
    assign axi_slave_wready[3] = ext_axi_wready;
    assign axi_slave_bid[15:12] = ext_axi_bid;
    assign axi_slave_bresp[7:6] = ext_axi_bresp;
    assign axi_slave_bvalid[3] = ext_axi_bvalid;
    assign ext_axi_bready = axi_slave_bready[3];
    assign ext_axi_arid = axi_slave_arid[15:12];
    assign ext_axi_araddr = axi_slave_araddr[127:96];
    assign ext_axi_arlen = axi_slave_arlen[31:24];
    assign ext_axi_arsize = axi_slave_arsize[11:9];
    assign ext_axi_arburst = axi_slave_arburst[7:6];
    assign ext_axi_arvalid = axi_slave_arvalid[3];
    assign axi_slave_arready[3] = ext_axi_arready;
    assign axi_slave_rid[15:12] = ext_axi_rid;
    assign axi_slave_rdata[127:96] = ext_axi_rdata;
    assign axi_slave_rresp[7:6] = ext_axi_rresp;
    assign axi_slave_rlast[3] = ext_axi_rlast;
    assign axi_slave_rvalid[3] = ext_axi_rvalid;
    assign ext_axi_rready = axi_slave_rready[3];

`ifndef SOC_EXTMEM_AXI_PORTS
    axi4_mem_model #(
        .DEPTH_WORDS(`ExtMemDepthWords),
        .WAIT_CYCLES(6)
    ) u_axi4_mem_model(
        .clk(clk),
        .rst(rst),
        .s_axi_awid(ext_axi_awid),
        .s_axi_awaddr(ext_axi_awaddr),
        .s_axi_awlen(ext_axi_awlen),
        .s_axi_awsize(ext_axi_awsize),
        .s_axi_awburst(ext_axi_awburst),
        .s_axi_awvalid(ext_axi_awvalid),
        .s_axi_awready(ext_axi_awready),
        .s_axi_wdata(ext_axi_wdata),
        .s_axi_wstrb(ext_axi_wstrb),
        .s_axi_wlast(ext_axi_wlast),
        .s_axi_wvalid(ext_axi_wvalid),
        .s_axi_wready(ext_axi_wready),
        .s_axi_bid(ext_axi_bid),
        .s_axi_bresp(ext_axi_bresp),
        .s_axi_bvalid(ext_axi_bvalid),
        .s_axi_bready(ext_axi_bready),
        .s_axi_arid(ext_axi_arid),
        .s_axi_araddr(ext_axi_araddr),
        .s_axi_arlen(ext_axi_arlen),
        .s_axi_arsize(ext_axi_arsize),
        .s_axi_arburst(ext_axi_arburst),
        .s_axi_arvalid(ext_axi_arvalid),
        .s_axi_arready(ext_axi_arready),
        .s_axi_rid(ext_axi_rid),
        .s_axi_rdata(ext_axi_rdata),
        .s_axi_rresp(ext_axi_rresp),
        .s_axi_rlast(ext_axi_rlast),
        .s_axi_rvalid(ext_axi_rvalid),
        .s_axi_rready(ext_axi_rready)
    );
`endif

    native_to_axi4_master u_cpu_data_axi_master(
        .clk(clk),
        .rst(rst),
        .native_addr_i(m0_addr_i), .native_wdata_i(m0_data_i), .native_wmask_i(m0_wmask_i),
        .native_req_i(m0_req_i), .native_we_i(m0_we_i), .native_rdata_o(m0_data_o), .native_ready_o(m0_ready_o),
        .native_burst_len_i(m0_burst_len_i),
        .m_axi_awaddr(axi_awaddr[31:0]), .m_axi_awlen(axi_awlen[7:0]), .m_axi_awsize(axi_awsize[2:0]),
        .m_axi_awburst(axi_awburst[1:0]), .m_axi_awvalid(axi_awvalid[0]), .m_axi_awready(axi_awready[0]),
        .m_axi_wdata(axi_wdata[31:0]), .m_axi_wstrb(axi_wstrb[3:0]), .m_axi_wlast(axi_wlast[0]),
        .m_axi_wvalid(axi_wvalid[0]), .m_axi_wready(axi_wready[0]), .m_axi_bresp(axi_bresp[1:0]),
        .m_axi_bvalid(axi_bvalid[0]), .m_axi_bready(axi_bready[0]), .m_axi_araddr(axi_araddr[31:0]),
        .m_axi_arlen(axi_arlen[7:0]), .m_axi_arsize(axi_arsize[2:0]), .m_axi_arburst(axi_arburst[1:0]),
        .m_axi_arvalid(axi_arvalid[0]), .m_axi_arready(axi_arready[0]), .m_axi_rdata(axi_rdata[31:0]),
        .m_axi_rresp(axi_rresp[1:0]), .m_axi_rlast(axi_rlast[0]), .m_axi_rvalid(axi_rvalid[0]),
        .m_axi_rready(axi_rready[0])
    );
    assign axi_awid[0] = 1'b0;
    assign axi_arid[0] = 1'b0;

    native_to_axi4_master u_cpu_instruction_axi_master(
        .clk(clk), .rst(rst),
        .native_addr_i(m1_addr_i), .native_wdata_i(m1_data_i), .native_wmask_i(m1_wmask_i),
        .native_req_i(m1_req_i), .native_we_i(m1_we_i), .native_rdata_o(m1_data_o), .native_ready_o(m1_ready_o),
        .native_burst_len_i(m1_burst_len_i),
        .m_axi_awaddr(axi_awaddr[63:32]), .m_axi_awlen(axi_awlen[15:8]), .m_axi_awsize(axi_awsize[5:3]),
        .m_axi_awburst(axi_awburst[3:2]), .m_axi_awvalid(axi_awvalid[1]), .m_axi_awready(axi_awready[1]),
        .m_axi_wdata(axi_wdata[63:32]), .m_axi_wstrb(axi_wstrb[7:4]), .m_axi_wlast(axi_wlast[1]),
        .m_axi_wvalid(axi_wvalid[1]), .m_axi_wready(axi_wready[1]), .m_axi_bresp(axi_bresp[3:2]),
        .m_axi_bvalid(axi_bvalid[1]), .m_axi_bready(axi_bready[1]), .m_axi_araddr(axi_araddr[63:32]),
        .m_axi_arlen(axi_arlen[15:8]), .m_axi_arsize(axi_arsize[5:3]), .m_axi_arburst(axi_arburst[3:2]),
        .m_axi_arvalid(axi_arvalid[1]), .m_axi_arready(axi_arready[1]), .m_axi_rdata(axi_rdata[63:32]),
        .m_axi_rresp(axi_rresp[3:2]), .m_axi_rlast(axi_rlast[1]), .m_axi_rvalid(axi_rvalid[1]),
        .m_axi_rready(axi_rready[1])
    );
    assign axi_awid[1] = 1'b0;
    assign axi_arid[1] = 1'b0;

    native_to_axi4_master u_dma_debug_axi_master(
        .clk(clk), .rst(rst),
        .native_addr_i(m2_addr_i), .native_wdata_i(m2_data_i), .native_wmask_i(m2_wmask_i),
        .native_req_i(m2_req_i), .native_we_i(m2_we_i), .native_rdata_o(m2_data_o), .native_ready_o(m2_ready_o),
        .native_burst_len_i(8'd0),
        .m_axi_awaddr(axi_awaddr[95:64]), .m_axi_awlen(axi_awlen[23:16]), .m_axi_awsize(axi_awsize[8:6]),
        .m_axi_awburst(axi_awburst[5:4]), .m_axi_awvalid(axi_awvalid[2]), .m_axi_awready(axi_awready[2]),
        .m_axi_wdata(axi_wdata[95:64]), .m_axi_wstrb(axi_wstrb[11:8]), .m_axi_wlast(axi_wlast[2]),
        .m_axi_wvalid(axi_wvalid[2]), .m_axi_wready(axi_wready[2]), .m_axi_bresp(axi_bresp[5:4]),
        .m_axi_bvalid(axi_bvalid[2]), .m_axi_bready(axi_bready[2]), .m_axi_araddr(axi_araddr[95:64]),
        .m_axi_arlen(axi_arlen[23:16]), .m_axi_arsize(axi_arsize[8:6]), .m_axi_arburst(axi_arburst[5:4]),
        .m_axi_arvalid(axi_arvalid[2]), .m_axi_arready(axi_arready[2]), .m_axi_rdata(axi_rdata[95:64]),
        .m_axi_rresp(axi_rresp[5:4]), .m_axi_rlast(axi_rlast[2]), .m_axi_rvalid(axi_rvalid[2]),
        .m_axi_rready(axi_rready[2])
    );
    assign axi_awid[2] = 1'b0;
    assign axi_arid[2] = 1'b0;

    assign axi_awid[3] = reserved_accel_axi_awid;
    assign axi_awaddr[127:96] = reserved_accel_axi_awaddr;
    assign axi_awlen[31:24] = reserved_accel_axi_awlen;
    assign axi_awsize[11:9] = reserved_accel_axi_awsize;
    assign axi_awburst[7:6] = reserved_accel_axi_awburst;
    assign axi_awvalid[3] = reserved_accel_axi_awvalid;
    assign reserved_accel_axi_awready = axi_awready[3];
    assign axi_wdata[127:96] = reserved_accel_axi_wdata;
    assign axi_wstrb[15:12] = reserved_accel_axi_wstrb;
    assign axi_wlast[3] = reserved_accel_axi_wlast;
    assign axi_wvalid[3] = reserved_accel_axi_wvalid;
    assign reserved_accel_axi_wready = axi_wready[3];
    assign reserved_accel_axi_bid = axi_bid[3];
    assign reserved_accel_axi_bresp = axi_bresp[7:6];
    assign reserved_accel_axi_bvalid = axi_bvalid[3];
    assign axi_bready[3] = reserved_accel_axi_bready;
    assign axi_arid[3] = reserved_accel_axi_arid;
    assign axi_araddr[127:96] = reserved_accel_axi_araddr;
    assign axi_arlen[31:24] = reserved_accel_axi_arlen;
    assign axi_arsize[11:9] = reserved_accel_axi_arsize;
    assign axi_arburst[7:6] = reserved_accel_axi_arburst;
    assign axi_arvalid[3] = reserved_accel_axi_arvalid;
    assign reserved_accel_axi_arready = axi_arready[3];
    assign reserved_accel_axi_rid = axi_rid[3];
    assign reserved_accel_axi_rdata = axi_rdata[127:96];
    assign reserved_accel_axi_rresp = axi_rresp[7:6];
    assign reserved_accel_axi_rlast = axi_rlast[3];
    assign reserved_accel_axi_rvalid = axi_rvalid[3];
    assign axi_rready[3] = reserved_accel_axi_rready;
    assign m3_data_o = `ZeroWord;
    assign m3_ready_o = `False;

    axi4_crossbar u_axi4_crossbar(
        .clk(clk), .rst(rst),
        .s_axi_awid(axi_awid),
        .s_axi_awaddr(axi_awaddr), .s_axi_awlen(axi_awlen), .s_axi_awsize(axi_awsize),
        .s_axi_awburst(axi_awburst), .s_axi_awvalid(axi_awvalid), .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata), .s_axi_wstrb(axi_wstrb), .s_axi_wlast(axi_wlast),
        .s_axi_wvalid(axi_wvalid), .s_axi_wready(axi_wready), .s_axi_bid(axi_bid), .s_axi_bresp(axi_bresp),
        .s_axi_bvalid(axi_bvalid), .s_axi_bready(axi_bready), .s_axi_arid(axi_arid), .s_axi_araddr(axi_araddr),
        .s_axi_arlen(axi_arlen), .s_axi_arsize(axi_arsize), .s_axi_arburst(axi_arburst),
        .s_axi_arvalid(axi_arvalid), .s_axi_arready(axi_arready), .s_axi_rid(axi_rid), .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp), .s_axi_rlast(axi_rlast), .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready),
        .m_axi_awid(axi_slave_awid), .m_axi_awaddr(axi_slave_awaddr), .m_axi_awlen(axi_slave_awlen),
        .m_axi_awsize(axi_slave_awsize), .m_axi_awburst(axi_slave_awburst),
        .m_axi_awvalid(axi_slave_awvalid), .m_axi_awready(axi_slave_awready),
        .m_axi_wdata(axi_slave_wdata), .m_axi_wstrb(axi_slave_wstrb),
        .m_axi_wlast(axi_slave_wlast), .m_axi_wvalid(axi_slave_wvalid),
        .m_axi_wready(axi_slave_wready), .m_axi_bid(axi_slave_bid), .m_axi_bresp(axi_slave_bresp),
        .m_axi_bvalid(axi_slave_bvalid), .m_axi_bready(axi_slave_bready), .m_axi_arid(axi_slave_arid),
        .m_axi_araddr(axi_slave_araddr), .m_axi_arlen(axi_slave_arlen),
        .m_axi_arsize(axi_slave_arsize), .m_axi_arburst(axi_slave_arburst),
        .m_axi_arvalid(axi_slave_arvalid), .m_axi_arready(axi_slave_arready), .m_axi_rid(axi_slave_rid),
        .m_axi_rdata(axi_slave_rdata), .m_axi_rresp(axi_slave_rresp),
        .m_axi_rlast(axi_slave_rlast), .m_axi_rvalid(axi_slave_rvalid),
        .m_axi_rready(axi_slave_rready),
        .active_master_o(axi_active_master), .active_slave_o(axi_active_slave),
        .busy_o(axi_busy)
    );

`ifndef SOC_CPU_AXI_DEBUG_PROFILE
    uart_debug u_uart_debug(
        .clk(clk),
        .rst(rst),
        .debug_en_i(uart_debug_pin),
        .req_o(uart_dbg_req),
        .mem_we_o(uart_dbg_we),
        .mem_addr_o(uart_dbg_addr),
        .mem_wdata_o(uart_dbg_wdata),
        .mem_rdata_i(uart_dbg_rdata)
    );
`else
    assign uart_dbg_req = 1'b0;
    assign uart_dbg_we = 1'b0;
    assign uart_dbg_addr = `ZeroWord;
    assign uart_dbg_wdata = `ZeroWord;
`endif

    jtag_top #(
        .DMI_ADDR_BITS(6),
        .DMI_DATA_BITS(32),
        .DMI_OP_BITS(2)
    ) u_jtag_top(
        .clk(clk),
        .jtag_rst_n(rst),
        .jtag_pin_TCK(jtag_TCK),
        .jtag_pin_TMS(jtag_TMS),
        .jtag_pin_TDI(jtag_TDI),
        .jtag_pin_TDO(jtag_TDO),
        .reg_we_o(jtag_reg_we_o),
        .reg_addr_o(jtag_reg_addr_o),
        .reg_wdata_o(jtag_reg_data_o),
        .reg_rdata_i(jtag_reg_data_i),
        .mem_we_o(jtag_mem_we),
        .mem_addr_o(jtag_mem_addr),
        .mem_wdata_o(jtag_mem_wdata),
        .mem_rdata_i(jtag_mem_rdata),
        .op_req_o(jtag_mem_req),
        .halt_req_o(jtag_halt_req_o),
        .reset_req_o(jtag_reset_req_o)
    );

    generate
        if (USE_BSCAN_USER2) begin : g_bscan_user2
            jtag_bscan2_user2 u_jtag_bscan2_user2(
                .clk(clk), .arst_n(rst),
                .reg_we_o(bscan_jtag_reg_we_o), .reg_addr_o(bscan_jtag_reg_addr_o),
                .reg_wdata_o(bscan_jtag_reg_data_o), .reg_rdata_i(jtag_reg_data_i),
                .mem_we_o(bscan_jtag_mem_we), .mem_addr_o(bscan_jtag_mem_addr),
                .mem_wdata_o(bscan_jtag_mem_wdata), .mem_rdata_i(bscan_jtag_mem_rdata),
                .op_req_o(bscan_jtag_mem_req), .halt_req_o(bscan_jtag_halt_req_o),
                .reset_req_o(bscan_jtag_reset_req_o)
            );
        end else begin : g_no_bscan_user2
            assign bscan_jtag_reg_we_o = 1'b0;
            assign bscan_jtag_reg_addr_o = `ZeroReg;
            assign bscan_jtag_reg_data_o = `ZeroWord;
            assign bscan_jtag_mem_we = 1'b0;
            assign bscan_jtag_mem_addr = `ZeroWord;
            assign bscan_jtag_mem_wdata = `ZeroWord;
            assign bscan_jtag_mem_req = 1'b0;
            assign bscan_jtag_halt_req_o = 1'b0;
            assign bscan_jtag_reset_req_o = 1'b0;
        end
    endgenerate

endmodule
