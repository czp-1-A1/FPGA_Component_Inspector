`timescale 1ns/1ps
module tb_direct_modes;
reg [1:0] mode=0,gray_state=1;reg scene=1;
reg [12:0] pixels=6400,count=0;reg [23:0] strength=0;
wire [1:0] state;
roi_mode_classifier #(.FUSE_FEATURES(0)) dut(mode,gray_state,scene,pixels,count,strength,state);
integer checked=0;
task check(input integer m,g,n,s,area,expected);
 begin
  mode=m;gray_state=g;count=n;strength=s;pixels=area;#2;
  if(state!==expected) $fatal(1,"direct selection mode=%0d gray=%0d EC=%0d GS=%0d area=%0d got=%0d expected=%0d",m,g,n,s,area,state,expected);
  checked++;
 end
endtask
initial begin
 for(integer m=0;m<4;m++) begin
  check(m,1,100,40000,6400,1);check(m,0,100,40000,6400,0);
 end
 check(0,2,0,0,0,2);check(1,3,6400,1000000,0,3);
 check(2,3,96,32768,6400,2);check(2,2,48,16384,6400,3);
 check(2,2,95,32768,6400,1);check(2,2,96,32767,6400,1);
 check(2,3,49,16384,6400,1);check(2,3,48,16385,6400,1);
 check(2,2,96,32768,6399,1);check(3,2,0,0,6399,1);
 // Disagreement must remain independently visible, not reject both tests.
 check(3,2,0,0,6400,2);check(3,3,96,32768,6400,3);
 check(3,2,70,20000,6400,2);check(3,3,70,20000,6400,3);
 scene=0;check(0,2,0,0,6400,1);
 $display("PASS direct modes: %0d checks, original edge bounds, RAW/GRAY brightness, EDGE independence, combined view does not fuse, incomplete sample rejects",checked);$finish;
end
endmodule
