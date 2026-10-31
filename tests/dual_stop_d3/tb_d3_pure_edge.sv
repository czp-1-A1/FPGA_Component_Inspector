`timescale 1ns/1ps
module tb_d3_pure_edge #(parameter W=96,H=30,N=48);
 localparam X0=W==96 ? 8:0,X1=W==96 ? 88:W,Y0=W==96 ? 2:0,Y1=W==96 ? 26:H;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,pv=0,sof=0,last=0,fs=0,cancel=0,credit=1;
 reg [95:0] rgb=0;reg [1:0] mode=0;
 wire bad0,v0,l0,fs0,g0,bad1,v1,l1,fs1,g1;
 wire [95:0] rgb0,rgb1;wire [10:0] x0,x1,gx0,gx1;wire [9:0] y0,y1,gy0,gy1;
 wire [12:0] cp0,cp1,ec0,ec1;wire [23:0] es0,es1;wire [31:0] td0,td1;
 wire [43:0] gm0,gm1;wire [3:0] gn0,gn1;
 roi_sobel_view #(.RAW_EDGE_ONLY(1),.WIDTH(W),.HEIGHT(H),.X0(X0),.X1(X1),.Y0(Y0),.Y1(Y1),.CORE_X0(20),.CORE_X1(70),.CORE_Y0(8),.CORE_Y1(22),.CACHE_ADDRESS_XOR(1)) dut(
  .clk(clk),.rst_n(rst),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(fs),.rgb(rgb),.mode(mode),.invalidate(cancel),.view_ready(credit),
  .frame_bad(bad0),.out_valid(v0),.out_last(l0),.out_early_sof(fs0),.out_rgb(rgb0),.out_x(x0),.out_y(y0),.core_pixels(cp0),.edge_count(ec0),.edge_sum(es0),.timing_debug(td0),
  .gradient_valid(g0),.gradient_x(gx0),.gradient_y(gy0),.gradient_magnitudes(gm0),.gradient_neighborhood(gn0),.dynamic_x0(11'd0),.dynamic_x1(11'd0),.dynamic_y0(10'd0),.dynamic_y1(10'd0));
 r50_reference_roi_sobel_view #(.WIDTH(W),.HEIGHT(H),.X0(X0),.X1(X1),.Y0(Y0),.Y1(Y1),.CORE_X0(20),.CORE_X1(70),.CORE_Y0(8),.CORE_Y1(22),.CACHE_ADDRESS_XOR(1)) baseline(
  .clk(clk),.rst_n(rst),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(fs),.rgb(rgb),.mode(mode),.invalidate(cancel),.view_ready(credit),
  .frame_bad(bad1),.out_valid(v1),.out_last(l1),.out_early_sof(fs1),.out_rgb(rgb1),.out_x(x1),.out_y(y1),.core_pixels(cp1),.edge_count(ec1),.edge_sum(es1),.timing_debug(td1),
  .gradient_valid(g1),.gradient_x(gx1),.gradient_y(gy1),.gradient_magnitudes(gm1),.gradient_neighborhood(gn1),.dynamic_x0(11'd0),.dynamic_x1(11'd0),.dynamic_y0(10'd0),.dynamic_y1(10'd0));
 reg [23:0] image[0:W*H-1];reg model_edge=0;
 integer seed=32'h189ca705,cycles=0,pixels=0,gradients=0,aborted=0,white=0,black=0,raw_pixels=0;
 function integer luminance(input integer x,y);
  reg [23:0] c;begin c=image[y*W+x];luminance=(int'(c[23:16])+2*int'(c[15:8])+int'(c[7:0]))/4;end
 endfunction
 function [23:0] golden(input integer x,y);
  integer sx,sy;begin
   if(!model_edge)golden=image[y*W+x];
   else if(x<=X0 || x>=X1-1 || y<=Y0 || y>=Y1-1 || y<=0 || y>=H-1)golden=0;
   else begin
    sx=luminance(x+1,y-1)+2*luminance(x+1,y)+luminance(x+1,y+1)-luminance(x-1,y-1)-2*luminance(x-1,y)-luminance(x-1,y+1);
    sy=luminance(x-1,y+1)+2*luminance(x,y+1)+luminance(x+1,y+1)-luminance(x-1,y-1)-2*luminance(x,y-1)-luminance(x+1,y-1);
    if(sx<0)sx=-sx;if(sy<0)sy=-sy;
    golden=sx+sy>=80 ? 24'hffffff:24'h000000;
   end
  end
 endfunction
 always @(posedge clk)begin #1;if(rst)begin
  cycles++;
  if({bad0,v0,l0,fs0,g0,cp0,ec0,es0,td0}!=={bad1,v1,l1,fs1,g1,cp1,ec1,es1,td1})$fatal(1,"pure edge changed schedule/guards/features cycle%0d",cycles);
  if(v0)begin
   if({x0,y0}!=={x1,y1})$fatal(1,"pure edge changed coordinates");
   for(integer k=0;k<4;k++)begin
    if(rgb0[95-k*24-:24]!==golden(x0+k,y0))$fatal(1,"pure edge pixel xy%0d,%0d mode%0d got%h expected%h",x0+k,y0,model_edge,rgb0[95-k*24-:24],golden(x0+k,y0));
    if(!model_edge)raw_pixels++;else if(rgb0[95-k*24-:24]==24'hffffff)white++;else black++;
   end
   pixels+=4;
  end
  if(g0)begin
   if({gx0,gy0,gm0,gn0}!=={gx1,gy1,gm1,gn1})$fatal(1,"pure edge changed gradient tap");gradients++;
  end
 end end
 initial begin
  repeat(8)@(negedge clk);rst=1;
  for(integer f=0;f<N;f++)begin
   mode=f%4;model_edge=mode[1];fs=1;pv=0;credit=1;@(negedge clk);fs=0;repeat(5)@(negedge clk);
   for(integer y=0;y<H;y++)begin
    credit=!(N>4 && f>=32 && f<40 && y>=3 && y<9);
    for(integer x=0;x<W/4;x++)begin
     if(N>4 && f>=40 && y==12 && x==12)begin fs=1;pv=0;@(negedge clk);fs=0;end
     if(N>4 && f>=16 && y==10 && x==0)mode=mode^2'b11;
     pv=1;sof=x==0 && y==0;last=x==W/4-1;rgb={$random(seed),$random(seed),$random(seed)};
     for(integer k=0;k<4;k++)image[y*W+x*4+k]=rgb[95-k*24-:24];
     @(negedge clk);pv=0;sof=0;last=0;
     repeat(N<=4 || f<16 ? 0:$unsigned($random(seed))%3)@(negedge clk);
    end
    repeat(N<=4 || f<8 ? 0:64)@(negedge clk);
   end
   repeat(W+180)@(negedge clk);
   if(bad0)aborted++;
   cancel=1;@(negedge clk);cancel=0;
  end
  if(raw_pixels<1000 || white<100 || black<100 || gradients<1000 || (N>4 && aborted<2))$fatal(1,"pure edge coverage incomplete raw%0d white%0d black%0d grad%0d aborted%0d",raw_pixels,white,black,gradients,aborted);
  if(N==4 && (pixels!=N*W*H || gradients!=2*(W/4)*H || aborted))$fatal(1,"pure edge full raster loss");
  $display("PASS PURE_EDGE: independent numeric pixels, RAW exact, mode bit0 ignored, mid-frame held modes; R50 every-clock schedule/gradients/counters/faults unchanged; W%0d H%0d frames%0d pixels%0d raw%0d white%0d black%0d gradients%0d aborted%0d",W,H,N,pixels,raw_pixels,white,black,gradients,aborted);$finish;
 end
 initial begin #50000000;$fatal(1,"pure edge watchdog");end
endmodule
