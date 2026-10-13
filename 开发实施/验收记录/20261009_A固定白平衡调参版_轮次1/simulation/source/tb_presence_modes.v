`timescale 1ns/1ps
module tb_presence_modes;
reg clk=0,rst=0,accept=0,sof=0,fs=0,bad=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire tape_ok;
always #5 clk=~clk;
roi_tape_guard #(.X0(56),.X1(136),.Y0(24),.Y1(104)) tape(
 clk,rst,accept,sof,fs,bad,x,y,rgb,tape_ok);
reg [1:0] mode=0,gray_state=2;reg scene=1;
reg [12:0] pixels=6400,edges=0;reg [23:0] strength=0;
wire [1:0] state;
roi_mode_classifier classifier(mode,gray_state,scene,pixels,edges,strength,state);
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task check;input [1:0] expected;begin #1;if(state!==expected) $fatal(1,"mode=%d gray=%d scene=%b EC=%d GS=%d expected=%d got=%d",mode,gray_state,scene,edges,strength,expected,state);end endtask
integer row,group,lane,px,index,value;
task image;input integer pattern;input expected;
begin
 fs=1;ticks(1);fs=0;ticks(4);
 for(row=0;row<128;row=row+1) begin
  for(group=0;group<48;group=group+1) begin
   x=group*4;y=row;
   for(lane=0;lane<4;lane=lane+1) begin
    px=group*4+lane;value=175;
    if(row>=24 && row<104 && ((px>=40 && px<56)||(px>=136 && px<152))) begin
     index=(row-24)*16+(px<56 ? px-40 : px-136);value=40;
     case(pattern)
      1:value=175;
      2:if(px>=136)value=175;
      3:value=100;
      4:value=101;
      5:if(index>=960)value=175;
      6:if(index>=959)value=175;
     endcase
    end
    rgb[95-lane*24-:24]={8'(value),8'(value),8'(value)};
    if(pattern==3 && value==100) rgb[95-lane*24-:24]=24'h00c800;
    // A bright locator circle still has dark tape on both sides. This is a
    // deliberate documented counterexample to full automatic alignment.
    if(pattern==8 && (px-96)*(px-96)+(row-64)*(row-64)<900)
     rgb[95-lane*24-:24]=24'hd0d0d0;
   end
   accept=!(pattern==7 && row==70 && group==34);sof=row==0 && group==0;
   ticks(1);accept=0;sof=0;ticks(1+group%2);
  end
 end
 ticks(5);
 if(tape_ok!==expected) $fatal(1,"tape pattern %0d expected=%b got=%b counts=%d/%d dark=%d/%d",pattern,expected,tape_ok,tape.left_count,tape.right_count,tape.left_dark,tape.right_dark);
 $display("OBS tape pattern=%0d valid=%b counts=%0d/%0d dark=%0d/%0d",pattern,tape_ok,tape.left_count,tape.right_count,tape.left_dark,tape.right_dark);
end endtask
initial begin
 ticks(4);rst=1;ticks(4);
 // The same low-MEAN category changes when EC/GS change in EDGE, but not GRAY.
 gray_state=3;mode=1;edges=400;strength=150000;check(3);
 mode=2;check(2);edges=0;strength=0;check(3);
 edges=96;strength=32768;check(2);edges=95;check(1);
 edges=48;strength=16384;check(3);edges=49;check(1);
 edges=400;strength=0;check(1);edges=0;strength=150000;check(1);
 edges=96;strength=32767;check(1);edges=48;strength=16385;check(1);
 pixels=6399;edges=400;strength=150000;check(1);pixels=6400;
 mode=3;gray_state=3;check(1);gray_state=2;check(2);
 edges=0;strength=0;check(1);gray_state=3;check(3);
 mode=0;gray_state=2;check(2);mode=1;check(2);
 scene=0;check(1);mode=2;check(1);scene=1;
 gray_state=1;check(1);gray_state=0;check(0);
 image(0,1);image(1,0);image(2,0);image(3,1);image(4,0);
 image(5,1);image(6,0);image(7,0);image(8,1);
 bad=1;ticks(1);bad=0;ticks(5);if(tape_ok) $fatal(1,"invalid scene retained");
 image(0,1);fs=1;ticks(1);fs=0;ticks(5);if(tape_ok) $fatal(1,"native FS retained scene");
 image(0,1);rst=0;ticks(2);rst=1;ticks(5);if(tape_ok) $fatal(1,"reset retained scene");
 $display("PASS presence modes: independent EDGE/GRAY, inclusive dual-feature bounds/deadband/conflict, incomplete core, background/one-sided guard, PPC4 weighted gray, 75-percent coverage, bubbles/missing beat, reset/FS/invalidate; locator-circle limitation recorded");
 $finish;
end
initial begin #4000000;$fatal(1,"presence modes watchdog");end
endmodule
