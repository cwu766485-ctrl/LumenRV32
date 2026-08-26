`timescale 1 ns / 1 ps

// USER2 scan-data transport for the project DMI endpoint.
//
// This module deliberately consumes the USER2 DR signals, rather than
// forwarding the chip configuration TAP into jtag_driver.  The latter would
// see UPDATE-IR/UPDATE-DR transitions that belong to the outer TAP and can
// mistake a USER instruction selection for a DMI request.  A submission is
// accepted only after a matching USER2 CAPTURE event.
module jtag_user2_dmi_transport #(
    parameter DMI_ADDR_BITS = 6,
    parameter DMI_DATA_BITS = 32,
    parameter DMI_OP_BITS = 2
)(
    input wire clk,
    input wire arst_n,

    input wire tck,
    input wire sel_i,
    input wire capture_i,
    input wire shift_i,
    input wire update_i,
    input wire tdi_i,
    output wire tdo_o,

    output wire reg_we_o,
    output wire[4:0] reg_addr_o,
    output wire[31:0] reg_wdata_o,
    input wire[31:0] reg_rdata_i,
    output wire mem_we_o,
    output wire[31:0] mem_addr_o,
    output wire[31:0] mem_wdata_o,
    input wire[31:0] mem_rdata_i,
    output wire op_req_o,
    output wire halt_req_o,
    output wire reset_req_o
);
    localparam DMI_BITS = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;

    wire tck_rst_n;
    wire cpu_rst_n;
    reg[DMI_BITS - 1:0] shift_reg;
    reg capture_seen;
    reg req_submit;
    reg[DMI_BITS - 1:0] req_data;
    reg[DMI_BITS - 1:0] resp_data;
    reg dm_busy;
    reg resp_wait_ack_drop;

    wire req_idle;
    wire req_valid;
    wire[DMI_BITS - 1:0] req_bundle;
    wire dm_ack;
    wire dm_resp_valid;
    wire[DMI_BITS - 1:0] dm_resp_bundle;
    wire dm_resp_idle;
    (* ASYNC_REG = "TRUE" *) reg dm_resp_idle_sync_d;
    (* ASYNC_REG = "TRUE" *) reg dm_resp_idle_sync;
    wire resp_ack;
    wire resp_valid;
    wire[DMI_BITS - 1:0] resp_bundle;
    wire busy = dm_busy | !req_idle;
    wire request_is_nop = (shift_reg[DMI_OP_BITS - 1:0] == {DMI_OP_BITS{1'b0}});
    wire[DMI_BITS - 1:0] busy_response = {{(DMI_ADDR_BITS + DMI_DATA_BITS){1'b0}}, {DMI_OP_BITS{1'b1}}};

    jtag_cdc_reset_sync u_tck_reset_sync (
        .clk(tck), .arst_n(arst_n), .srst_n(tck_rst_n)
    );
    jtag_cdc_reset_sync u_cpu_reset_sync (
        .clk(clk), .arst_n(arst_n), .srst_n(cpu_rst_n)
    );

    // The DMI response sender lives in the CPU clock domain. Synchronize its
    // one-entry idle indication before it releases the TCK-side request gate.
    always @(posedge tck or negedge tck_rst_n) begin
        if (!tck_rst_n) begin
            dm_resp_idle_sync_d <= 1'b1;
            dm_resp_idle_sync <= 1'b1;
        end else begin
            dm_resp_idle_sync_d <= dm_resp_idle;
            dm_resp_idle_sync <= dm_resp_idle_sync_d;
        end
    end

    // USER2 capture/shift/update lives wholly in the TCK domain.  The
    // captured flag is the transport-v16 guard: UPDATE without a preceding
    // USER2 CAPTURE cannot launch a DMI request.
    always @(posedge tck or negedge tck_rst_n) begin
        if (!tck_rst_n) begin
            shift_reg <= {DMI_BITS{1'b0}};
            capture_seen <= 1'b0;
            req_submit <= 1'b0;
            req_data <= {DMI_BITS{1'b0}};
            resp_data <= {DMI_BITS{1'b0}};
            dm_busy <= 1'b0;
            resp_wait_ack_drop <= 1'b0;
        end else begin
            req_submit <= 1'b0;
            if (resp_valid) begin
                resp_data <= resp_bundle;
                // Do not accept another request merely because the response
                // has reached TCK.  jtag_dm has one response sender, whose
                // four-phase ack must return low before it can transmit the
                // next response.  Keeping busy through that round trip
                // enforces the documented single-outstanding boundary.
                resp_wait_ack_drop <= 1'b1;
            end
            // TCK has consumed the response. The response buffer in jtag_dm
            // retains any just-arrived next response, so the transport may
            // accept the next request as soon as this ACK is released.
            if (resp_wait_ack_drop && !resp_ack) begin
                dm_busy <= 1'b0;
                resp_wait_ack_drop <= 1'b0;
            end
            if (sel_i && capture_i) begin
                shift_reg <= busy ? busy_response : resp_data;
                capture_seen <= 1'b1;
            end else if (sel_i && shift_i) begin
                shift_reg <= {tdi_i, shift_reg[DMI_BITS - 1:1]};
            end
            if (sel_i && update_i) begin
                // A host uses a NOP DR scan to capture an asynchronous
                // response.  It still produces UPDATE_DR at the outer TAP,
                // but NOP must not occupy the one-entry DMI transport or
                // replace the response the host is collecting.
                if (capture_seen && !request_is_nop && !busy && req_idle) begin
                    req_data <= shift_reg;
                    req_submit <= 1'b1;
                    dm_busy <= 1'b1;
                end
                capture_seen <= 1'b0;
            end
        end
    end

    assign tdo_o = shift_reg[0];

    full_handshake_tx #(.DW(DMI_BITS)) u_req_tx (
        .clk(tck), .rst_n(tck_rst_n), .ack_i(dm_ack),
        .req_i(req_submit), .req_data_i(req_data), .idle_o(req_idle),
        .req_o(req_valid), .req_data_o(req_bundle)
    );
    full_handshake_rx #(.DW(DMI_BITS)) u_resp_rx (
        .clk(tck), .rst_n(tck_rst_n), .req_i(dm_resp_valid),
        .req_data_i(dm_resp_bundle), .ack_o(resp_ack),
        .recv_data_o(resp_bundle), .recv_rdy_o(resp_valid)
    );

    jtag_dm #(
        .DMI_ADDR_BITS(DMI_ADDR_BITS), .DMI_DATA_BITS(DMI_DATA_BITS),
        .DMI_OP_BITS(DMI_OP_BITS)
    ) u_jtag_dm (
        .clk(clk), .rst_n(cpu_rst_n), .dm_ack_o(dm_ack),
        .dtm_req_valid_i(req_valid), .dtm_req_data_i(req_bundle),
        .dtm_ack_i(resp_ack), .dm_resp_data_o(dm_resp_bundle),
        .dm_resp_valid_o(dm_resp_valid), .dm_reg_we_o(reg_we_o),
        .dm_reg_addr_o(reg_addr_o), .dm_reg_wdata_o(reg_wdata_o),
        .dm_reg_rdata_i(reg_rdata_i), .dm_mem_we_o(mem_we_o),
        .dm_mem_addr_o(mem_addr_o), .dm_mem_wdata_o(mem_wdata_o),
        .dm_mem_rdata_i(mem_rdata_i), .dm_op_req_o(op_req_o),
        .dm_halt_req_o(halt_req_o), .dm_reset_req_o(reset_req_o),
        .dm_resp_idle_o(dm_resp_idle)
    );
endmodule
