`timescale 1ns/1ps
module tb_csi_monitor;
reg clk=0,refclk=0,rst=0,hs=0; reg [15:0] data=0;
always #5 clk=~clk; always #7 refclk=~refclk;
wire fs,fe,cv,rs,re,rv;wire [31:0] cd;wire [39:0] rd;
wire [15:0] w,h,le,err,fps,gap;wire [31:0] uptime,frames;
csi_unpacket_2lane csi(.I_clk(clk),.I_rst_n(rst),.I_hs_valid(hs),.I_hs_data(data),.O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(cv),.O_csi_data(cd));
raw10_unpacket_2lane raw(.I_clk(clk),.I_rst_n(rst),.I_csi_frame_start(fs),.I_csi_frame_end(fe),.I_csi_valid(cv),.I_csi_data(cd),.I_camera_black_level(10'd0),.O_raw10_frame_start(rs),.O_raw10_frame_end(re),.O_raw10_valid(rv),.O_raw10_data(rd));
input_monitor #(.REF_HZ(1000000)) mon(clk,refclk,rst,rs,re,hs,rv,2'b0,w,h,le,err,fps,gap,uptime,frames);
task ticks; input integer n; begin repeat(n) @(negedge clk); end endtask
task short_packet; input [7:0] dt; begin hs=1;data={dt,8'd0};ticks(1);data=0;ticks(1);hs=0;ticks(40);end endtask
integer row,i;
initial begin
 ticks(8);rst=1;ticks(30);short_packet(0);
 for(row=0;row<600;row=row+1) begin
  hs=1;data=16'h2b00;ticks(1);data=16'h0500;ticks(1);
  for(i=0;i<640;i=i+1) begin data=i;ticks(1);end
  data=0;ticks(1);hs=0;ticks(40);
 end
 short_packet(1);ticks(100);
 if(w!=1024 || h!=600 || err!=0) $fatal(1,"actual CSI pipeline: %d x %d errors %d",w,h,err);
 $display("PASS actual CSI and RAW10 decoder feeding monitor: 1024 x 600");$finish;
end
endmodule
