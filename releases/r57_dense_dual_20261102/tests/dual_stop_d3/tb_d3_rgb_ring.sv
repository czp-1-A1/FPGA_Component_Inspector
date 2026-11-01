`timescale 1ns/1ps
module tb_d3_rgb_ring;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,pv=0,sof=0,last=0,fs=0,cancel=0,credit=1;
 reg [95:0] rgb=0;reg [1:0] mode=0;
 wire bad0,v0,l0,fs0,g0,bad1,v1,l1,fs1,g1;
 wire [95:0] rgb0,rgb1;wire [10:0] x0,x1,gx0,gx1;wire [9:0] y0,y1,gy0,gy1;
 wire [12:0] cp0,cp1,ec0,ec1;wire [23:0] es0,es1;wire [31:0] td0,td1;
 wire [43:0] gm0,gm1;wire [3:0] gn0,gn1;
 roi_sobel_view #(.WIDTH(96),.HEIGHT(30),.X0(8),.X1(88),.Y0(2),.Y1(26),.CORE_X0(20),.CORE_X1(70),.CORE_Y0(8),.CORE_Y1(22),.CACHE_ADDRESS_XOR(1)) dut(
  .clk(clk),.rst_n(rst),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(fs),.rgb(rgb),.mode(mode),.invalidate(cancel),.view_ready(credit),
  .frame_bad(bad0),.out_valid(v0),.out_last(l0),.out_early_sof(fs0),.out_rgb(rgb0),.out_x(x0),.out_y(y0),.core_pixels(cp0),.edge_count(ec0),.edge_sum(es0),.timing_debug(td0),
  .gradient_valid(g0),.gradient_x(gx0),.gradient_y(gy0),.gradient_magnitudes(gm0),.gradient_neighborhood(gn0),.dynamic_x0(11'd0),.dynamic_x1(11'd0),.dynamic_y0(10'd0),.dynamic_y1(10'd0));
 r11_reference_roi_sobel_view #(.WIDTH(96),.HEIGHT(30),.X0(8),.X1(88),.Y0(2),.Y1(26),.CORE_X0(20),.CORE_X1(70),.CORE_Y0(8),.CORE_Y1(22),.CACHE_ADDRESS_XOR(1)) baseline(
  .clk(clk),.rst_n(rst),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(fs),.rgb(rgb),.mode(mode),.invalidate(cancel),.view_ready(credit),
  .frame_bad(bad1),.out_valid(v1),.out_last(l1),.out_early_sof(fs1),.out_rgb(rgb1),.out_x(x1),.out_y(y1),.core_pixels(cp1),.edge_count(ec1),.edge_sum(es1),.timing_debug(td1),
  .gradient_valid(g1),.gradient_x(gx1),.gradient_y(gy1),.gradient_magnitudes(gm1),.gradient_neighborhood(gn1),.dynamic_x0(11'd0),.dynamic_x1(11'd0),.dynamic_y0(10'd0),.dynamic_y1(10'd0));
 integer seed=32'h3ea3751,cycles=0,pixels=0,gradients=0,errors=0,aborted=0;
 always @(posedge clk)begin #1;if(rst)begin
  cycles++;
  if({bad0,v0,l0,fs0,g0,cp0,ec0,es0,td0}!=={bad1,v1,l1,fs1,g1,cp1,ec1,es1,td1})$fatal(1,"ring status/count/schedule differs cycle%0d",cycles);
  if(v0)begin
   if({rgb0,x0,y0}!=={rgb1,x1,y1})$fatal(1,"ring RGB coordinate differs cycle%0d xy%0d,%0d",cycles,x0,y0);pixels+=4;
  end
  if(g0)begin
   if({gx0,gy0,gm0,gn0}!=={gx1,gy1,gm1,gn1})$fatal(1,"ring feature tap differs");gradients++;
  end
 end end
 initial begin
  repeat(8)@(negedge clk);rst=1;
  for(integer f=0;f<48;f++)begin
   mode=f%4;fs=1;pv=0;credit=1;@(negedge clk);fs=0;repeat(5)@(negedge clk);
   for(integer y=0;y<30;y++)begin
    credit=!(f>=32 && f<40 && y>=3 && y<9);
    for(integer x=0;x<24;x++)begin
     if(f>=40 && y==12 && x==12)begin fs=1;pv=0;@(negedge clk);fs=0;end
     pv=1;sof=x==0 && y==0;last=x==23;rgb={$random(seed),$random(seed),$random(seed)};
     @(negedge clk);pv=0;sof=0;last=0;
     repeat(f<16 ? 0 : $unsigned($random(seed))%3)@(negedge clk);
    end
    repeat(f<8 ? 0 : 64)@(negedge clk);
   end
   repeat(180)@(negedge clk);
   if(bad0)aborted++;
   cancel=1;@(negedge clk);cancel=0;
  end
  if(pixels<40000 || gradients<2000 || aborted<2)$fatal(1,"ring coverage pixels%0d gradients%0d aborted%0d",pixels,gradients,aborted);
  $display("PASS exact three-row RGB ring: 48 frames/all4 modes, dense/native row gaps, random beat gaps, credit stalls/overrun, early cancel, XOR cache encoding; same valid RGB/gradients + every-clock counters/diagnostics/faults/schedule, cycles%0d pixels%0d gradients%0d aborted%0d",cycles,pixels,gradients,aborted);$finish;
 end
 initial begin #10000000;$fatal(1,"RGB ring watchdog");end
endmodule
