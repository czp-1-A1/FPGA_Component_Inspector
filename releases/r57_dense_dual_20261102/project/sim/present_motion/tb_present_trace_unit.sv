`timescale 1ns/1ps
module tb_present_trace_unit;
reg clk=0;always #5 clk=~clk;
reg rst=0,cancel=0,we=0,measure=0,ek=0,select_trace=0;
reg [10:0] wx=0;reg [9:0] wy=0;reg [31:0] wd=0;
reg [9:0] x0=0,x1=0,y0=0,y1=0;
wire ready,normal,eok,gr,gn,ge;wire [31:0] edges,gedges;wire [100:0] trace;
local_edge_surface_check #(.TRACE(1),.STANDING_REVIEW(1)) dut(.clk(clk),.rst_n(rst),.cancel(cancel),.write_enable(we),.measure(measure),.measure_empty(ek),.write_x(wx),.write_y(wy),.write_data(wd),.xmin(x0),.xmax(x1),.ymin(y0),.ymax(y1),.ready(ready),.normal(normal),.empty_ok(eok),.edge_strengths(edges),.trace_enable(select_trace),.trace_metrics(trace));
local_edge_surface_check_r22 #(.STANDING_REVIEW(1)) golden(.clk(clk),.rst_n(rst),.cancel(cancel),.write_enable(we),.measure(measure),.measure_empty(ek),.write_x(wx),.write_y(wy),.write_data(wd),.xmin(x0),.xmax(x1),.ymin(y0),.ymax(y1),.ready(gr),.normal(gn),.empty_ok(ge),.edge_strengths(gedges));
reg [19:0] fixture[0:34*12544-1];reg [100:0] expected[0:33];reg [1:0] flags[0:33];reg [39:0] bounds[0:33];reg kinds[0:33];
integer n=0,checks=0,cycles=0,waits,phase_target,t;
reg [19:0] g;reg [100:0] held;
always @(posedge clk)begin #1;if(rst)begin
 if({ready,normal,eok,edges}!=={gr,gn,ge,gedges} || dut.phase!==golden.phase)$fatal(1,"R22 cycle decision/FSM mismatch case%0d",n);
 cycles++;
end end
task clear_frame;begin @(negedge clk);cancel=1;we=0;measure=0;@(negedge clk);cancel=0;if(trace!==0)$fatal(1,"cancel stale trace");end endtask
task capture(input integer ci,input integer skip);
integer yy,xx,k,idx;begin idx=0;
 for(yy=225;yy<616;yy+=2)for(xx=388;xx<896;xx+=8)begin
  g=fixture[ci*12544+idx];wd=0;for(k=0;k<4;k++)wd[k*8+:8]={g[k*5+:5],3'd0};
  wx=xx;wy=yy;we=!(skip && idx==12543);@(negedge clk);idx++;
 end we=0;repeat(2)@(negedge clk);
end endtask
task request(input integer ci,input integer sel);
begin x0=bounds[ci][9:0];x1=bounds[ci][19:10];y0=bounds[ci][29:20];y1=bounds[ci][39:30];ek=kinds[ci];select_trace=sel;measure=1;@(negedge clk);measure=0;end endtask
task await_done;begin waits=0;while(!ready && waits<900)begin @(negedge clk);waits++;end if(!ready)$fatal(1,"deadline");checks++;end endtask
initial begin
 $readmemh("present_motion/unit/fixtures.hex",fixture);$readmemh("present_motion/unit/expected.hex",expected);$readmemh("present_motion/unit/flags.hex",flags);$readmemh("present_motion/unit/bounds.hex",bounds);$readmemh("present_motion/unit/kinds.hex",kinds);
 repeat(5)@(negedge clk);rst=1;
 for(n=0;n<34;n++)begin clear_frame;capture(n,0);request(n,1);await_done;
  if({eok,normal}!==flags[n] || trace!==expected[n])$fatal(1,"independent metrics case%0d got%026h expected%026h",n,trace,expected[n]);
  $display("PTRACE_UNIT case=%0d metrics=%026h wait=%0d",n,trace,waits);
 end
 clear_frame;capture(26,1);request(26,1);await_done;if(trace!==(101'd32))$fatal(1,"capture qualification %026h",trace);
 clear_frame;capture(26,0);request(26,1);await_done;held=trace;
 select_trace=0;x0=x0+3;x1=x1+3;measure=1;@(negedge clk);measure=0;await_done;if(trace!==held)$fatal(1,"other target overwrote selected P");
 clear_frame;capture(26,0);request(26,1);x0=192;x1=209;measure=1;@(negedge clk);measure=0;await_done;
 if(trace!==101'd16)$fatal(1,"cache bbox qualification %026h",trace);
 clear_frame;capture(26,0);request(26,1);x1=x0+14;measure=1;@(negedge clk);measure=0;await_done;
 if(trace!==101'd64)$fatal(1,"undersized qualification %026h",trace);
 for(phase_target=2;phase_target<=7;phase_target++)begin
  clear_frame;capture(26,0);request(26,1);t=0;
  while(dut.phase!=phase_target && t<900)begin @(negedge clk);t++;end
  if(t==900)$fatal(1,"phase coverage");clear_frame;repeat(700)@(negedge clk);
  if(ready || trace!==0)$fatal(1,"abort trace stale");
 end
 $display("PASS PRESENT_TRACE_UNIT: %0d requests, %0d cycles exact R22 FSM/decision equality, independent sums/signed gradients, missing/cache/bbox qualification, overwrite guard and six cancel phases",checks,cycles);$finish;
end
initial begin #40000000;$fatal(1,"watchdog");end
endmodule
