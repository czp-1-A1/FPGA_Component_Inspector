`timescale 1ns/1ps
// Independent CSI RAW10 byte packing and every decoded pixel, before the ISP.
module tb_csi_pixels;
localparam WIDTH=1920,HEIGHT=1080,RAW_BYTES=WIDTH*5/4;
reg clk=0,run_clk=1,rst=0,hs=0;reg [15:0] data=0;
always #4.444 if(run_clk)clk=~clk;
wire fs,fe,cv,rs,re,rv;wire [31:0] cd;wire [39:0] rd;
csi_unpacket_2lane csi(.I_clk(clk),.I_rst_n(rst),.I_hs_valid(hs),.I_hs_data(data),
 .O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(cv),.O_csi_data(cd),.O_csi_hs());
raw10_unpacket_2lane raw(.I_clk(clk),.I_rst_n(rst),.I_csi_frame_start(fs),
 .I_csi_frame_end(fe),.I_csi_valid(cv),.I_csi_data(cd),.I_camera_black_level(10'd0),
 .O_raw10_frame_start(rs),.O_raw10_frame_end(re),.O_raw10_valid(rv),.O_raw10_data(rd));
function integer pixel(input integer x,y);pixel=((x*37)^(y*97)^(x>>1))&1023;endfunction
function [7:0] payload(input integer i,y);
 integer x;
 begin
  x=(i/5)*4;
  case(i%5)
   0,1,2,3:payload=8'(pixel(x+i%5,y)>>2);
   4:payload={2'(pixel(x+3,y)),2'(pixel(x+2,y)),2'(pixel(x+1,y)),2'(pixel(x,y))};
  endcase
 end
endfunction
integer epoch=0,groups=0,starts=0,ends=0,compared=0;reg [39:0] expected;
always @(posedge clk)if(rst)begin
 if(rs)begin epoch++;groups=0;starts++;end
 if(re)ends++;
 if(rv)begin
  if(groups>=WIDTH*HEIGHT/4)$fatal(1,"CSI extra decoded group");
  for(integer k=0;k<4;k++)expected[k*10+:10]=10'(pixel(groups%(WIDTH/4)*4+k,groups/(WIDTH/4)));
  if(rd!==expected)$fatal(1,"CSI pixel truth frame%0d x%0d y%0d got%h expected%h",epoch,groups%(WIDTH/4)*4,groups/(WIDTH/4),rd,expected);
  groups++;compared+=4;
 end
end
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task short_packet(input [7:0] dt);begin
 hs=1;data={dt,8'd0};ticks(1);data=0;ticks(1);hs=0;ticks(32);
end endtask
task frame(input integer schedule);
 integer y,i,gap;
 begin
  short_packet(0);
  for(y=0;y<HEIGHT;y++)begin
   hs=1;data={8'h2b,8'(RAW_BYTES)};ticks(1);data={8'(RAW_BYTES>>8),8'h00};ticks(1);
   for(i=0;i<RAW_BYTES;i+=2)begin data={payload(i,y),payload(i+1,y)};ticks(1);end
   data=0;ticks(1);hs=0;
   case(schedule)
    0:gap=40;
    1:gap=3+y%7;
    default:gap=98+y%11;
   endcase
   ticks(gap);
   if(schedule==2 && y!=HEIGHT-1)begin run_clk=0;#12000;run_clk=1;end
  end
  short_packet(1);ticks(64);
  if(groups!=WIDTH*HEIGHT/4 || starts!=epoch || ends!=epoch)$fatal(1,"CSI complete native frame/markers failed");
  $display("OBS CSI pixels frame%0d schedule%0d groups%0d",epoch,schedule,groups);
 end
endtask
initial begin
 ticks(8);rst=1;ticks(40);frame(0);frame(1);frame(2);
 if(compared!=3*WIDTH*HEIGHT)$fatal(1,"CSI pixel coverage");
 $display("PASS CSI pixels: three full1920x1080 frames,6220800 independent10bit pixels,short/long packet gaps and stopped recovered clock,exact order and SOF/EOF");$finish;
end
initial begin #100000000;$fatal(1,"CSI pixel watchdog");end
endmodule
