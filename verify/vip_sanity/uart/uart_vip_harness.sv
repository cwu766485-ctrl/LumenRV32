`timescale 1ns/1ps

// A UART VIP attaches to tx_pin/rx_pin.  A register BFM/APB adapter drives
// we_i/addr_i/data_i when testing the UART block in isolation.
module uart_vip_harness (
    input wire clk, input wire rst, input wire we_i,
    input wire [31:0] addr_i, input wire [31:0] data_i, output wire [31:0] data_o,
    output wire tx_pin, input wire rx_pin
);
    uart u_dut (.clk(clk), .rst(rst), .we_i(we_i), .addr_i(addr_i), .data_i(data_i),
                .data_o(data_o), .tx_pin(tx_pin), .rx_pin(rx_pin));
endmodule
