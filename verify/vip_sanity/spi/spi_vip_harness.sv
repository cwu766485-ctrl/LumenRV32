`timescale 1ns/1ps

// An SPI slave VIP attaches to spi_mosi/spi_miso/spi_ss/spi_clk.
module spi_vip_harness (
    input wire clk, input wire rst, input wire we_i,
    input wire [31:0] addr_i, input wire [31:0] data_i, output wire [31:0] data_o,
    output wire spi_mosi, input wire spi_miso, output wire spi_ss, output wire spi_clk
);
    spi u_dut (.clk(clk), .rst(rst), .we_i(we_i), .addr_i(addr_i), .data_i(data_i), .data_o(data_o),
               .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_ss(spi_ss), .spi_clk(spi_clk));
endmodule
