`timescale 1ns/1ps
// Diagnosis only: original R56 RTL, single/dual tape, same geometry/recipe.
module tb_r57_budget;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,sof=0,accept=0;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sample;wire [303:0] display_objects;
 wire [607:0] main_objects,station_objects;
 wire gready,gsample;wire [303:0] gdisplay;wire [607:0] gmain,gstation;
 frame_shape_search #(.DUAL_STOP(1),.DUAL_REGION_COUNT(1),.SPARSE_ROW_SCAN(1),
  .PRESENT_TRACE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),
  .EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),
  .STANDING_REVIEW(1),.SURFACE_REVIEW(1),.COUNT_EMPTY_MARGIN(1),
  .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(
  .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),
  .invalidate(1'b0),.pixel_x(x),.pixel_y(y),.rgb(rgb),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0),
  .station_hold_valid(2'd0),.station_hold_empty_only(2'd0),
  .station_hold_x(22'd0),.station_hold_y(20'd0),.station_hold_radius(12'd0),
  .ready(ready),.sample_new(sample),.region_objects(display_objects),
  .recorder_objects(main_objects),.station_objects(station_objects));
 frame_shape_search_r56 #(.DUAL_STOP(1),.DUAL_REGION_COUNT(1),.SPARSE_ROW_SCAN(1),
  .PRESENT_TRACE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),
  .EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),
  .STANDING_REVIEW(1),.SURFACE_REVIEW(1),.COUNT_EMPTY_MARGIN(1),
  .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) golden(
  .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),
  .invalidate(1'b0),.pixel_x(x),.pixel_y(y),.rgb(rgb),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0),
  .station_hold_valid(2'd0),.station_hold_empty_only(2'd0),
  .station_hold_x(22'd0),.station_hold_y(20'd0),.station_hold_radius(12'd0),
  .ready(gready),.sample_new(gsample),.region_objects(gdisplay),
  .recorder_objects(gmain),.station_objects(gstation));
 integer scene=0,px,py,l,v,waited,valid0,valid1,valids0,valids1;
 integer phases[0:63];
 function integer image(input integer xx,yy);
  integer lane,k,cx,cy,dx,dy,enable;
  begin
   image=scene>=6 ? 220 : 30;
   for(lane=0;lane<2;lane++)begin
    enable=scene%3==2 || scene%3==lane;
    cy=lane==0 ? 320 : 516;
    if(enable && scene>=6 && yy>=cy-40 && yy<cy+44)image=30;
    if(enable)begin
     for(k=0;k<18;k++)begin
      // First ten in main ROI; further seven strictly in the parking ROI.
      cx=k<10 ? 430+k*46 : 90+(k-10)*44;
      dx=xx-cx;dy=yy-cy;
      if((k<10 || scene>=3) && dx>=-18 && dx<18 && dy>=-22 && dy<22 &&
         !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))image=180;
      if((k<10 || scene>=3) && dx*dx+(dy+36)*(dy+36)<=49)image=180;
     end
    end
   end
  end
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 initial begin
  ticks(8);rst=1;ticks(4);
  for(scene=0;scene<9;scene++)begin
   fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px+=4)begin
     x=px;y=py;sof=px==0 && py==0;accept=1;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   for(l=0;l<64;l++)phases[l]=0;
   waited=0;
   while(!ready && waited<1500000)begin
    phases[dut.phase]++;ticks(1);waited++;
    if(waited==125000)$display("BUDGET_AT_125000 scene=%0d ready=%0d phase=%0d",scene,ready,dut.phase);
   end
   if(!ready)$fatal(1,"analysis unfinished scene%0d phase%0d",scene,dut.phase);
   if(waited>120000)$fatal(1,"dense deadline exceeded scene%0d cycles%0d",scene,waited);
   while(!gready)ticks(1);
   if({display_objects,main_objects,station_objects}!=={gdisplay,gmain,gstation})$fatal(1,"R56 candidate/class/position mismatch scene%0d",scene);
   ticks(2);valid0=0;valid1=0;valids0=0;valids1=0;
   for(l=0;l<4;l++)begin
    if(main_objects[l*76+75])valid0++;
    if(main_objects[(l+4)*76+75])valid1++;
    if(station_objects[l*76+75])valids0++;
    if(station_objects[(l+4)*76+75])valids1++;
   end
   $display("R57_BUDGET scene=%0d cycles=%0d us=%0d main=%0d,%0d station=%0d,%0d display=%h",scene,waited,waited/100,valid0,valid1,valids0,valids1,display_objects);
   for(l=0;l<64;l++)if(phases[l]!=0)$display("R56_PHASE scene=%0d phase=%0d cycles=%0d",scene,l,phases[l]);
  end
  $display("PASS R57_BUDGET original R56 exact candidate/class/position comparison, all9 single/dual main+station scenes within 1.2ms");$finish;
 end
 initial begin #300000000;$fatal(1,"watchdog");end
endmodule
