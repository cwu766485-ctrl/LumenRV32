`timescale 1ns/1ps
`include "../rtl/core/defines.v"

// ID scoreboard for Stage B/C.  Four masters issue to DDR concurrently; the
// model returns R and B in reverse master order.  Master 0 uses a two-beat
// burst to prove same-ID ordering while different IDs complete out of order.
module axi4_crossbar_stage_a_tb;
reg clk=0,rst=`RstEnable;
reg[3:0] sawid=0,sarid=0,sawv=0,swv=0,sarv=0,sbr=4'hf,srr=4'hf,swlast=0;
reg[127:0] sawa=0,swdata=0,sara=0; reg[31:0] sawlen=0,sarlen=0; reg[11:0] sawsize={4{3'd2}},sarsize={4{3'd2}}; reg[7:0] sawburst={4{2'b01}},sarburst={4{2'b01}}; reg[15:0] swstrb={4{4'hf}};
wire[3:0] sawr,swr,sbid,sbv,sarr,srid,srl,srv; wire[7:0] sbrsp,srrsp; wire[127:0] srdata;
wire[15:0] mawid,marid; wire[127:0] mawa,mwda,mara; wire[31:0] mawlen,marlen; wire[11:0] mawsize,marsize; wire[7:0] mawburst,marburst; wire[3:0] mawv,mwv,m_bready,mav,m_rready,mwlast; wire[15:0] mwstrb; wire[7:0] mbrsp,mrrsp;
reg[3:0] mawr=4'b1000,mwr=4'b1000,mbv_i=0,marr=4'b1000,mrv_i=0,mrl_i=0; reg[15:0] mbid=0,mrid=0; reg[127:0] mrdata=0; reg[7:0] mbresp=0,mrresp=0;
reg[3:0] rd_pending=0,wr_pending=0; reg rd_response_started=0,wr_response_started=0; reg[1:0] rd_beats[0:3]; reg[3:0] aw_fifo[0:3]; reg[1:0] awh=0,awt=0,awc=0; integer i,cyc; reg[3:0] rseen=0,bseen=0; reg[1:0] r0_count=0; integer o;

axi4_crossbar dut(.clk(clk),.rst(rst),.s_axi_awid(sawid),.s_axi_awaddr(sawa),.s_axi_awlen(sawlen),.s_axi_awsize(sawsize),.s_axi_awburst(sawburst),.s_axi_awvalid(sawv),.s_axi_awready(sawr),.s_axi_wdata(swdata),.s_axi_wstrb(swstrb),.s_axi_wlast(swlast),.s_axi_wvalid(swv),.s_axi_wready(swr),.s_axi_bid(sbid),.s_axi_bresp(sbrsp),.s_axi_bvalid(sbv),.s_axi_bready(sbr),.s_axi_arid(sarid),.s_axi_araddr(sara),.s_axi_arlen(sarlen),.s_axi_arsize(sarsize),.s_axi_arburst(sarburst),.s_axi_arvalid(sarv),.s_axi_arready(sarr),.s_axi_rid(srid),.s_axi_rdata(srdata),.s_axi_rresp(srrsp),.s_axi_rlast(srl),.s_axi_rvalid(srv),.s_axi_rready(srr),.m_axi_awid(mawid),.m_axi_awaddr(mawa),.m_axi_awlen(mawlen),.m_axi_awsize(mawsize),.m_axi_awburst(mawburst),.m_axi_awvalid(mawv),.m_axi_awready(mawr),.m_axi_wdata(mwda),.m_axi_wstrb(mwstrb),.m_axi_wlast(mwlast),.m_axi_wvalid(mwv),.m_axi_wready(mwr),.m_axi_bid(mbid),.m_axi_bresp(mbresp),.m_axi_bvalid(mbv_i),.m_axi_bready(m_bready),.m_axi_arid(marid),.m_axi_araddr(mara),.m_axi_arlen(marlen),.m_axi_arsize(marsize),.m_axi_arburst(marburst),.m_axi_arvalid(mav),.m_axi_arready(marr),.m_axi_rid(mrid),.m_axi_rdata(mrdata),.m_axi_rresp(mrresp),.m_axi_rlast(mrl_i),.m_axi_rvalid(mrv_i),.m_axi_rready(m_rready));
always #5 clk=~clk;
always @(posedge clk) begin
 if(rst==`RstEnable) begin rd_pending<=0;wr_pending<=0;rd_response_started<=0;wr_response_started<=0;mbv_i<=0;mrv_i<=0;mrl_i<=0;awc<=0;awh<=0;awt<=0;cyc<=0; for(i=0;i<4;i=i+1) rd_beats[i]<=0; end else begin
  cyc<=cyc+1;
  if(mav[3]&&marr[3]) begin rd_pending[marid[15:14]]<=1; rd_beats[marid[15:14]]<=marlen[31:24]+1; end
  if(mawv[3]&&mawr[3]) begin aw_fifo[awt]<=mawid[15:12]; awt<=awt+1; awc<=awc+1; end
  if(mwv[3]&&mwr[3]&&mwlast[3]) begin wr_pending[aw_fifo[awh][3:2]]<=1; awh<=awh+1; awc<=awc-1; end
  if(rd_pending==4'hf) rd_response_started<=1;
  if(!mrv_i[3] && rd_response_started) begin
   if(rd_pending[3]) begin mrid[15:12]<=4'hc; mrdata[127:96]<=32'hD000_0300+rd_beats[3]; mrresp[7:6]<=0; mrl_i[3]<=rd_beats[3]==1; mrv_i[3]<=1; end
   else if(rd_pending[2]) begin mrid[15:12]<=4'h8; mrdata[127:96]<=32'hD000_0200+rd_beats[2]; mrresp[7:6]<=0; mrl_i[3]<=rd_beats[2]==1; mrv_i[3]<=1; end
   else if(rd_pending[1]) begin mrid[15:12]<=4'h4; mrdata[127:96]<=32'hD000_0100+rd_beats[1]; mrresp[7:6]<=0; mrl_i[3]<=rd_beats[1]==1; mrv_i[3]<=1; end
   else if(rd_pending[0]) begin mrid[15:12]<=4'h0; mrdata[127:96]<=32'hD000_0000+rd_beats[0]; mrresp[7:6]<=0; mrl_i[3]<=rd_beats[0]==1; mrv_i[3]<=1; end
  end
  else if(mrv_i[3]&&m_rready[3]) begin mrv_i[3]<=0; if(mrl_i[3]) rd_pending[mrid[15:14]]<=0; else rd_beats[mrid[15:14]]<=rd_beats[mrid[15:14]]-1; end
  if(wr_pending==4'hf) wr_response_started<=1;
  if(!mbv_i[3] && wr_response_started) begin
   if(wr_pending[3]) begin mbid[15:12]<=4'hc; mbresp[7:6]<=0; mbv_i[3]<=1; end
   else if(wr_pending[2]) begin mbid[15:12]<=4'h8; mbresp[7:6]<=0; mbv_i[3]<=1; end
   else if(wr_pending[1]) begin mbid[15:12]<=4'h4; mbresp[7:6]<=0; mbv_i[3]<=1; end
   else if(wr_pending[0]) begin mbid[15:12]<=4'h0; mbresp[7:6]<=0; mbv_i[3]<=1; end
  end
  else if(mbv_i[3]&&m_bready[3]) begin mbv_i[3]<=0; wr_pending[mbid[15:14]]<=0; end
  for(i=0;i<4;i=i+1) begin if(srv[i]&&srr[i]) begin if(srid[i]!==1'b0||srrsp[i*2+:2]!==0) begin $display("AXI_ID_FAIL bad R ID/RESP");$finish(1);end if(i==0) begin if((r0_count==0&&srl[i])||(r0_count==1&&!srl[i])||(r0_count>1)) begin $display("AXI_ID_FAIL same-ID R ordering");$finish(1);end r0_count<=r0_count+1;end if(srl[i]) rseen[i]<=1; end if(sbv[i]&&sbr[i]) begin if(sbid[i]!==1'b0||sbrsp[i*2+:2]!==0) begin $display("AXI_ID_FAIL bad B ID/RESP");$finish(1);end bseen[i]<=1;end end
  if(cyc>400) begin $display("AXI_ID_TIMEOUT rseen=%b bseen=%b arv=%b awv=%b wv=%b rd=%b wr=%b q=%0d mrv=%b mrid=%h rready=%b dutrd=%b dutwr=%b q3=%0d h=%0d t=%0d o0=%0d o1=%0d o2=%0d o3=%0d swr=%b",rseen,bseen,sarv,sawv,swv,rd_pending,wr_pending,awc,mrv_i,mrid,m_rready,dut.rd_busy_r,dut.wr_busy_r,dut.wq_count[3],dut.wq_head[3],dut.wq_tail[3],dut.wq_owner[3][0],dut.wq_owner[3][1],dut.wq_owner[3][2],dut.wq_owner[3][3],swr);$finish(1);end
 end
end
always @(posedge clk) if(rst==`RstDisable) begin for(i=0;i<4;i=i+1) begin if(sawv[i]&&sawr[i]) sawv[i]<=0; if(swv[i]&&swr[i]) swv[i]<=0; if(sarv[i]&&sarr[i]) sarv[i]<=0; end end
initial begin repeat(5)@(posedge clk);rst=`RstDisable; @(negedge clk); sara[31:0]=32'h30000000;sara[63:32]=32'h30000004;sara[95:64]=32'h30000008;sara[127:96]=32'h3000000c;sarlen[7:0]=1;sarv=4'hf; wait(rseen==4'hf); if(r0_count!=2) begin $display("AXI_ID_FAIL same-ID burst incomplete");$finish(1);end @(negedge clk);sawa[31:0]=32'h30000100;sawa[63:32]=32'h30000104;sawa[95:64]=32'h30000108;sawa[127:96]=32'h3000010c;swdata=128'h4444_0003_3333_0002_2222_0001_1111_0000;swlast=4'hf;sawv=4'hf;swv=4'hf;wait(bseen==4'hf);$display("AXI4_XBAR_STAGE_BC_PASS R_OOO=1 B_OOO=1 SAME_ID_ORDER=PASS");$finish;end
endmodule
