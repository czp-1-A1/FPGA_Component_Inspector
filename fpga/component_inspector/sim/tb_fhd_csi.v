`timescale 1ns/1ps
// Oracle: standard five-byte RAW10 groups. No expected values come from RTL.
module tb_fhd_csi;
reg clk=0,refclk=0,rst=0,hs=0;reg [15:0] data=0;
always #5 clk=~clk;always #7 refclk=~refclk;
wire fs,fe,cv,rs,re,rv;wire [31:0] cd;wire [39:0] rd;
wire [15:0] w,h,le,err,fps,gap;wire [31:0] uptime,frames;
csi_unpacket_2lane csi(.I_clk(clk),.I_rst_n(rst),.I_hs_valid(hs),.I_hs_data(data),
 .O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(cv),.O_csi_data(cd));
raw10_unpacket_2lane raw(clk,rst,fs,fe,cv,cd,10'd0,rs,re,rv,rd);
input_monitor #(.WIDTH(1920),.HEIGHT(1080),.REF_HZ(1000000)) mon(clk,refclk,rst,rs,re,hs,rv,2'b0,w,h,le,err,fps,gap,uptime,frames);
function integer pixel(input integer index);pixel=(index*13+index/1920*7+19)%1024;endfunction
reg [7:0] bytes[0:2399];integer row,b,k,p,count=0;
always @(posedge clk) if(rv)begin
 for(integer j=0;j<4;j=j+1)
  if(rd[j*10+:10]!==10'(pixel(count+j)))$fatal(1,"RAW order/value index=%0d got=%0d expected=%0d",count+j,rd[j*10+:10],pixel(count+j));
 count=count+4;
end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task short_packet(input [7:0] dt);begin hs=1;data={dt,8'd0};ticks(1);data=0;ticks(1);hs=0;ticks(40);end endtask
initial begin
 ticks(8);rst=1;ticks(30);short_packet(0);
 for(row=0;row<1080;row=row+1)begin
  for(b=0;b<480;b=b+1)begin
   for(k=0;k<4;k=k+1)bytes[b*5+k]=pixel(row*1920+b*4+k)>>2;
   bytes[b*5+4]={2'(pixel(row*1920+b*4+3)),2'(pixel(row*1920+b*4+2)),2'(pixel(row*1920+b*4+1)),2'(pixel(row*1920+b*4))};
  end
  hs=1;data=16'h2b60;ticks(1);data=16'h0900;ticks(1);
  for(b=0;b<2400;b=b+2)begin data={bytes[b],bytes[b+1]};ticks(1);end
  data=0;ticks(1);hs=0;ticks(40);
  if(count!=(row+1)*1920)$fatal(1,"RAW line count row=%0d count=%0d",row,count);
 end
 short_packet(1);ticks(100);
 if(count!=2073600 || w!=1920 || h!=1080 || err!=0)$fatal(1,"FHD decode/monitor count=%0d %dx%d err=%0d",count,w,h,err);
 $display("PASS FHD CSI: 2400 bytes/line, 1920 pixels, 1080 lines, every RAW10 pixel/order/boundary, measured 1920x1080");$finish;
end
initial begin #20000000;$fatal(1,"FHD CSI timeout");end
endmodule
