`timescale 1ns/1ps
module tb_csi_monitor #(parameter WIDTH=1024, HEIGHT=600);
localparam [15:0] RAW_BYTES=WIDTH*5/4;
reg clk=0,refclk=0,rst=0,hs=0; reg [15:0] data=0;
always #5 clk=~clk; always #7 refclk=~refclk;
wire fs,fe,cv,rs,re,rv;wire [31:0] cd;wire [39:0] rd;
wire [15:0] w,h,le,err,fps,gap;wire [31:0] uptime,frames;
csi_unpacket_2lane csi(.I_clk(clk),.I_rst_n(rst),.I_hs_valid(hs),.I_hs_data(data),.O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(cv),.O_csi_data(cd));
raw10_unpacket_2lane raw(.I_clk(clk),.I_rst_n(rst),.I_csi_frame_start(fs),.I_csi_frame_end(fe),.I_csi_valid(cv),.I_csi_data(cd),.I_camera_black_level(10'd0),.O_raw10_frame_start(rs),.O_raw10_frame_end(re),.O_raw10_valid(rv),.O_raw10_data(rd));
input_monitor #(.REF_HZ(1000000),.EXPECTED_WIDTH(WIDTH),.EXPECTED_HEIGHT(HEIGHT)) mon(clk,refclk,rst,rs,re,hs,rv,2'b0,w,h,le,err,fps,gap,uptime,frames);
task ticks; input integer n; begin repeat(n) @(negedge clk); end endtask
task short_packet; input [7:0] dt; begin hs=1;data={dt,8'd0};ticks(1);data=0;ticks(1);hs=0;ticks(40);end endtask
integer row,i;
initial begin
 ticks(8);rst=1;ticks(30);short_packet(0);
 for(row=0;row<HEIGHT;row=row+1) begin
  // CSI header bytes: DT, WC-low, WC-high, ECC (unused by this decoder).
  hs=1;data={8'h2b,RAW_BYTES[7:0]};ticks(1);data={RAW_BYTES[15:8],8'h00};ticks(1);
  for(i=0;i<WIDTH*5/8;i=i+1) begin data=i;ticks(1);end
  data=0;ticks(1);hs=0;ticks(40);
 end
 short_packet(1);ticks(100);
 if(w!=WIDTH || h!=HEIGHT || err!=0 || frames!=1) $fatal(1,"actual CSI pipeline: %d x %d errors %d frames %d",w,h,err,frames);
 $display("PASS actual CSI and RAW10 decoder feeding monitor: %0d x %0d",WIDTH,HEIGHT);$finish;
end
endmodule
