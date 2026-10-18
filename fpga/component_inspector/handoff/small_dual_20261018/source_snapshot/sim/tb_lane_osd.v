`timescale 1ns/1ps
module tb_lane_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,valid=1;reg [303:0] objects=0;
reg [15:0] ex=1092,ga=40,fp=27,gap=0;reg [1:0] mode=3;wire ov,oh,od;wire [23:0] rgb;
always #5 clk=~clk;
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_SEARCH(1),.FRAME_OBJECTS(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.exposure(ex),.gain(ga),.fps(fp),.view_mode(mode),
 .roi_valid(valid),.cfg_done(1'b1),.frame_objects(objects),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(gap),
 .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(rgb));
wire bv,bh,bd;wire [23:0] brgb;
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.FRAME_OBJECTS(1),.ENABLE(0)) bypass(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.exposure(ex),.gain(ga),.fps(fp),.view_mode(mode),
 .roi_valid(valid),.cfg_done(1'b1),.frame_objects(objects),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(gap),
 .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.out_vs(bv),.out_hs(bh),.out_de(bd),.out_rgb(brgb));
reg [23:0] expected[0:921599];reg [2:0] ed=0,eh=0,ev=0;
function [75:0] record(input integer state,reason,x0,x1,y0,y1);
 record={1'b1,2'(state),4'(reason),13'd4000,7'd36,7'd44,11'(x0),11'(x1),10'(y0),10'(y1)};
endfunction
task set_case(input integer c);begin
case(c)
0:begin objects={record(2,0,900,940,500,544),record(3,0,634,650,412,428),record(3,0,480,496,260,276),record(2,0,610,648,278,322)};valid=1;mode=3;ex=1092;ga=40;fp=27;gap=0;end
1:begin objects={record(2,0,900,940,500,544),record(2,15,612,650,400,444),record(3,0,480,496,260,276),record(2,4,634,672,278,322)};valid=1;mode=0;ex=1200;ga=48;fp=26;gap=0;end
2:begin objects={record(2,0,900,940,500,544),record(3,0,634,650,412,428),record(3,0,480,496,260,276),record(2,0,610,648,278,322)};valid=0;mode=1;ex=1200;ga=48;fp=26;gap=1;end
3:begin objects={record(2,0,900,940,500,544),record(3,0,642,658,412,428),record(3,0,480,496,260,276),76'd0};valid=1;mode=2;ex=1092;ga=40;fp=27;gap=0;end
endcase
end endtask
integer frame=0,pixel=0,checks=0,xx,yy;reg checking=0;
always @(posedge clk)begin
 ed={ed[1:0],de};eh={eh[1:0],hs};ev={ev[1:0],vs};#1;
 if(rst && ({od,oh,ov}!=={ed[2],eh[2],ev[2]} || {bd,bh,bv}!=={ed[2],eh[2],ev[2]}))$fatal(1,"lane UI sync/bypass latency");
 if(checking && od)begin
  if(rgb!==expected[pixel])$fatal(1,"lane UI case%0d x%0d y%0d got%h expected%h",frame,pixel%1280,pixel/1280,rgb,expected[pixel]);
  if(brgb!==24'h556677)$fatal(1,"lane UI bypass changed pixel");pixel++;checks++;
 end
end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
initial begin
 ticks(5);rst=1;ticks(5);
 for(frame=0;frame<4;frame++)begin
  set_case(frame);$readmemh($sformatf("lane_ui_%0d.hex",frame),expected);
  vs=1;ticks(3);vs=0;ticks(4);pixel=0;checking=1;
  for(yy=0;yy<720;yy++)begin
   hs=1;ticks(2);hs=0;de=1;ticks(1280);de=0;ticks(4);
   if(yy==360)set_case((frame+1)%4); // New tuple must wait for next raster.
  end
  ticks(5);checking=0;if(pixel!=921600)$fatal(1,"lane UI raster coverage");
 end
 $display("PASS lane OSD: 4 full rasters/%0d independent pixels, moving labels follow boxes,2 lanes,unused slots ignored,invalid clears,atomic snapshots,logo/fonts/header,3-clock sync and ENABLE bypass",checks);$finish;
end
initial begin #70000000;$fatal(1,"lane UI watchdog");end
endmodule
