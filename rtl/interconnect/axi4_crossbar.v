`timescale 1 ns / 1 ps
`include "../core/defines.v"

// Four-master/four-slave AXI4 crossbar, ID-aware Stage B/C implementation.
// Outgoing ID[3:0] = {master_index[1:0], 1'b0, local_id[0]}.  The master
// prefix gives every initiator an independent ID namespace.  Write data is
// serialized in AW acceptance order per slave (AXI4 has no WID); AR requests
// may be issued independently and R/B return through their decoded IDs.
module axi4_crossbar(
    input wire clk, input wire rst,
    input wire[3:0] s_axi_awid, input wire[127:0] s_axi_awaddr, input wire[31:0] s_axi_awlen,
    input wire[11:0] s_axi_awsize, input wire[7:0] s_axi_awburst, input wire[3:0] s_axi_awvalid,
    output reg[3:0] s_axi_awready, input wire[127:0] s_axi_wdata, input wire[15:0] s_axi_wstrb,
    input wire[3:0] s_axi_wlast, input wire[3:0] s_axi_wvalid, output reg[3:0] s_axi_wready,
    output reg[3:0] s_axi_bid, output reg[7:0] s_axi_bresp, output reg[3:0] s_axi_bvalid,
    input wire[3:0] s_axi_bready,
    input wire[3:0] s_axi_arid, input wire[127:0] s_axi_araddr, input wire[31:0] s_axi_arlen,
    input wire[11:0] s_axi_arsize, input wire[7:0] s_axi_arburst, input wire[3:0] s_axi_arvalid,
    output reg[3:0] s_axi_arready, output reg[3:0] s_axi_rid, output reg[127:0] s_axi_rdata,
    output reg[7:0] s_axi_rresp, output reg[3:0] s_axi_rlast, output reg[3:0] s_axi_rvalid,
    input wire[3:0] s_axi_rready,

    output reg[15:0] m_axi_awid, output reg[127:0] m_axi_awaddr, output reg[31:0] m_axi_awlen,
    output reg[11:0] m_axi_awsize, output reg[7:0] m_axi_awburst, output reg[3:0] m_axi_awvalid,
    input wire[3:0] m_axi_awready, output reg[127:0] m_axi_wdata, output reg[15:0] m_axi_wstrb,
    output reg[3:0] m_axi_wlast, output reg[3:0] m_axi_wvalid, input wire[3:0] m_axi_wready,
    input wire[15:0] m_axi_bid, input wire[7:0] m_axi_bresp, input wire[3:0] m_axi_bvalid,
    output reg[3:0] m_axi_bready,
    output reg[15:0] m_axi_arid, output reg[127:0] m_axi_araddr, output reg[31:0] m_axi_arlen,
    output reg[11:0] m_axi_arsize, output reg[7:0] m_axi_arburst, output reg[3:0] m_axi_arvalid,
    input wire[3:0] m_axi_arready, input wire[15:0] m_axi_rid, input wire[127:0] m_axi_rdata,
    input wire[7:0] m_axi_rresp, input wire[3:0] m_axi_rlast, input wire[3:0] m_axi_rvalid,
    output reg[3:0] m_axi_rready,
    output reg[1:0] active_master_o, output reg[1:0] active_slave_o, output reg busy_o
);
    // One write credit per master (AXI4 W channel has no WID); two read
    // credits per master, selected by the initiator's local ID bit.
    reg[3:0] wr_busy_r;
    reg[7:0] rd_busy_r;
    reg[1:0] rr_wr_r[0:3], rr_rd_r[0:3];
    reg[1:0] wq_owner[0:3][0:3];
    reg[1:0] wq_head[0:3], wq_tail[0:3];
    reg[2:0] wq_count[0:3];
    reg aw_sel_valid[0:3], ar_sel_valid[0:3];
    reg[1:0] aw_sel_owner[0:3], ar_sel_owner[0:3];
    reg w_pop[0:3];
    integer slot, offset, candidate, entry;

    // Legacy debug fields retained for existing waveform consumers.
    reg[1:0] state_r, owner_r, target_r;
    reg[1:0] bresp_r, rresp_r;
    reg bvalid_r, aw_done_r, w_done_r, rlast_r, rvalid_r;
    reg[31:0] rdata_r;
    localparam ST_IDLE=2'd0, ST_WRITE=2'd1, ST_READ=2'd2;

    function [1:0] target_of;
        input [31:0] addr;
        begin target_of = addr[29:28]; end
    endfunction

    always @(*) begin
        for (slot=0; slot<4; slot=slot+1) begin
            aw_sel_valid[slot]=1'b0; aw_sel_owner[slot]=2'd0;
            ar_sel_valid[slot]=1'b0; ar_sel_owner[slot]=2'd0;
            if (wq_count[slot] < 4) begin
                for (offset=0; offset<4; offset=offset+1) begin
                    candidate=(rr_wr_r[slot]+offset)&3;
                    if (!aw_sel_valid[slot] && s_axi_awvalid[candidate] && !wr_busy_r[candidate] &&
                        target_of(s_axi_awaddr[candidate*32 +: 32])==slot[1:0]) begin
                        aw_sel_valid[slot]=1'b1; aw_sel_owner[slot]=candidate[1:0];
                    end
                end
            end
            for (offset=0; offset<4; offset=offset+1) begin
                candidate=(rr_rd_r[slot]+offset)&3;
                if (!ar_sel_valid[slot] && s_axi_arvalid[candidate] &&
                    !rd_busy_r[{candidate[1:0],s_axi_arid[candidate]}] &&
                    target_of(s_axi_araddr[candidate*32 +: 32])==slot[1:0]) begin
                    ar_sel_valid[slot]=1'b1; ar_sel_owner[slot]=candidate[1:0];
                end
            end
            w_pop[slot]=(wq_count[slot]!=0) && s_axi_wvalid[wq_owner[slot][wq_head[slot]]] &&
                        m_axi_wready[slot] && s_axi_wlast[wq_owner[slot][wq_head[slot]]];
        end
    end

    always @(*) begin
        s_axi_awready=0; s_axi_wready=0; s_axi_bid=0; s_axi_bresp=0; s_axi_bvalid=0;
        s_axi_arready=0; s_axi_rid=0; s_axi_rdata=0; s_axi_rresp=0; s_axi_rlast=0; s_axi_rvalid=0;
        m_axi_awid=0; m_axi_awaddr=0; m_axi_awlen=0; m_axi_awsize=0; m_axi_awburst=0; m_axi_awvalid=0;
        m_axi_wdata=0; m_axi_wstrb=0; m_axi_wlast=0; m_axi_wvalid=0; m_axi_bready=0;
        m_axi_arid=0; m_axi_araddr=0; m_axi_arlen=0; m_axi_arsize=0; m_axi_arburst=0; m_axi_arvalid=0; m_axi_rready=0;
        for (slot=0; slot<4; slot=slot+1) begin
            if (aw_sel_valid[slot]) begin
                m_axi_awid[slot*4 +: 4]={aw_sel_owner[slot],1'b0,s_axi_awid[aw_sel_owner[slot]]};
                m_axi_awaddr[slot*32 +:32]=s_axi_awaddr[aw_sel_owner[slot]*32 +:32];
                m_axi_awlen[slot*8 +:8]=s_axi_awlen[aw_sel_owner[slot]*8 +:8];
                m_axi_awsize[slot*3 +:3]=s_axi_awsize[aw_sel_owner[slot]*3 +:3];
                m_axi_awburst[slot*2 +:2]=s_axi_awburst[aw_sel_owner[slot]*2 +:2];
                m_axi_awvalid[slot]=1'b1; s_axi_awready[aw_sel_owner[slot]]=m_axi_awready[slot];
            end
            if (wq_count[slot]!=0) begin
                m_axi_wdata[slot*32 +:32]=s_axi_wdata[wq_owner[slot][wq_head[slot]]*32 +:32];
                m_axi_wstrb[slot*4 +:4]=s_axi_wstrb[wq_owner[slot][wq_head[slot]]*4 +:4];
                m_axi_wlast[slot]=s_axi_wlast[wq_owner[slot][wq_head[slot]]];
                m_axi_wvalid[slot]=s_axi_wvalid[wq_owner[slot][wq_head[slot]]];
                s_axi_wready[wq_owner[slot][wq_head[slot]]]=m_axi_wready[slot];
            end
            if (ar_sel_valid[slot]) begin
                m_axi_arid[slot*4 +:4]={ar_sel_owner[slot],1'b0,s_axi_arid[ar_sel_owner[slot]]};
                m_axi_araddr[slot*32 +:32]=s_axi_araddr[ar_sel_owner[slot]*32 +:32];
                m_axi_arlen[slot*8 +:8]=s_axi_arlen[ar_sel_owner[slot]*8 +:8];
                m_axi_arsize[slot*3 +:3]=s_axi_arsize[ar_sel_owner[slot]*3 +:3];
                m_axi_arburst[slot*2 +:2]=s_axi_arburst[ar_sel_owner[slot]*2 +:2];
                m_axi_arvalid[slot]=1'b1; s_axi_arready[ar_sel_owner[slot]]=m_axi_arready[slot];
            end
            if (m_axi_bvalid[slot] && wr_busy_r[m_axi_bid[slot*4+3 -:2]]) begin
                s_axi_bid[m_axi_bid[slot*4+3 -:2]]=m_axi_bid[slot*4];
                s_axi_bresp[m_axi_bid[slot*4+3 -:2]*2 +:2]=m_axi_bresp[slot*2 +:2];
                s_axi_bvalid[m_axi_bid[slot*4+3 -:2]]=1'b1;
                m_axi_bready[slot]=s_axi_bready[m_axi_bid[slot*4+3 -:2]];
            end
            if (m_axi_rvalid[slot] && rd_busy_r[{m_axi_rid[slot*4+3 -:2],m_axi_rid[slot*4]}]) begin
                s_axi_rid[m_axi_rid[slot*4+3 -:2]]=m_axi_rid[slot*4];
                s_axi_rdata[m_axi_rid[slot*4+3 -:2]*32 +:32]=m_axi_rdata[slot*32 +:32];
                s_axi_rresp[m_axi_rid[slot*4+3 -:2]*2 +:2]=m_axi_rresp[slot*2 +:2];
                s_axi_rlast[m_axi_rid[slot*4+3 -:2]]=m_axi_rlast[slot];
                s_axi_rvalid[m_axi_rid[slot*4+3 -:2]]=1'b1;
                m_axi_rready[slot]=s_axi_rready[m_axi_rid[slot*4+3 -:2]];
            end
        end
    end

    always @(posedge clk) begin
        if (rst==`RstEnable) begin
            wr_busy_r<=0; rd_busy_r<=0;
            for(slot=0;slot<4;slot=slot+1) begin
                rr_wr_r[slot]<=0; rr_rd_r[slot]<=0; wq_head[slot]<=0; wq_tail[slot]<=0; wq_count[slot]<=0;
                for(entry=0;entry<4;entry=entry+1) wq_owner[slot][entry]<=0;
            end
        end else begin
            for(slot=0;slot<4;slot=slot+1) begin
                if (aw_sel_valid[slot] && m_axi_awready[slot]) begin
                    wq_owner[slot][wq_tail[slot]]<=aw_sel_owner[slot];
                    wq_tail[slot]<=wq_tail[slot]+1'b1;
                    rr_wr_r[slot]<=aw_sel_owner[slot]+1'b1;
                    wr_busy_r[aw_sel_owner[slot]]<=1'b1;
                end
                if (ar_sel_valid[slot] && m_axi_arready[slot]) begin
                    rr_rd_r[slot]<=ar_sel_owner[slot]+1'b1;
                    rd_busy_r[{ar_sel_owner[slot],s_axi_arid[ar_sel_owner[slot]]}]<=1'b1;
                end
                case ({(aw_sel_valid[slot] && m_axi_awready[slot]),w_pop[slot]})
                    2'b10: wq_count[slot]<=wq_count[slot]+1'b1;
                    2'b01: begin wq_count[slot]<=wq_count[slot]-1'b1; wq_head[slot]<=wq_head[slot]+1'b1; end
                    2'b11: wq_head[slot]<=wq_head[slot]+1'b1;
                    default: ;
                endcase
                if (m_axi_bvalid[slot] && m_axi_bready[slot]) wr_busy_r[m_axi_bid[slot*4+3 -:2]]<=1'b0;
                if (m_axi_rvalid[slot] && m_axi_rready[slot] && m_axi_rlast[slot]) rd_busy_r[{m_axi_rid[slot*4+3 -:2],m_axi_rid[slot*4]}]<=1'b0;
            end
        end
    end

    always @(*) begin
        state_r=ST_IDLE; owner_r=0; target_r=0; active_master_o=0; active_slave_o=0; busy_o=0;
        bresp_r=0; bvalid_r=0; aw_done_r=0; w_done_r=0; rdata_r=0; rresp_r=0; rlast_r=0; rvalid_r=0;
        for(slot=0;slot<4;slot=slot+1) begin
            if (!busy_o && wq_count[slot]!=0) begin state_r=ST_WRITE; owner_r=wq_owner[slot][wq_head[slot]]; target_r=slot[1:0]; active_master_o=owner_r; active_slave_o=target_r; busy_o=1; aw_done_r=1; w_done_r=w_pop[slot]; end
            if (!busy_o && m_axi_rvalid[slot]) begin state_r=ST_READ; owner_r=m_axi_rid[slot*4+3 -:2]; target_r=slot[1:0]; active_master_o=owner_r; active_slave_o=target_r; busy_o=1; rdata_r=m_axi_rdata[slot*32 +:32]; rresp_r=m_axi_rresp[slot*2 +:2]; rlast_r=m_axi_rlast[slot]; rvalid_r=1; end
        end
    end
endmodule
