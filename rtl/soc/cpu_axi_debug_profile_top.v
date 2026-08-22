`timescale 1 ns / 1 ps

// Portable CPU-focused integration boundary used for FPGA and ASIC PPA work.
// It keeps the RV32IM core (including I/D cache), CPU instruction/data AXI
// adapters, AXI fabric, ROM/RAM, PMU and JTAG/debug. DMA and normal board
// peripherals are removed with SOC_CPU_AXI_DEBUG_PROFILE.
module cpu_axi_debug_profile_top (
    input wire clk,
    input wire rst,
    input wire jtag_TCK,
    input wire jtag_TMS,
    input wire jtag_TDI,
    output wire jtag_TDO,
    output wire over,
    output wire succ,
    output wire halted_ind
);
    wire uart_tx_unused;
    wire [1:0] gpio_unused;
    wire spi_mosi_unused;
    wire spi_ss_unused;
    wire spi_clk_unused;
    wire [3:0] qspi_io_unused;
    wire qspi_cs_n_unused;
    wire qspi_clk_unused;

    heterogeneous_soc_top u_soc (
        .clk(clk),
        .rst(rst),
        .over(over),
        .succ(succ),
        .halted_ind(halted_ind),
        .uart_debug_pin(1'b0),
        .uart_tx_pin(uart_tx_unused),
        .uart_rx_pin(1'b1),
        .gpio(gpio_unused),
        .jtag_TCK(jtag_TCK),
        .jtag_TMS(jtag_TMS),
        .jtag_TDI(jtag_TDI),
        .jtag_TDO(jtag_TDO),
        .spi_miso(1'b0),
        .spi_mosi(spi_mosi_unused),
        .spi_ss(spi_ss_unused),
        .spi_clk(spi_clk_unused),
        .qspi_io(qspi_io_unused),
        .qspi_cs_n(qspi_cs_n_unused),
        .qspi_clk(qspi_clk_unused)
    );
endmodule
