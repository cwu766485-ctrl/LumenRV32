`timescale 1 ns / 1 ps

// Active-low reset synchronizer for one JTAG CDC clock domain.
// Assertion is asynchronous. Release takes two local clock edges so that
// the DMI handshake state machines do not leave reset metastably.
module jtag_cdc_reset_sync (
    input wire clk,
    input wire arst_n,
    output wire srst_n
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] release_sync;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) release_sync <= 2'b00;
        else release_sync <= {release_sync[0], 1'b1};
    end

    assign srst_n = release_sync[1];
endmodule
