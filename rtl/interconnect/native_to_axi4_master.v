`timescale 1 ns / 1 ps

`include "../core/defines.v"

// Converts the existing req/ready native interface into a legal AXI4 master.
// CPU cache line fills may request a multi-beat read burst. Writes and the
// DMA/NPU/debug native paths remain single-beat.
module native_to_axi4_master(
    input wire clk,
    input wire rst,

    input wire[`MemAddrBus] native_addr_i,
    input wire[`MemBus] native_wdata_i,
    input wire[`MemMaskBus] native_wmask_i,
    input wire native_req_i,
    input wire native_we_i,
    input wire[7:0] native_burst_len_i,
    output reg[`MemBus] native_rdata_o,
    output reg native_ready_o,

    output reg[31:0] m_axi_awaddr,
    output wire[7:0] m_axi_awlen,
    output wire[2:0] m_axi_awsize,
    output wire[1:0] m_axi_awburst,
    output reg m_axi_awvalid,
    input wire m_axi_awready,

    output reg[31:0] m_axi_wdata,
    output reg[3:0] m_axi_wstrb,
    output wire m_axi_wlast,
    output reg m_axi_wvalid,
    input wire m_axi_wready,

    input wire[1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output reg m_axi_bready,

    output reg[31:0] m_axi_araddr,
    output wire[7:0] m_axi_arlen,
    output wire[2:0] m_axi_arsize,
    output wire[1:0] m_axi_arburst,
    output reg m_axi_arvalid,
    input wire m_axi_arready,

    input wire[31:0] m_axi_rdata,
    input wire[1:0] m_axi_rresp,
    input wire m_axi_rlast,
    input wire m_axi_rvalid,
    output reg m_axi_rready
);

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_WRITE_ADDR_DATA = 3'd1;
    localparam [2:0] ST_WRITE_RESP = 3'd2;
    localparam [2:0] ST_READ_ADDR = 3'd3;
    localparam [2:0] ST_READ_DATA = 3'd4;
    localparam [2:0] ST_COOLDOWN = 3'd5;

    reg[2:0] state_r;
    reg[7:0] read_burst_len_r;

    assign m_axi_awlen = 8'd0;
    assign m_axi_awsize = 3'd2;
    assign m_axi_awburst = 2'b01;
    assign m_axi_wlast = 1'b1;
    assign m_axi_arlen = read_burst_len_r;
    assign m_axi_arsize = 3'd2;
    assign m_axi_arburst = 2'b01;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state_r <= ST_IDLE;
            native_rdata_o <= `ZeroWord;
            native_ready_o <= `False;
            m_axi_awaddr <= `ZeroWord;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= `ZeroWord;
            m_axi_wstrb <= 4'h0;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b0;
            m_axi_araddr <= `ZeroWord;
            m_axi_arvalid <= 1'b0;
            m_axi_rready <= 1'b0;
            read_burst_len_r <= 8'd0;
        end else begin
            native_ready_o <= `False;

            case (state_r)
                ST_IDLE: begin
                    m_axi_bready <= 1'b0;
                    m_axi_rready <= 1'b0;
                    if (native_req_i == `True) begin
                        if (native_we_i == `WriteEnable) begin
                            m_axi_awaddr <= native_addr_i;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata <= native_wdata_i;
                            m_axi_wstrb <= native_wmask_i;
                            m_axi_wvalid <= 1'b1;
                            state_r <= ST_WRITE_ADDR_DATA;
                        end else begin
                            m_axi_araddr <= native_addr_i;
                            read_burst_len_r <= native_burst_len_i;
                            m_axi_arvalid <= 1'b1;
                            state_r <= ST_READ_ADDR;
                        end
                    end
                end
                ST_WRITE_ADDR_DATA: begin
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                    end
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                    end
                    if ((!m_axi_awvalid || m_axi_awready) &&
                        (!m_axi_wvalid || m_axi_wready)) begin
                        m_axi_bready <= 1'b1;
                        state_r <= ST_WRITE_RESP;
                    end
                end
                ST_WRITE_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        native_rdata_o <= {30'h0, m_axi_bresp};
                        native_ready_o <= `True;
                        m_axi_bready <= 1'b0;
                        state_r <= ST_COOLDOWN;
                    end
                end
                ST_READ_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready <= 1'b1;
                        state_r <= ST_READ_DATA;
                    end
                end
                ST_READ_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        native_rdata_o <= m_axi_rdata;
                        native_ready_o <= `True;
                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0;
                            state_r <= ST_COOLDOWN;
                        end
                    end
                end
                // The native requester consumes ready on this edge and updates
                // or drops its request. Waiting one cycle lets an identical
                // back-to-back transaction be distinguished from the completed
                // request without submitting the old request twice.
                ST_COOLDOWN: begin
                    state_r <= ST_IDLE;
                end
                default: state_r <= ST_IDLE;
            endcase
        end
    end

endmodule
