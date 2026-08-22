`timescale 1 ns / 1 ps

`ifndef FPGA_CPU_CLK_DIV
`define FPGA_CPU_CLK_DIV 2
`endif

// ZU15EG implementation wrapper for the portable CPU/AXI/PMU/JTAG profile.
module zu15eg_cpu_profile_top (
    input wire pl_ref_clk_n,
    input wire pl_ref_clk_p,
    output wire status_led
);
    wire clk_200m;
    wire cpu_clk;
    reg [15:0] reset_count = 16'h0000;
    wire rst_n = &reset_count;
    wire halted;
    // These status paths make the CPU architecturally observable at the FPGA
    // top, preventing an otherwise un-driven benchmark wrapper from being
    // reduced to an empty design during synthesis.
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
        .jtag_TCK(1'b0), .jtag_TMS(1'b1), .jtag_TDI(1'b0), .jtag_TDO(),
        .over(over), .succ(succ), .halted_ind(halted)
    );

    assign status_led = over ^ succ ^ ~halted;
endmodule
