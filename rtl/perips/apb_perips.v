`timescale 1 ns / 1 ps

/*
SPDX-License-Identifier: Apache-2.0

Project-specific implementation for heterogeneous_soc.

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

`include "../core/defines.v"

// APB peripheral interconnect for timer / uart / gpio / spi / qspi / i2c / pmu / dma.
module apb_perips(

    input wire clk,
    input wire rst,

    input wire[`MemAddrBus] paddr_i,
    input wire[`MemBus] pwdata_i,
    output reg[`MemBus] prdata_o,
    input wire[3:0] pstrb_i,
    input wire pwrite_i,
    input wire psel_i,
    input wire penable_i,
    output wire pready_o,
    output wire pslverr_o,

    input wire[`InstBus] perf_inst_i,
    input wire[`Hold_Flag_Bus] perf_hold_flag_i,
    input wire perf_int_assert_i,
    input wire perf_div_busy_i,
    input wire perf_icache_hit_i,
    input wire perf_icache_miss_i,
    input wire perf_dcache_load_hit_i,
    input wire perf_dcache_load_miss_i,
    input wire perf_dcache_store_hit_i,
    input wire perf_dcache_store_miss_i,
    input wire perf_branch_redirect_i,
    input wire perf_branch_flush_i,
    input wire[2:0] perf_prefetch_occupancy_i,
    input wire perf_prefetch_full_i,
    input wire perf_prefetch_stall_i,
    input wire perf_branch_predict_hit_i,
    input wire perf_branch_predict_miss_i,
    input wire perf_dcache_load_miss_stall_i,
    input wire perf_dcache_store_wait_i,
    input wire perf_fetch_bus_wait_i,
    input wire perf_data_bus_wait_i,
    input wire perf_id_contention_i,
    input wire perf_store_buffer_enqueue_i,
    input wire perf_store_buffer_full_stall_i,
    input wire perf_store_buffer_drain_i,

    output wire timer_int_o,
    output wire dma_int_o,
    output wire i2c_int_o,

    output wire[`MemAddrBus] dma_addr_o,
    output wire[`MemBus] dma_data_o,
    output wire[`MemMaskBus] dma_wmask_o,
    output wire dma_req_o,
    output wire dma_we_o,
    input wire[`MemBus] dma_data_i,
    input wire dma_ready_i,

    output wire uart_tx_pin,
    input wire uart_rx_pin,
    inout wire[1:0] gpio,

    input wire spi_miso,
    output wire spi_mosi,
    output wire spi_ss,
    output wire spi_clk,

    inout wire[3:0] qspi_io,
    output wire qspi_cs_n,
    output wire qspi_clk,

    inout wire i2c_scl,
    inout wire i2c_sda

    );

    localparam [3:0] APB_SEL_TIMER = 4'h0;
    localparam [3:0] APB_SEL_UART = 4'h1;
    localparam [3:0] APB_SEL_GPIO = 4'h2;
    localparam [3:0] APB_SEL_SPI = 4'h3;
    localparam [3:0] APB_SEL_PMU = 4'h4;
    localparam [3:0] APB_SEL_DMA = 4'h5;
    localparam [3:0] APB_SEL_QSPI = 4'h7;
    localparam [3:0] APB_SEL_I2C = 4'h8;

    wire apb_access = psel_i & penable_i;
    wire timer_sel = apb_access & (paddr_i[15:12] == APB_SEL_TIMER);
    wire uart_sel = apb_access & (paddr_i[15:12] == APB_SEL_UART);
    wire gpio_sel = apb_access & (paddr_i[15:12] == APB_SEL_GPIO);
    wire spi_sel = apb_access & (paddr_i[15:12] == APB_SEL_SPI);
    wire pmu_sel = apb_access & (paddr_i[15:12] == APB_SEL_PMU);
    wire dma_sel = apb_access & (paddr_i[15:12] == APB_SEL_DMA);
    wire qspi_sel = apb_access & (paddr_i[15:12] == APB_SEL_QSPI);
    wire i2c_sel = apb_access & (paddr_i[15:12] == APB_SEL_I2C);

    wire[`MemBus] timer_data_o;
    wire[`MemBus] uart_data_o;
    wire[`MemBus] gpio_data_o;
    wire[`MemBus] spi_data_o;
    wire[`MemBus] pmu_data_o;
    wire[`MemBus] dma_data_out;
    wire[`MemBus] qspi_data_o;
    wire[`MemBus] i2c_data_o;
    wire dma_busy;
    wire dma_done;
    wire dma_error;
    wire[`MemBus] timer_wdata;
    wire[`MemBus] uart_wdata;
    wire[`MemBus] gpio_wdata;
    wire[`MemBus] spi_wdata;
    wire[`MemBus] pmu_wdata;
    wire[`MemBus] dma_wdata;
    wire[`MemBus] qspi_wdata;
    wire[`MemBus] i2c_wdata;
    wire[1:0] io_in;
    wire[31:0] gpio_ctrl;
    wire[31:0] gpio_data;

    assign pready_o = 1'b1;
    assign pslverr_o = 1'b0;

`ifdef SOC_DDR_BOARD_MINIMAL
    assign gpio = 2'bzz;
    assign io_in = 2'b0;
`else
    assign gpio[0] = (gpio_ctrl[1:0] == 2'b01) ? gpio_data[0] : 1'bz;
    assign io_in[0] = gpio[0];
    assign gpio[1] = (gpio_ctrl[3:2] == 2'b01) ? gpio_data[1] : 1'bz;
    assign io_in[1] = gpio[1];
`endif

    function [`MemBus] apply_strb;
        input [`MemBus] prior;
        input [`MemBus] next;
        input [3:0] strb;
        begin
            apply_strb = prior;
            if (strb[0]) apply_strb[7:0] = next[7:0];
            if (strb[1]) apply_strb[15:8] = next[15:8];
            if (strb[2]) apply_strb[23:16] = next[23:16];
            if (strb[3]) apply_strb[31:24] = next[31:24];
        end
    endfunction

    assign timer_wdata = apply_strb(timer_data_o, pwdata_i, pstrb_i);
    assign uart_wdata = apply_strb(uart_data_o, pwdata_i, pstrb_i);
    assign gpio_wdata = apply_strb(gpio_data_o, pwdata_i, pstrb_i);
    assign spi_wdata = apply_strb(spi_data_o, pwdata_i, pstrb_i);
    assign pmu_wdata = apply_strb(pmu_data_o, pwdata_i, pstrb_i);
    assign dma_wdata = apply_strb(dma_data_out, pwdata_i, pstrb_i);
    assign qspi_wdata = apply_strb(qspi_data_o, pwdata_i, pstrb_i);
    assign i2c_wdata = apply_strb(i2c_data_o, pwdata_i, pstrb_i);

`ifdef SOC_CPU_AXI_DEBUG_PROFILE
    // CPU interview/PPA profile: retain only the PMU register bank.  The
    // normal SoC remains unchanged; all ordinary APB peripherals are quiet.
    assign timer_data_o = `ZeroWord;
    assign timer_int_o = 1'b0;
    assign uart_data_o = `ZeroWord;
    assign uart_tx_pin = 1'b0;
    assign gpio = 2'bzz;
    assign io_in = 2'b00;
    assign gpio_data_o = `ZeroWord;
    assign gpio_ctrl = `ZeroWord;
    assign gpio_data = `ZeroWord;
    assign i2c_data_o = `ZeroWord;
    assign i2c_scl = 1'bz;
    assign i2c_sda = 1'bz;
    assign i2c_int_o = 1'b0;
    assign spi_data_o = `ZeroWord;
    assign spi_mosi = 1'b0;
    assign spi_ss = 1'b1;
    assign spi_clk = 1'b0;
    assign qspi_data_o = `ZeroWord;
    assign qspi_io = 4'bzzzz;
    assign qspi_cs_n = 1'b1;
    assign qspi_clk = 1'b0;
`else
    timer u_timer(
        .clk(clk),
        .rst(rst),
        .data_i(timer_wdata),
        .addr_i({20'h0, paddr_i[11:0]}),
        .we_i(pwrite_i & timer_sel),
        .data_o(timer_data_o),
        .int_sig_o(timer_int_o)
    );

    uart u_uart(
        .clk(clk),
        .rst(rst),
        .we_i(pwrite_i & uart_sel),
        .addr_i({20'h0, paddr_i[11:0]}),
        .data_i(uart_wdata),
        .data_o(uart_data_o),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

`ifdef SOC_DDR_BOARD_MINIMAL
    assign gpio_data_o = `ZeroWord;
    assign gpio_ctrl = `ZeroWord;
    assign gpio_data = `ZeroWord;
`else
    gpio u_gpio(
        .clk(clk),
        .rst(rst),
        .we_i(pwrite_i & gpio_sel),
        .addr_i({20'h0, paddr_i[11:0]}),
        .data_i(gpio_wdata),
        .data_o(gpio_data_o),
        .io_pin_i(io_in),
        .reg_ctrl(gpio_ctrl),
        .reg_data(gpio_data)
    );
`endif

    i2c_master u_i2c_master(
        .clk(clk),
        .rst(rst),
        .we_i(pwrite_i & i2c_sel),
        .addr_i({20'h0, paddr_i[11:0]}),
        .data_i(i2c_wdata),
        .data_o(i2c_data_o),
        .scl(i2c_scl),
        .sda(i2c_sda),
        .irq_o(i2c_int_o)
    );

`ifdef SOC_DDR_BOARD_MINIMAL
    assign spi_data_o = `ZeroWord;
    assign spi_mosi = 1'b0;
    assign spi_ss = 1'b1;
    assign spi_clk = 1'b0;
`else
    spi u_spi(
        .clk(clk),
        .rst(rst),
        .data_i(spi_wdata),
        .addr_i({20'h0, paddr_i[11:0]}),
        .we_i(pwrite_i & spi_sel),
        .data_o(spi_data_o),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_ss(spi_ss),
        .spi_clk(spi_clk)
    );
`endif

`ifdef SOC_DDR_BOARD_MINIMAL
    assign qspi_data_o = `ZeroWord;
    assign qspi_io = 4'bzzzz;
    assign qspi_cs_n = 1'b1;
    assign qspi_clk = 1'b0;
`else
    qspi u_qspi(
        .clk(clk),
        .rst(rst),
        .data_i(qspi_wdata),
        .addr_i({20'h0, paddr_i[11:0]}),
        .we_i(pwrite_i & qspi_sel),
        .data_o(qspi_data_o),
        .qspi_io(qspi_io),
        .qspi_cs_n(qspi_cs_n),
        .qspi_clk(qspi_clk)
    );
`endif

`endif  // SOC_CPU_AXI_DEBUG_PROFILE

    pmu u_pmu(
        .clk(clk),
        .rst(rst),
        .we_i(pwrite_i & pmu_sel),
        .addr_i({20'h0, paddr_i[11:0]}),
        .data_i(pmu_wdata),
        .data_o(pmu_data_o),
        .inst_i(perf_inst_i),
        .hold_flag_i(perf_hold_flag_i),
        .int_assert_i(perf_int_assert_i),
        .div_busy_i(perf_div_busy_i),
        .icache_hit_i(perf_icache_hit_i),
        .icache_miss_i(perf_icache_miss_i),
        .dcache_load_hit_i(perf_dcache_load_hit_i),
        .dcache_load_miss_i(perf_dcache_load_miss_i),
        .dcache_store_hit_i(perf_dcache_store_hit_i),
        .dcache_store_miss_i(perf_dcache_store_miss_i),
        .branch_redirect_i(perf_branch_redirect_i),
        .branch_flush_i(perf_branch_flush_i),
        .prefetch_occupancy_i(perf_prefetch_occupancy_i),
        .prefetch_full_i(perf_prefetch_full_i),
        .prefetch_stall_i(perf_prefetch_stall_i),
        .branch_predict_hit_i(perf_branch_predict_hit_i),
        .branch_predict_miss_i(perf_branch_predict_miss_i),
        .dcache_load_miss_stall_i(perf_dcache_load_miss_stall_i),
        .dcache_store_wait_i(perf_dcache_store_wait_i),
        .fetch_bus_wait_i(perf_fetch_bus_wait_i),
        .data_bus_wait_i(perf_data_bus_wait_i),
        .id_contention_i(perf_id_contention_i),
        .store_buffer_enqueue_i(perf_store_buffer_enqueue_i),
        .store_buffer_full_stall_i(perf_store_buffer_full_stall_i),
        .store_buffer_drain_i(perf_store_buffer_drain_i)
    );

`ifdef SOC_CPU_AXI_DEBUG_PROFILE
    assign dma_data_out = `ZeroWord;
    assign dma_addr_o = `ZeroWord;
    assign dma_data_o = `ZeroWord;
    assign dma_wmask_o = 4'b0000;
    assign dma_req_o = 1'b0;
    assign dma_we_o = 1'b0;
    assign dma_int_o = 1'b0;
`else
    dma u_dma(
        .clk(clk),
        .rst(rst),
        .we_i(pwrite_i & dma_sel),
        .addr_i({20'h0, paddr_i[11:0]}),
        .data_i(dma_wdata),
        .data_o(dma_data_out),
        .mem_addr_o(dma_addr_o),
        .mem_data_o(dma_data_o),
        .mem_wmask_o(dma_wmask_o),
        .mem_req_o(dma_req_o),
        .mem_we_o(dma_we_o),
        .mem_data_i(dma_data_i),
        .mem_ready_i(dma_ready_i),
        .busy_o(dma_busy),
        .done_o(dma_done),
        .error_o(dma_error),
        .irq_o(dma_int_o)
    );
`endif

    always @ (*) begin
        case (paddr_i[15:12])
            APB_SEL_TIMER: prdata_o = timer_data_o;
            APB_SEL_UART: prdata_o = uart_data_o;
            APB_SEL_GPIO: prdata_o = gpio_data_o;
            APB_SEL_SPI: prdata_o = spi_data_o;
            APB_SEL_PMU: prdata_o = pmu_data_o;
            APB_SEL_DMA: prdata_o = dma_data_out;
            APB_SEL_QSPI: prdata_o = qspi_data_o;
            APB_SEL_I2C: prdata_o = i2c_data_o;
            default: prdata_o = `ZeroWord;
        endcase
    end

endmodule
