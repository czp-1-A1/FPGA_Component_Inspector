`timescale 1ns/1ps
module tb_roi_guard;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0,cfg=1,pv=0,ps=0,pl=0;
reg [1:0] lane_error=0;
reg [95:0] data=0;
always #5 clk=~clk;
wire [10:0] x;
wire [9:0] y;
wire accept,commit,invalid,sv;
wire [7:0] avg,lo,hi;
wire [19:0] count;
wire [27:0] sum;
roi_frame_guard #(.WIDTH(12),.HEIGHT(3)) guard(clk,rst,fs,fe,hs,rv,lane_error,cfg,pv,ps,pl,x,y,accept,commit,invalid);
roi_statistics #(.X0(1),.X1(10),.Y0(0),.Y1(3)) stats(clk,rst,accept,ps,x,y,data,commit,invalid,sv,avg,lo,hi,count,sum,,fs);
integer commits=0,row,b,p,reference_sum,reference_lo,reference_hi,g,case_no=0;
always @(posedge clk) if(rst && commit) commits=commits+1;
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task reset_case;begin
 rst=0;fs=0;fe=0;hs=0;rv=0;pv=0;ps=0;pl=0;cfg=1;lane_error=0;ticks(4);rst=1;ticks(4);commits=0;
 fs=1;ticks(1);fs=0;case_no=case_no+1;
end endtask
task native_rows;input integer rows,beats,collision;
begin
 for(row=0;row<rows;row=row+1) begin
  hs=1;
  for(b=0;b<beats;b=b+1) begin rv=1;ticks(1);rv=0;ticks(1);end
  hs=0;
  if(collision && row==rows-1) begin ticks(16);fe=1;ticks(1);fe=0;ticks(4);end
  else ticks(20);
 end
end endtask
task end_native;begin fe=1;ticks(1);fe=0;ticks(2);end endtask
task pixels;input integer rows,short_line,duplicate;
integer r,v,l;
begin
 for(r=0;r<rows;r=r+1) begin
  for(v=0;v<3-short_line;v=v+1) begin
   for(l=0;l<4;l=l+1) data[95-l*24-:24]={8'(40+v*4+l),8'(60+r*15),8'(70+v*4+l+r)};
   pv=1;ps=(r==0 && v==0) || (duplicate && r==1 && v==0);pl=(v==2-short_line);
   ticks(1);pv=0;ps=0;pl=0;ticks(1);
  end
  ticks(3);
 end
end endtask
task expect_good;begin
 ticks(40);
 if(commits!=1 || !sv || count!=27 || sum!=reference_sum || avg!=reference_sum/27 || lo!=reference_lo || hi!=reference_hi)
  $fatal(1,"ROI case %0d commits=%0d valid=%b count=%d sum=%d mean=%d min=%d max=%d",case_no,commits,sv,count,sum,avg,lo,hi);
end endtask
task expect_bad;begin ticks(40);if(commits!=0 || sv) $fatal(1,"bad frame accepted case %0d",case_no);end endtask
initial begin
 reference_sum=0;reference_lo=255;reference_hi=0;
 for(row=0;row<3;row=row+1) for(p=1;p<10;p=p+1) begin
  g=((40+p)+2*(60+row*15)+(70+p+row))/4;
  reference_sum=reference_sum+g;
  if(g<reference_lo) reference_lo=g;if(g>reference_hi) reference_hi=g;
 end
 reset_case;native_rows(3,3,0);end_native;pixels(3,0,0);expect_good;
 reset_case;native_rows(3,3,1);pixels(3,0,0);expect_good;
 reset_case;native_rows(3,3,0);pixels(3,0,0);ticks(5);
 if(commits!=0) $fatal(1,"published before native FE");end_native;expect_good;
 reset_case;native_rows(3,2,0);end_native;pixels(3,0,0);expect_bad;
 reset_case;native_rows(2,3,0);end_native;pixels(3,0,0);expect_bad;
 reset_case;native_rows(3,4,0);end_native;pixels(3,0,0);expect_bad;
 reset_case;native_rows(3,3,0);end_native;pixels(3,1,0);expect_bad;
 reset_case;native_rows(3,3,0);end_native;pixels(3,0,1);expect_bad;
 reset_case;native_rows(1,3,0);pixels(3,0,0);native_rows(2,3,0);end_native;expect_bad;
 reset_case;native_rows(3,3,0);end_native;cfg=0;ticks(1);cfg=1;pixels(3,0,0);expect_bad;
 reset_case;native_rows(3,3,0);end_native;lane_error=1;ticks(1);lane_error=0;pixels(3,0,0);expect_bad;
 reset_case;native_rows(3,3,0);end_native;pixels(3,0,0);expect_good;
 fs=1;ticks(1);fs=0;commits=0;pixels(1,0,0);fs=1;ticks(1);fs=0;
 native_rows(3,3,0);end_native;pixels(3,0,0);expect_good;
 // A configuration change while the frame division is pending must cancel it.
 reset_case;native_rows(3,3,0);end_native;pixels(3,0,0);
 cfg=0;ticks(1);cfg=1;ticks(40);
 if(commits!=1 || sv) $fatal(1,"cancelled pending sample became valid");
 reset_case;native_rows(3,3,0);end_native;pixels(3,0,0);expect_good;
 $display("PASS ROI guard: independent RGB math, unaligned ROI, first/last beat, completion ordering, FE collision, malformed/overrun/config/lane/overlap and recovery");
 $finish;
end
initial begin #100000; $fatal(1,"ROI guard watchdog");end
endmodule
