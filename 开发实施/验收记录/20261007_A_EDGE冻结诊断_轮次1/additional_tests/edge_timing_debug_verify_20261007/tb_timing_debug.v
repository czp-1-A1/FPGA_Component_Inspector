`timescale 1ns/1ps
module tb_timing_debug;
reg clk=0; always #4.444 clk=~clk;
reg rst_n=0,valid=0,sof=0,last=0,early=0,ready=1;
reg [95:0] rgb=0;reg [1:0] mode=0;
wire bad,ov,ol,oe;wire [95:0] data;wire [10:0] x;wire [9:0] y;
wire [12:0] cp,ec;wire [23:0] es;wire [31:0] debug;
wire cbad,cov,col,coe;wire [95:0] cdata;wire [10:0] cx;wire [9:0] cy;
wire [12:0] ccp,cec;wire [23:0] ces;
roi_sobel_view #(.HEIGHT(4),.X0(0),.X1(1024),.Y0(0),.Y1(4),
 .CORE_X0(4),.CORE_X1(80),.CORE_Y0(1),.CORE_Y1(3)) dut(
 .clk(clk),.rst_n(rst_n),.pixel_valid(valid),.pixel_sof(sof),.pixel_last(last),
 .early_sof(early),.rgb(rgb),.mode(mode),.invalidate(1'b0),.view_ready(ready),
 .frame_bad(bad),.out_valid(ov),.out_last(ol),.out_early_sof(oe),.out_rgb(data),
 .out_x(x),.out_y(y),.core_pixels(cp),.edge_count(ec),.edge_sum(es),.timing_debug(debug));
roi_sobel_view_no_debug #(.HEIGHT(4),.X0(0),.X1(1024),.Y0(0),.Y1(4),
 .CORE_X0(4),.CORE_X1(80),.CORE_Y0(1),.CORE_Y1(3)) control(
 .clk(clk),.rst_n(rst_n),.pixel_valid(valid),.pixel_sof(sof),.pixel_last(last),
 .early_sof(early),.rgb(rgb),.mode(mode),.invalidate(1'b0),.view_ready(ready),
 .frame_bad(cbad),.out_valid(cov),.out_last(col),.out_early_sof(coe),.out_rgb(cdata),
 .out_x(cx),.out_y(cy),.core_pixels(ccp),.edge_count(cec),.edge_sum(ces));
reg [31:0] epoch_snapshot=0;
integer cycles=0,compared_cycles=0,compared_beats=0,raw_reference_beats=0;
integer cases=0,first_start=0,second_start=0,third_start=0;
always @(posedge clk) begin
 cycles=cycles+1;
 if(!rst_n) epoch_snapshot<=0;
 else if(early) epoch_snapshot<=debug;
 #1;
 if(rst_n) begin
  compared_cycles=compared_cycles+1;
  if({bad,ov,ol,oe,x,y,cp,ec,es} !== {cbad,cov,col,coe,cx,cy,ccp,cec,ces})
   $fatal(1,"diagnostics change video control cycle=%0d debug=%h",cycles,debug);
  if(dut.read_issue !== control.read_issue || dut.cache_overrun !== control.cache_overrun ||
     {dut.reading,dut.read_y,dut.read_group,dut.ready_rows,dut.input_armed} !==
     {control.reading,control.read_y,control.read_group,control.ready_rows,control.input_armed})
   $fatal(1,"diagnostics change flow/cache control cycle=%0d",cycles);
  if(ov) begin
   compared_beats=compared_beats+1;
   if(data !== cdata) $fatal(1,"diagnostics change video RGB cycle=%0d",cycles);
  end
  if(mode==0 && valid && !early && (sof || dut.input_armed)) begin
   raw_reference_beats=raw_reference_beats+1;
   if(!ov || data !== rgb || ol !== last) $fatal(1,"RAW direct reference mismatch cycle=%0d",cycles);
  end
 end
end
function [95:0] pattern;
 input integer row,group;
 integer lane,r,g,b;reg[95:0] result;
 begin
  result=0;
  for(lane=0;lane<4;lane=lane+1) begin
   r=(row*41+group*3+lane*7)%256;g=(row*13+group*5+lane*11)%256;b=(row*19+group*7+lane*17)%256;
   result[95-lane*24-:24]={r[7:0],g[7:0],b[7:0]};
  end
  pattern=result;
 end
endfunction
task step;
 input vv,ss,ll,ee,rr;input[95:0] color;
 begin
  @(negedge clk);valid=vv;sof=ss;last=ll;early=ee;ready=rr;rgb=color;
  @(posedge clk);#2;
 end
endtask
task idle;
 input integer count;input rr;integer k;
 begin for(k=0;k<count;k=k+1) step(0,0,0,0,rr,0);end
endtask
task row;
 input integer number;input rr;integer group;
 begin
  for(group=0;group<256;group=group+1) begin
   step(1,number==0 && group==0,group==255,0,rr,pattern(number,group));
   if(group==0) begin
    if(number==0) first_start=cycles;
    if(number==1) second_start=cycles;
    if(number==2) third_start=cycles;
   end
  end
 end
endtask
task begin_epoch;
 input[1:0] mm;
 begin
  @(negedge clk);mode=mm;
  step(0,0,0,1,1,0);
  if(debug !== 32'd0 || dut.period_seen!==0 || dut.line_seen!==0)
   $fatal(1,"early fails clearing current diagnostic debug=%h",debug);
 end
endtask
task check_lp;
 input integer interval;input[15:0] expected;
 begin
  begin_epoch(0);row(0,1);
  if(debug[31:16] !== 0 || dut.period_seen!==0) $fatal(1,"one-line LP is not unmeasured zero");
  idle(interval-256,1);row(1,1);
  if(second_start-first_start != interval) $fatal(1,"test stimulus interval incorrect");
  if(debug !== {expected,16'd0} || dut.period_seen!==1)
   $fatal(1,"LP interval=%0d expected=%h got=%h",interval,expected,debug);
  $display("CHECK LP exact interval=%0d LP=%h WS=%h period_seen=%b",interval,debug[31:16],debug[15:0],dut.period_seen);
  cases=cases+1;
 end
endtask
task pending;
 input[1:0] mm;
 begin
  begin_epoch(mm);row(0,0);row(1,0);
  if(mm[1] && (dut.ready_rows!==1 || dut.read_y!==0 || dut.reading!==0 || bad))
   $fatal(1,"test failed creating actual pending row without force");
  if(debug !== {16'd256,16'd0}) $fatal(1,"pending-row starting diagnostic incorrect %h",debug);
 end
endtask
task check_ws;
 input integer waiting;input[15:0] expected;reg[31:0] old;
 begin
  pending(2);idle(waiting,0);
  old={16'd256,expected};
  if(debug !== old || bad) $fatal(1,"WS waiting=%0d expected=%h got=%h bad=%b",waiting,old,debug,bad);
  // Credit release starts the real row. Mid-row credit loss must not count as a wait.
  step(0,0,0,0,1,0);
  if(dut.wait_cycles!==0 || debug!==old || dut.reading!==1) $fatal(1,"credit release failed");
  idle(270,0);
  if(debug!==old || bad || dut.read_y!==1) $fatal(1,"mid-row low credit incorrectly counted or row failed");
  step(0,0,0,1,0,0);
  if(debug!==0 || epoch_snapshot!==old) $fatal(1,"same-edge snapshot/clear mismatch old=%h snap=%h curr=%h",old,epoch_snapshot,debug);
  $display("CHECK WS exact waiting=%0d WS=%h snapshot=%h continuous replay preserved",waiting,expected,epoch_snapshot);
  cases=cases+1;
 end
endtask
reg[31:0] wanted;
initial begin
 idle(3,1);@(negedge clk);rst_n=1;
 check_lp(256,16'd256);check_lp(257,16'd257);check_lp(640,16'd640);
 check_lp(65535,16'hffff);check_lp(65536,16'hffff);
 begin_epoch(0);row(0,1);idle(65540,1);
 if(debug[31:16]!==0 || dut.period_seen!==0 || dut.line_age!==16'hffff)
  $fatal(1,"saturated one-line age must remain unmeasured LP=0 %h",debug);
 $display("CHECK LP unmeasured period_seen hides saturated age");cases=cases+1;
 begin_epoch(0);row(0,1);idle(384,1);row(1,1);
 if(debug[31:16]!==16'd640) $fatal(1,"LP first period mismatch");
 idle(1,1);row(2,1);
 if(third_start-second_start!==257 || debug[31:16]!==16'd257) $fatal(1,"LP shortest-period update mismatch");
 $display("CHECK LP minimum selects 257 after 640");cases=cases+1;
 check_ws(0,0);check_ws(1,1);check_ws(2,2);check_ws(65535,16'hffff);check_ws(65536,16'hffff);
 // Early truncates a live pending wait: no input pixel force, no cache overrun.
 pending(3);idle(9,0);wanted={16'd256,16'd9};
 if(debug!==wanted || bad) $fatal(1,"live pending wait setup fails");
 step(1,0,0,1,0,96'hffffff000000ffffff000000);
 if(debug!==0 || epoch_snapshot!==wanted || dut.input_armed!==0)
  $fatal(1,"early truncation loses old wait or accepts stale beat");
 $display("CHECK WS early truncation old=%h current=%h",epoch_snapshot,debug);cases=cases+1;
 // Repeated waits retain max rather than sum.
 pending(2);idle(7,0);step(0,0,0,0,1,0);idle(270,0);row(2,0);idle(3,0);
 if(debug[15:0]!==7 || dut.wait_cycles!==3 || bad) $fatal(1,"WS max accidentally accumulates separate episodes %h",debug);
 $display("CHECK WS separate episodes 7 then 3 keeps maximum 7");cases=cases+1;
 // Actual input cache abort freezes history; diagnostic must not keep growing afterward.
 pending(2);idle(5,0);row(2,0);step(1,0,0,0,0,pattern(3,0));
 if(!bad || debug[15:0]!==262) $fatal(1,"cache-abort last wait mismatch bad=%b WS=%0d",bad,debug[15:0]);
 idle(100,0);
 if(debug[15:0]!==262 || dut.wait_cycles!==0) $fatal(1,"bad frame keeps accumulating wait");
 $display("CHECK WS actual cache abort preserves 262 waited cycles");cases=cases+1;
 pending(0);idle(65536,0);
 if(debug!=={16'd256,16'd0} || bad) $fatal(1,"RAW falsely waits for row credit %h",debug);
 $display("CHECK RAW 65536 low-credit cycles WS=0, LP measured");cases=cases+1;
 pending(1);idle(65536,0);
 if(debug!=={16'd256,16'd0} || bad) $fatal(1,"GRAY falsely waits for row credit %h",debug);
 $display("CHECK GRAY 65536 low-credit cycles WS=0, LP measured");cases=cases+1;
 // New frame measurement must not contain old long gap or previous wait.
 begin_epoch(2);row(0,1);idle(384,1);row(1,1);idle(300,1);
 if(debug!=={16'd640,16'd0}) $fatal(1,"new epoch contaminated diagnostic %h",debug);
 $display("CHECK fresh EDGE epoch LP=640 WS=0 after RAW/GRAY");cases=cases+1;
 $display("PASS independent timing_debug: %0d cases, %0d compared cycles, %0d video beats, %0d RAW RGB reference beats; LP exact/saturation/unmeasured, WS EDGE-only/max/saturation/truncation, same-edge old snapshot and new clear, no diagnostic flow/video changes",cases,compared_cycles,compared_beats,raw_reference_beats);
 $finish;
end
initial begin #10000000;$fatal(1,"test timeout");end
endmodule
