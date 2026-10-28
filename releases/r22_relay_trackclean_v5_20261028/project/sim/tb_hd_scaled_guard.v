`timescale 1ns/1ps
module tb_hd_scaled_guard;
reg clk=0,rst=0,early=0,valid=0,last=0,native=0,bad=0;
always #5 clk=~clk;
wire accept,sof,commit,fault;wire [10:0] x;wire [9:0] y;
integer commits=0,accepted=0;
scaled_frame_guard dut(clk,rst,early,valid,last,native,bad,accept,sof,x,y,commit,fault);
always @(posedge clk)begin if(commit)commits++;if(accept)accepted++;end
task tick;begin @(negedge clk);end endtask
task start;begin valid=0;last=0;native=0;bad=0;early=1;tick;early=0;repeat(3)tick;end endtask
task raster(input integer short_frame);
 begin
  for(integer yy=0;yy<(short_frame ? 719 : 720);yy++)
   for(integer xx=0;xx<1280;xx+=4)begin
    valid=1;last=(xx==1276);tick;valid=0;last=0;if(xx%16==0)tick;
   end
  valid=0;last=0;repeat(4)tick;
 end
endtask
initial begin
 repeat(8)tick;rst=1;start;raster(0);
 if(commit || commits || accepted!=230400)$fatal(1,"scaled pixels bypassed native proof");
 native=1;tick;native=0;repeat(4)tick;
 if(commits!=1 || fault)$fatal(1,"both proofs did not publish");
 start;raster(1);native=1;tick;native=0;repeat(4)tick;
 if(commits!=1)$fatal(1,"native proof bypassed missing final scaled row");
 start;valid=1;last=1;tick;valid=0;last=0;native=1;repeat(4)tick;native=0;
 if(!fault || commits!=1)$fatal(1,"malformed scaled EOL accepted");
 start;native=1;tick;native=0;raster(0);repeat(4)tick;
 if(fault || commits!=2)$fatal(1,"scaled guard recovery failed");
 $display("PASS hd scaled guard: 921600 pixels independent of native proof, short/malformed rejection, proof ordering and recovery");
 $finish;
end
initial begin #15000000;$fatal(1,"scaled guard watchdog");end
endmodule
