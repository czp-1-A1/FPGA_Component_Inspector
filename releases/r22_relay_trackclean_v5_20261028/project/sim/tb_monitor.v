`timescale 1ns/1ps
module tb_monitor;
reg rx=0,refclk=0,rst=0,fs=0,fe=0,hs=0,valid=0;
reg [1:0] lane=0;
always #5 rx=~rx; always #7 refclk=~refclk;
wire [15:0] w,h,le,err,fps,gap; wire [31:0] uptime,frames;
input_monitor #(.REF_HZ(200000)) dut(rx,refclk,rst,fs,fe,hs,valid,lane,w,h,le,err,fps,gap,uptime,frames);
task ticks;input integer n;begin repeat(n) @(negedge rx);end endtask
task frame;input integer width;input integer height; integer x,y;begin
 fs=1;ticks(1);fs=0;ticks(25);
 for(y=0;y<height;y=y+1) begin
  hs=1;ticks(8);
  for(x=0;x<width/4;x=x+1) begin valid=1;ticks(1);valid=0;ticks(1);end
  hs=0;ticks(30);
 end
 fe=1;ticks(1);fe=0;ticks(100);
end endtask
initial begin
 ticks(3);rst=1;
 frame(1024,600);
 if(w!=1024 || h!=600 || err!=0 || frames!=1) $fatal(1,"dimensions %d %d err %d frames %d",w,h,err,frames);
 lane=1;ticks(15);lane=0;ticks(40);if(le!=1) $fatal(1,"lane edge count");
 frame(1000,599);if(w!=1000 || h!=599 || err!=1) $fatal(1,"bad frame detection");
 ticks(600000); if(fps!=0 || gap==0) $fatal(1,"loss of input");
 $display("PASS monitor: bubbled PPC4 input, actual dimensions, bad frame, lane edge, stopped input");$finish;
end
initial begin #20000000;$fatal(1,"timeout");end
endmodule
