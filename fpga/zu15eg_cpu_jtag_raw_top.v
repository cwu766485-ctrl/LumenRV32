`timescale 1 ns / 1 ps

`ifndef FPGA_CPU_CLK_DIV
`define FPGA_CPU_CLK_DIV 2
`endif

// ZU15EG CPU profile with a raw, external four-wire JTAG connection.
// TCK is driven by an external probe through board-specific PL I/O.
module zu15eg_cpu_jtag_raw_top (
    input  wire pl_ref_clk_n,
    input  wire pl_ref_clk_p,
    input  wire jtag_TCK,
    input  wire jtag_TMS,
    input  wire jtag_TDI,
    output wire jtag_TDO,
    output wire status_led
);
    wire clk_200m;
    wire cpu_clk;
    reg [15:0] reset_count = 16'h0000;
    wire rst_n = &reset_count;
    wire halted;
    (* KEEP = "TRUE" *) wire over;
    (* KEEP = "TRUE" *) wire succ;

    IBUFDS u_refclk_ibuf (.I(pl_ref_clk_p), .IB(pl_ref_clk_n), .O(clk_200m));
    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(`FPGA_CPU_CLK_DIV),
        .IS_CE_INVERTED(1'b0),
        .IS_CLR_INVERTED(1'b0)
    ) u_clk_div (.I(clk_200m), .CE(1'b1), .CLR(1'b0), .O(cpu_clk));

    always @(posedge cpu_clk) begin
        if (!rst_n)
            reset_count <= reset_count + 1'b1;
    end

    (* KEEP_HIERARCHY = "yes" *) cpu_axi_debug_profile_top u_profile (
        .clk(cpu_clk), .rst(rst_n),
        .jtag_TCK(jtag_TCK), .jtag_TMS(jtag_TMS),
        .jtag_TDI(jtag_TDI), .jtag_TDO(jtag_TDO),
        .over(over), .succ(succ), .halted_ind(halted)
    );

    assign status_led = over ^ succ ^ ~halted;
endmodule
