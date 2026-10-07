`timescale 1ns/1ps
// Full-size guard oracle, independent of ISP and no post-test answer changes.
module tb_fhd_faults;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0,pv=0,ps=0,pl=0,cfg=1;
reg [1:0] lane=0;always #5 clk=~clk;
wire [10:0] x,y;wire accept,commit,invalid;
roi_frame_guard #(.WIDTH(1920),.HEIGHT(1080)) dut(clk,rst,fs,fe,hs,rv,lane,cfg,pv,ps,pl,x,y,accept,commit,invalid);
integer commits=0,case_no=0;
always @(posedge clk)if(rst && commit)commits=commits+1;
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task frame(input integer fault);integer rows,beats;begin
 case_no=case_no+1;commits=0;fs=1;ticks(1);fs=0;ticks(20);
 rows=fault==2 ? 1079 : fault==3 ? 1081 : 1080;
 for(integer row=0;row<rows;row=row+1)begin
  hs=1;beats=fault==1 && row==100 ? 479 : 480;
  for(integer b=0;b<beats;b=b+1)begin
   rv=1;pv=1;ps=(row==0 && b==0);pl=(b==beats-1);
   if(row==500 && b==100)begin if(fault==4)cfg=0;if(fault==5)lane=2;end
   ticks(1);rv=0;pv=0;ps=0;pl=0;cfg=1;lane=0;ticks(1);
  end
  hs=0;ticks(20);
 end
 fe=1;ticks(1);fe=0;ticks(30);
 if(fault==0)begin
  if(commits!=1 || dut.bad || dut.raw_total!=2073600 || dut.processed_total!=2073600 || dut.lines!=1080)
   $fatal(1,"FHD good/recovery rejected %0d raw=%0d proc=%0d lines=%0d",case_no,dut.raw_total,dut.processed_total,dut.lines);
 end else if(commits!=0 || !dut.bad)$fatal(1,"FHD fault accepted %0d fault=%0d",case_no,fault);
 $display("PASS FHD guard case=%0d fault=%0d commits=%0d",case_no,fault,commits);
end endtask
initial begin
 ticks(5);rst=1;ticks(10);frame(0);
 for(integer f=1;f<=5;f=f+1)begin frame(f);frame(0);end
 rst=0;ticks(10);rst=1;ticks(10);frame(0);
 $display("PASS FHD faults: short line, missing/extra line, config cancellation, lane error, reset and full-frame recovery, 21-bit counters/overflow");$finish;
end
initial begin #200000000;$fatal(1,"FHD guard timeout");end
endmodule
