`timescale 1ns/1ps
module gray_cache_pair #(parameter XOR=0,IDENT=0)(input wire clk,output reg done=0);
 localparam W=1280,H=720;
 reg rst_n=0,pv=0,sof=0,last=0,early=0,invalid=0,credit=1;
 reg [95:0] rgb=0;reg [1:0] mode=0;
 wire [1:0] ov,ol,oe,bad,gv;
 wire [95:0] color[0:1];wire [10:0] ox[0:1],gx[0:1];wire [9:0] oy[0:1],gy[0:1];
 wire [12:0] cp[0:1],ec[0:1];wire [23:0] es[0:1];wire [31:0] timing[0:1];
 wire [43:0] gm[0:1];wire [3:0] gn[0:1];
 R17_roi_sobel_view #(.WIDTH(W),.HEIGHT(H),.X0(0),.X1(W),.Y0(0),.Y1(H),
  .CORE_X0(600),.CORE_X1(680),.CORE_Y0(320),.CORE_Y1(400),.CACHE_ADDRESS_XOR(XOR)) reference(
  .clk(clk),.rst_n(rst_n),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(early),
  .rgb(rgb),.mode(mode),.invalidate(invalid),.view_ready(credit),.frame_bad(bad[0]),
  .out_valid(ov[0]),.out_last(ol[0]),.out_early_sof(oe[0]),.out_rgb(color[0]),.out_x(ox[0]),.out_y(oy[0]),
  .core_pixels(cp[0]),.edge_count(ec[0]),.edge_sum(es[0]),.timing_debug(timing[0]),
  .gradient_valid(gv[0]),.gradient_x(gx[0]),.gradient_y(gy[0]),.gradient_magnitudes(gm[0]),.gradient_neighborhood(gn[0]),
  .dynamic_x0(11'd0),.dynamic_x1(11'd0),.dynamic_y0(10'd0),.dynamic_y1(10'd0));
 roi_sobel_view #(.WIDTH(W),.HEIGHT(H),.X0(0),.X1(W),.Y0(0),.Y1(H),
  .CORE_X0(600),.CORE_X1(680),.CORE_Y0(320),.CORE_Y1(400),.CACHE_ADDRESS_XOR(XOR)) trial(
  .clk(clk),.rst_n(rst_n),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(early),
  .rgb(rgb),.mode(mode),.invalidate(invalid),.view_ready(credit),.frame_bad(bad[1]),
  .out_valid(ov[1]),.out_last(ol[1]),.out_early_sof(oe[1]),.out_rgb(color[1]),.out_x(ox[1]),.out_y(oy[1]),
  .core_pixels(cp[1]),.edge_count(ec[1]),.edge_sum(es[1]),.timing_debug(timing[1]),
  .gradient_valid(gv[1]),.gradient_x(gx[1]),.gradient_y(gy[1]),.gradient_magnitudes(gm[1]),.gradient_neighborhood(gn[1]),
  .dynamic_x0(11'd0),.dynamic_x1(11'd0),.dynamic_y0(10'd0),.dynamic_y1(10'd0));
 integer cycles=0,beats=0,gradients=0,frame=0,before_beats=0;
 integer x,y,j,k;
 always @(posedge clk)begin
  #1;
  if(rst_n)begin
   cycles=cycles+1;
   if({ov[0],ol[0],oe[0],bad[0],gv[0],cp[0],ec[0],es[0],timing[0]} !==
      {ov[1],ol[1],oe[1],bad[1],gv[1],cp[1],ec[1],es[1],timing[1]})
    $fatal(1,"control/statistics mismatch XOR%0d frame%0d cycle%0d",XOR,frame,cycles);
   if(ov[0])begin
    if({color[0],ox[0],oy[0]} !== {color[1],ox[1],oy[1]})
     $fatal(1,"RGB/coordinate mismatch XOR%0d frame%0d x%0d y%0d",XOR,frame,ox[0],oy[0]);
    beats=beats+1;
   end
   if(gv[0])begin
    if({gx[0],gy[0],gm[0],gn[0]} !== {gx[1],gy[1],gm[1],gn[1]})
     $fatal(1,"gradient mismatch XOR%0d frame%0d x%0d y%0d",XOR,frame,gx[0],gy[0]);
    gradients=gradients+1;
   end
  end
 end
 function [23:0] pixel(input integer xx,yy,seed);
  reg [7:0] rr,gg,bb;
  begin
   rr=(xx*17+yy*37+seed*11)&255;
   gg=(xx*29+yy*11+seed*59)&255;
   bb=(xx*7+yy*19+seed*83)&255;
   if((xx/37+yy/31+seed)%5==0)begin rr=255;gg=255;bb=255;end
   if((xx/43+yy/47+seed)%7==0)begin rr=0;gg=0;bb=0;end
   pixel={rr,gg,bb};
  end
 endfunction
 task idle(input integer n);
  begin repeat(n)begin @(negedge clk);pv=0;sof=0;last=0;end end
 endtask
 task raster(input integer m,scenario);
  begin
   frame=frame+1;before_beats=beats;
   @(negedge clk);mode=m;early=1;pv=0;sof=0;last=0;invalid=0;credit=1;
   @(negedge clk);early=0;idle(8);
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<W;x=x+4)begin
     @(negedge clk);pv=1;sof=(x==0 && y==0);last=(x==W-4);
     credit=!(scenario==1 && y>=120 && y<128);
     invalid=(scenario==2 && y==210 && x==28);
     for(j=0;j<4;j=j+1)rgb[95-j*24-:24]=pixel(x+j,y,frame+IDENT);
     if((x/4)%11==3)idle(1);
    end
    idle(y%7);
   end
   idle(5*(W/4)+80);invalid=0;credit=1;
   if(scenario==0)begin
    if(bad[0] || beats-before_beats!=W*H/4)
     $fatal(1,"coverage failed XOR%0d mode%0d observed%0d expected%0d bad%b",XOR,m,beats-before_beats,W*H/4,bad[0]);
   end
   if(scenario==1 && !bad[0])$fatal(1,"credit-loss scenario must trigger real frame_bad");
   $display("CACHE_EQ XOR=%0d frame=%0d mode=%0d scenario=%0d beats=%0d bad=%b",XOR,frame,m,scenario,beats-before_beats,bad[0]);
  end
 endtask
 initial begin
  idle(3);@(negedge clk);rst_n=1;idle(4);
  for(k=0;k<4;k=k+1)raster(k,0);
  raster(3,1);raster(2,2);
  // Reset with old cached data retained; a new raster must warm itself.
  @(negedge clk);rst_n=0;idle(4);@(negedge clk);rst_n=1;idle(4);raster(3,0);
  if(beats<5*W*H/4 || gradients<2*W*H/4)$fatal(1,"insufficient compared output coverage");
  $display("PASS cache pair XOR%0d: cycles=%0d RGBbeats=%0d gradients=%0d full720p_four_modes_credit_cancel_reset",XOR,cycles,beats,gradients);
  done=1;
 end
endmodule
module tb_rgb_shared_equivalence;
 reg clk=0;always #5 clk=~clk;
 wire d0,d1;
 gray_cache_pair #(.XOR(0),.IDENT(0)) plain(clk,d0);
 gray_cache_pair #(.XOR(1),.IDENT(7)) encoded(clk,d1);
 initial begin wait(d0 && d1);$display("PASS RGB shared equivalence: immutable R15 full720p RGB/gradients/statistics/control/timing both XOR modes");$finish;end
 initial begin #200000000;$fatal(1,"gray cache test timeout");end
endmodule
