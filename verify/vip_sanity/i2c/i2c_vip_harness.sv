`timescale 1ns/1ps

// Connect an open-drain I2C slave VIP to scl/sda.  Pull-ups are intentionally
// not instantiated: the VIP environment should model the bus electrical rule.
module i2c_vip_harness (
    input wire clk, input wire rst, input wire we_i,
    input wire [31:0] addr_i, input wire [31:0] data_i, output wire [31:0] data_o,
    inout tri scl, inout tri sda, output wire irq_o
);
    i2c_master u_dut (.clk(clk), .rst(rst), .we_i(we_i), .addr_i(addr_i), .data_i(data_i),
                      .data_o(data_o), .scl(scl), .sda(sda), .irq_o(irq_o));
endmodule
