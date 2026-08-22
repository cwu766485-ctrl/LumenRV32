`timescale 1 ns / 1 ps

`include "../core/defines.v"

module extmem_async_bridge(
    input wire src_clk,
    input wire src_rst,
    input wire src_req_i,
    input wire src_we_i,
    input wire[`MemAddrBus] src_addr_i,
    input wire[`MemBus] src_wdata_i,
    input wire[`MemMaskBus] src_wmask_i,
    output reg[`MemBus] src_rdata_o,
    output reg src_ready_o,

    input wire dst_clk,
    input wire dst_rst,
    output reg dst_req_o,
    output reg dst_we_o,
    output reg[`MemAddrBus] dst_addr_o,
    output reg[`MemBus] dst_wdata_o,
    output reg[`MemMaskBus] dst_wmask_o,
    input wire[`MemBus] dst_rdata_i,
    input wire dst_ready_i,

    output wire dbg_src_busy_o,
    output wire dbg_src_req_toggle_o,
    output wire dbg_src_req_seen_o,
    output wire dbg_src_rsp_toggle_sync_o,
    output wire dbg_src_rsp_toggle_seen_o,
    output wire dbg_dst_req_toggle_sync_o,
    output wire dbg_dst_req_toggle_seen_o,
    output wire dbg_dst_capture_pending_o,
    output wire dbg_dst_rsp_toggle_o,
    output wire[`MemAddrBus] dbg_src_payload_addr_o,
    output wire[`MemBus] dbg_src_payload_wdata_o,
    output wire dbg_src_payload_we_o,
    output wire[`MemMaskBus] dbg_src_payload_wmask_o
    );

    (* mark_debug = "true" *) reg src_busy_r;
    (* mark_debug = "true" *) reg src_req_toggle_r;
    reg src_req_seen_r;
    (* ASYNC_REG = "TRUE", mark_debug = "true" *) reg src_rsp_toggle_sync1_r;
    (* ASYNC_REG = "TRUE", mark_debug = "true" *) reg src_rsp_toggle_sync2_r;
    (* mark_debug = "true" *) reg src_rsp_toggle_seen_r;

    (* ASYNC_REG = "TRUE", mark_debug = "true" *) reg dst_req_toggle_sync1_r;
    (* ASYNC_REG = "TRUE", mark_debug = "true" *) reg dst_req_toggle_sync2_r;
    (* mark_debug = "true" *) reg dst_req_toggle_seen_r;
    (* mark_debug = "true" *) reg dst_capture_pending_r;
    (* mark_debug = "true" *) reg dst_rsp_toggle_r;

    reg src_payload_we_r;
    reg[`MemAddrBus] src_payload_addr_r;
    reg[`MemBus] src_payload_wdata_r;
    reg[`MemMaskBus] src_payload_wmask_r;
    reg[`MemBus] dst_rsp_rdata_r;

    assign dbg_src_busy_o = src_busy_r;
    assign dbg_src_req_toggle_o = src_req_toggle_r;
    assign dbg_src_req_seen_o = src_req_seen_r;
    assign dbg_src_rsp_toggle_sync_o = src_rsp_toggle_sync2_r;
    assign dbg_src_rsp_toggle_seen_o = src_rsp_toggle_seen_r;
    assign dbg_dst_req_toggle_sync_o = dst_req_toggle_sync2_r;
    assign dbg_dst_req_toggle_seen_o = dst_req_toggle_seen_r;
    assign dbg_dst_capture_pending_o = dst_capture_pending_r;
    assign dbg_dst_rsp_toggle_o = dst_rsp_toggle_r;
    assign dbg_src_payload_addr_o = src_payload_addr_r;
    assign dbg_src_payload_wdata_o = src_payload_wdata_r;
    assign dbg_src_payload_we_o = src_payload_we_r;
    assign dbg_src_payload_wmask_o = src_payload_wmask_r;

    always @(posedge src_clk) begin
        if (src_rst == `RstEnable) begin
            src_busy_r <= 1'b0;
            src_req_toggle_r <= 1'b0;
            src_req_seen_r <= 1'b0;
            src_rsp_toggle_sync1_r <= 1'b0;
            src_rsp_toggle_sync2_r <= 1'b0;
            src_rsp_toggle_seen_r <= 1'b0;
            src_payload_we_r <= 1'b0;
            src_payload_addr_r <= `ZeroWord;
            src_payload_wdata_r <= `ZeroWord;
            src_payload_wmask_r <= 4'b0;
            src_rdata_o <= `ZeroWord;
            src_ready_o <= `False;
        end else begin
            src_rsp_toggle_sync1_r <= dst_rsp_toggle_r;
            src_rsp_toggle_sync2_r <= src_rsp_toggle_sync1_r;
            if (src_ready_o == `True && src_req_i == `False) begin
                src_ready_o <= `False;
            end

            if (src_busy_r == 1'b0) begin
                if (src_req_i == `True && src_req_seen_r == 1'b0) begin
                    src_payload_we_r <= src_we_i;
                    src_payload_addr_r <= src_addr_i;
                    src_payload_wdata_r <= src_wdata_i;
                    src_payload_wmask_r <= src_wmask_i;
                    src_req_toggle_r <= ~src_req_toggle_r;
                    src_busy_r <= 1'b1;
                    src_req_seen_r <= 1'b1;
                end else if (src_req_i == `False) begin
                    src_req_seen_r <= 1'b0;
                end
            end

            if (src_busy_r == 1'b1 && src_rsp_toggle_sync2_r != src_rsp_toggle_seen_r) begin
                src_rsp_toggle_seen_r <= src_rsp_toggle_sync2_r;
                src_busy_r <= 1'b0;
                src_rdata_o <= dst_rsp_rdata_r;
                src_ready_o <= `True;
                src_req_seen_r <= src_req_i;
            end
        end
    end

    always @(posedge dst_clk) begin
        if (dst_rst == `RstEnable) begin
            dst_req_toggle_sync1_r <= 1'b0;
            dst_req_toggle_sync2_r <= 1'b0;
            dst_req_toggle_seen_r <= 1'b0;
            dst_capture_pending_r <= 1'b0;
            dst_rsp_toggle_r <= 1'b0;
            dst_req_o <= `False;
            dst_we_o <= `False;
            dst_addr_o <= `ZeroWord;
            dst_wdata_o <= `ZeroWord;
            dst_wmask_o <= 4'b0;
            dst_rsp_rdata_r <= `ZeroWord;
        end else begin
            dst_req_toggle_sync1_r <= src_req_toggle_r;
            dst_req_toggle_sync2_r <= dst_req_toggle_sync1_r;

            if (dst_req_o == `False && dst_req_toggle_sync2_r != dst_req_toggle_seen_r) begin
                dst_req_toggle_seen_r <= dst_req_toggle_sync2_r;
                dst_capture_pending_r <= 1'b1;
            end else if (dst_capture_pending_r == 1'b1) begin
                dst_capture_pending_r <= 1'b0;
                dst_req_o <= `True;
                dst_we_o <= src_payload_we_r;
                dst_addr_o <= src_payload_addr_r;
                dst_wdata_o <= src_payload_wdata_r;
                dst_wmask_o <= src_payload_wmask_r;
            end else if (dst_req_o == `True && dst_ready_i == `True) begin
                dst_req_o <= `False;
                dst_rsp_rdata_r <= dst_rdata_i;
                dst_rsp_toggle_r <= ~dst_rsp_toggle_r;
            end
        end
    end

endmodule
