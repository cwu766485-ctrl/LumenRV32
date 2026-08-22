`timescale 1 ns / 1 ps

`ifndef FPGA_CPU_CLK_DIV
`define FPGA_CPU_CLK_DIV 4
`endif

// Minimal physical bring-up image for the project RTL itself.
// It deliberately uses only the SoC ROM/RAM (BRAM inferred by Vivado) and
// UART; DDR4, QSPI and external AXI are not part of this image.
module zu15eg_riscv_bram_uart_top (
    input  wire pl_ref_clk_n,
    input  wire pl_ref_clk_p,
    input  wire pl_uart_rx,
    output wire pl_uart_tx,
    output wire rs485_de_re,
    output wire rs485_di,
    input  wire rs485_ro,
    output wire status_led
);
    wire clk_200m;
    wire clk_50m;
    reg [15:0] reset_count = 16'h0000;
    wire rst_n = &reset_count;
    wire uart_tx;
    wire over;
    wire succ;
    wire halted;
    wire [1:0] gpio_unused;
    wire spi_mosi_unused;
    wire spi_ss_unused;
    wire spi_clk_unused;
    wire [3:0] qspi_io_unused;
    wire qspi_cs_n_unused;
    wire qspi_clk_unused;

    IBUFDS u_refclk_ibuf (
        .I(pl_ref_clk_p),
        .IB(pl_ref_clk_n),
        .O(clk_200m)
    );

    // The board reference is 200 MHz.  The project UART default divisor
    // targets 115200 baud at 50 MHz, so retain that documented clock rate.
    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(`FPGA_CPU_CLK_DIV),
        .IS_CE_INVERTED(1'b0),
        .IS_CLR_INVERTED(1'b0)
    ) u_clk_div (
        .I(clk_200m),
        .CE(1'b1),
        .CLR(1'b0),
        .O(clk_50m)
    );

    always @(posedge clk_50m) begin
        if (!rst_n)
            reset_count <= reset_count + 1'b1;
    end

    heterogeneous_soc_top u_soc (
        .clk(clk_50m),
        .rst(rst_n),
        .over(over),
        .succ(succ),
        .halted_ind(halted),
        .uart_debug_pin(1'b1),
        .uart_tx_pin(uart_tx),
        .uart_rx_pin(pl_uart_rx),
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
        .qspi_clk(qspi_clk_unused)
    );

    assign pl_uart_tx = uart_tx;
    assign rs485_de_re = 1'b1;
    assign rs485_di = uart_tx;
    assign status_led = ~halted;
endmodule
