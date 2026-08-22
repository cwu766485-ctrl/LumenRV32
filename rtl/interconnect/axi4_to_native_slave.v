`timescale 1 ns / 1 ps
`include "../core/defines.v"

// AXI4 slave boundary for a simple req/ready memory device.
//
// AXI allows AW and W to arrive independently.  This bridge therefore stores
// either channel until both are present, then performs one native write.  The
// legacy implementation required same-cycle AW+W, which was incompatible with
// a legal crossbar that schedules address and data independently.
module axi4_to_native_slave(
    input wire clk, input wire rst,
    input wire[3:0] s_axi_awid, input wire[31:0] s_axi_awaddr, input wire[7:0] s_axi_awlen,
    input wire[2:0] s_axi_awsize, input wire[1:0] s_axi_awburst,
    input wire s_axi_awvalid, output reg s_axi_awready,
    input wire[31:0] s_axi_wdata, input wire[3:0] s_axi_wstrb,
    input wire s_axi_wlast, input wire s_axi_wvalid, output reg s_axi_wready,
    output reg[3:0] s_axi_bid, output reg[1:0] s_axi_bresp, output reg s_axi_bvalid, input wire s_axi_bready,
    input wire[3:0] s_axi_arid, input wire[31:0] s_axi_araddr, input wire[7:0] s_axi_arlen,
    input wire[2:0] s_axi_arsize, input wire[1:0] s_axi_arburst,
    input wire s_axi_arvalid, output reg s_axi_arready,
    output reg[3:0] s_axi_rid, output reg[31:0] s_axi_rdata, output reg[1:0] s_axi_rresp,
    output reg s_axi_rlast, output reg s_axi_rvalid, input wire s_axi_rready,
    output reg[`MemAddrBus] mem_addr_o, output reg[`MemBus] mem_wdata_o,
    output reg[`MemMaskBus] mem_wmask_o, output reg mem_req_o, output reg mem_we_o,
    input wire[`MemBus] mem_rdata_i, input wire mem_ready_i
);
    localparam IDLE = 2'd0, ACCESS = 2'd1, RESP = 2'd2;
    reg[1:0] state_r;
    reg write_r;
    reg[7:0] read_beats_left_r;
    reg aw_captured_r;
    reg w_captured_r;
    reg[31:0] awaddr_r;
    reg[3:0] awid_r;
    reg[3:0] arid_r;
    reg[31:0] wdata_r;
    reg[3:0] wstrb_r;

    // Do not start a read while an incomplete write is being assembled.  This
    // makes the simple native endpoint deterministic without violating AXI
    // channel independence or data stability rules.
    always @ (*) begin
        s_axi_awready = (state_r == IDLE) && !aw_captured_r;
        s_axi_wready = (state_r == IDLE) && !w_captured_r;
        s_axi_arready = (state_r == IDLE) && !aw_captured_r && !w_captured_r &&
                        !s_axi_awvalid && !s_axi_wvalid;
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state_r <= IDLE;
            write_r <= 1'b0;
            read_beats_left_r <= 8'd0;
            aw_captured_r <= 1'b0;
            w_captured_r <= 1'b0;
            awaddr_r <= `ZeroWord;
            awid_r <= 4'b0;
            arid_r <= 4'b0;
            s_axi_bid <= 4'b0;
            wdata_r <= `ZeroWord;
            wstrb_r <= 4'b0;
            s_axi_bresp <= 2'b00;
            s_axi_bvalid <= 1'b0;
            s_axi_rdata <= `ZeroWord;
            s_axi_rid <= 4'b0;
            s_axi_rresp <= 2'b00;
            s_axi_rlast <= 1'b0;
            s_axi_rvalid <= 1'b0;
            mem_addr_o <= `ZeroWord;
            mem_wdata_o <= `ZeroWord;
            mem_wmask_o <= 4'b0000;
            mem_req_o <= `False;
            mem_we_o <= `WriteDisable;
        end else begin
            case (state_r)
                IDLE: begin
                    mem_req_o <= `False;
                    mem_we_o <= `WriteDisable;

                    if (s_axi_awvalid && s_axi_awready) begin
                        aw_captured_r <= 1'b1;
                        awaddr_r <= s_axi_awaddr;
                        awid_r <= s_axi_awid;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        w_captured_r <= 1'b1;
                        wdata_r <= s_axi_wdata;
                        wstrb_r <= s_axi_wstrb;
                    end

                    // Use the incoming channel payload on its capture cycle,
                    // otherwise the registered payload from an earlier cycle.
                    if ((aw_captured_r || (s_axi_awvalid && s_axi_awready)) &&
                        (w_captured_r || (s_axi_wvalid && s_axi_wready))) begin
                        mem_addr_o <= aw_captured_r ? {4'h0, awaddr_r[27:0]} :
                                                      {4'h0, s_axi_awaddr[27:0]};
                        mem_wdata_o <= w_captured_r ? wdata_r : s_axi_wdata;
                        mem_wmask_o <= w_captured_r ? wstrb_r : s_axi_wstrb;
                        mem_we_o <= `WriteEnable;
                        mem_req_o <= `True;
                        write_r <= 1'b1;
                        s_axi_bid <= aw_captured_r ? awid_r : s_axi_awid;
                        aw_captured_r <= 1'b0;
                        w_captured_r <= 1'b0;
                        state_r <= ACCESS;
                    end else if (s_axi_arvalid && s_axi_arready) begin
                        mem_addr_o <= {4'h0, s_axi_araddr[27:0]};
                        mem_wdata_o <= `ZeroWord;
                        mem_wmask_o <= 4'b0000;
                        mem_we_o <= `WriteDisable;
                        mem_req_o <= `True;
                        write_r <= 1'b0;
                        arid_r <= s_axi_arid;
                        read_beats_left_r <= s_axi_arlen;
                        state_r <= ACCESS;
                    end
                end
                ACCESS: begin
                    if (mem_ready_i) begin
                        mem_req_o <= `False;
                        if (write_r) begin
                            s_axi_bresp <= 2'b00;
                            s_axi_bvalid <= 1'b1;
                        end else begin
                            s_axi_rdata <= mem_rdata_i;
                            s_axi_rid <= arid_r;
                            s_axi_rresp <= 2'b00;
                            s_axi_rlast <= (read_beats_left_r == 8'd0);
                            s_axi_rvalid <= 1'b1;
                        end
                        state_r <= RESP;
                    end
                end
                RESP: begin
                    if (write_r && s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        state_r <= IDLE;
                    end else if (!write_r && s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        s_axi_rlast <= 1'b0;
                        if (read_beats_left_r == 8'd0) begin
                            state_r <= IDLE;
                        end else begin
                            read_beats_left_r <= read_beats_left_r - 8'd1;
                            mem_addr_o <= mem_addr_o + 32'd4;
                            mem_req_o <= `True;
                            state_r <= ACCESS;
                        end
                    end
                end
                default: state_r <= IDLE;
            endcase
        end
    end
endmodule
