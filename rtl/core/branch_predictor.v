`timescale 1 ns / 1 ps
`include "defines.v"

// Direct-mapped BTB + 2-bit saturating BHT for conditional branches.
// EX resolves and trains every branch; cold entries retain backward-taken
// static prediction so behavior remains sensible before training.
module branch_predictor #(parameter ENTRY_COUNT = 16)(
    input wire clk, input wire rst,
    input wire lookup_valid_i, input wire[`InstAddrBus] lookup_pc_i,
    input wire fallback_taken_i, input wire[`InstAddrBus] fallback_target_i,
    output wire predict_taken_o, output wire[`InstAddrBus] predict_target_o,
    input wire update_valid_i, input wire[`InstAddrBus] update_pc_i,
    input wire update_taken_i, input wire[`InstAddrBus] update_target_i
);
    function integer clog2;
        input integer value; integer i;
        begin value = value - 1; for (i = 0; value > 0; i = i + 1) value = value >> 1; clog2 = i; end
    endfunction
    localparam INDEX_BITS = clog2(ENTRY_COUNT);
    reg valid[0:ENTRY_COUNT - 1];
    reg[`InstAddrBus] tag[0:ENTRY_COUNT - 1];
    reg[`InstAddrBus] target[0:ENTRY_COUNT - 1];
    reg[1:0] counter[0:ENTRY_COUNT - 1];
    integer i;
    wire[INDEX_BITS - 1:0] lookup_index = lookup_pc_i[INDEX_BITS + 1:2];
    wire[INDEX_BITS - 1:0] update_index = update_pc_i[INDEX_BITS + 1:2];
    wire hit = lookup_valid_i && valid[lookup_index] && (tag[lookup_index] == lookup_pc_i);
    assign predict_taken_o = hit ? counter[lookup_index][1] : fallback_taken_i;
    assign predict_target_o = hit ? target[lookup_index] : fallback_target_i;
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            for (i = 0; i < ENTRY_COUNT; i = i + 1) begin
                valid[i] <= `False; tag[i] <= `ZeroWord; target[i] <= `ZeroWord; counter[i] <= 2'b01;
            end
        end else if (update_valid_i == `True) begin
            valid[update_index] <= `True;
            tag[update_index] <= update_pc_i;
            target[update_index] <= update_target_i;
            if (!valid[update_index] || tag[update_index] != update_pc_i)
                counter[update_index] <= update_taken_i ? 2'b10 : 2'b01;
            else if (update_taken_i && counter[update_index] != 2'b11)
                counter[update_index] <= counter[update_index] + 1'b1;
            else if (!update_taken_i && counter[update_index] != 2'b00)
                counter[update_index] <= counter[update_index] - 1'b1;
        end
    end
endmodule
