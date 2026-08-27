// Shared SVA property set.  Simulation executes it; a formal harness may use
// the identical source with assumptions for the native-memory environment.
module cpu_core_properties(
    input logic clk, rst,
    input logic mem_pc_req_i, mem_pc_ready_i,
    input logic [31:0] mem_pc_addr_i,
    input logic mem_ex_req_i, mem_ex_ready_i, mem_ex_we_i,
    input logic [31:0] mem_ex_addr_i, mem_ex_wdata_i,
    input logic [4:0] jtag_reg_addr_i,
    input logic [31:0] jtag_reg_data_i
);
    property x0_reads_zero;
        @(posedge clk) disable iff (!rst) jtag_reg_addr_i == 5'd0 |-> jtag_reg_data_i == 32'd0;
    endproperty
    assert property (x0_reads_zero);

    property fetch_request_stable_while_waiting;
        @(posedge clk) disable iff (!rst) mem_pc_req_i && !mem_pc_ready_i |=> mem_pc_req_i && $stable(mem_pc_addr_i);
    endproperty
    assert property (fetch_request_stable_while_waiting);

    property data_request_stable_while_waiting;
        @(posedge clk) disable iff (!rst) mem_ex_req_i && !mem_ex_ready_i |=> mem_ex_req_i && $stable(mem_ex_addr_i) && $stable(mem_ex_we_i) && $stable(mem_ex_wdata_i);
    endproperty
    assert property (data_request_stable_while_waiting);
endmodule
