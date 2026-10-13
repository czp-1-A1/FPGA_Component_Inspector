`timescale 1ns/1ps
// Diagnostic only: actual Sobel, packing, video_in and generated FIFO.
// DDR read arbitration is a legal 240-ready-transfer busy interval, followed
// by a long idle interval. PHY/DDR electrical behavior is not represented.
module tb_ddr_full_tailgap;
localparam W=1024,H=600;
reg cam=0,ddr=0,rst=0,pv=0,sof=0,last=0,early=0;
reg [95:0] rgb=0;
always #4.444 cam=~cam;
always #7.5 ddr=~ddr;
wire ov,ol,oe;wire [95:0] color;
roi_sobel_view_tailgap #(.WIDTH(W),.HEIGHT(H)) view(.clk(cam),.rst_n(rst),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(early),.rgb(rgb),.mode(2'd0),.invalidate(1'b0),.out_valid(ov),.out_last(ol),.out_early_sof(oe),.out_rgb(color),.out_x(),.out_y(),.core_pixels(),.edge_count(),.edge_sum());
reg bypass=0;
wire ps,pvalid;wire [127:0] pdata;
data_96bit_to_128bit pack(cam,rst,bypass?early:oe,bypass?pv:ov,bypass?rgb:color,ps,pvalid,pdata);
wire wrbusy,wren;wire [1:0] rp;wire [24:0] addr;wire [127:0] data;
reg rdbusy=0,ready=1;
video_in vi(rst,cam,ps,pvalid,pdata,1'b0,ddr,1'b0,rdbusy,wrbusy,rp,wren,addr,data,ready);
integer fifo_peak=0,dropped=0,written=0,produced=0,mismatches=0;
integer cycle=0,read_transfers=0,rd_wait=0,read_starts=0;
integer row_gap=512,stall=0,trigger=190,read_runs=1;
integer armed=1,y,x,n,id=0;
reg [127:0] expected[0:W*H*3/16-1];
always @(posedge cam) begin
 if(pvalid) begin expected[produced]=pdata;produced=produced+1;end
 if(vi.U_w128_d512_fifo.full_flag && pvalid) dropped=dropped+1;
 if(vi.U_w128_d512_fifo.wrusedw>fifo_peak) fifo_peak=vi.U_w128_d512_fifo.wrusedw;
end
always @(posedge ddr) if(rst) begin
 cycle=cycle+1;
 if(wren) begin
  if(data!==expected[written]) begin
   if(mismatches<3) $display("MISMATCH word=%0d addr=%0d got=%h expected=%h",written,addr,data,expected[written]);
   mismatches=mismatches+1;
  end
  written=written+1;
 end
 // Begin only when writer is idle, as the real video_out requires. The
 // duration is exactly 240 accepted DDR commands; ready stalls are finite.
 if(!rdbusy && !wrbusy && armed && produced>=(H-3)*192 && vi.S_fifo_rd_num>=trigger) begin
  rdbusy<=1;read_starts=read_starts+1;read_transfers=0;rd_wait=stall;armed=0;
 end
 if(rdbusy) begin
  if(rd_wait>0) begin ready<=0;rd_wait=rd_wait-1;end
  else begin ready<=1;
   if(ready) begin read_transfers=read_transfers+1;
    if(read_transfers==240) begin rdbusy<=0;ready<=1;end
   end
  end
 end
end
task ticks;input integer n;begin repeat(n) @(negedge cam);end endtask
initial begin
 if(!$value$plusargs("GAP=%d",row_gap)) row_gap=512;
 if(!$value$plusargs("STALL=%d",stall)) stall=0;
 if(!$value$plusargs("TRIGGER=%d",trigger)) trigger=190;
 if(!$value$plusargs("BYPASS=%d",bypass)) bypass=0;
 ticks(8);rst=1;ticks(8);early=1;ticks(1);early=0;ticks(50);
 for(y=0;y<H;y=y+1) begin
  for(x=0;x<W;x=x+4) begin
   for(n=0;n<4;n=n+1) rgb[95-n*24-:24]=(y*W+x+n);
   pv=1;sof=y==0 && x==0;last=x==W-4;ticks(1);
  end
  pv=0;sof=0;last=0;ticks(row_gap);
 end
 ticks(6000);
 $display("CAPACITY RAW bypass=%0d gap=%0d stall=%0d trigger=%0d produced=%0d written=%0d expected=%0d peak=%0d dropped=%0d mismatches=%0d readstarts=%0d",bypass,row_gap,stall,trigger,produced,written,W*H*3/16,fifo_peak,dropped,mismatches,read_starts);
 $finish;
end
endmodule
