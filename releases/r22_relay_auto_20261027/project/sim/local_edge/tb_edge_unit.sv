`timescale 1ns/1ps
module tb_edge_unit;
reg clk=0;always #5 clk=~clk;
reg rst=0,cancel=0,we=0,measure=0,empty_kind=0;reg [10:0] wx=0;reg [9:0] wy=0;reg [31:0] wd=0;
reg [9:0] x0=0,x1=0,y0=0,y1=0;wire ready,normal,empty_ok;wire [31:0] strengths;
local_edge_surface_check #(.STANDING_REVIEW(1)) dut(.clk(clk),.rst_n(rst),.cancel(cancel),.write_enable(we),.measure(measure),.measure_empty(empty_kind),.write_x(wx),.write_y(wy),.write_data(wd),.xmin(x0),.xmax(x1),.ymin(y0),.ymax(y1),.ready(ready),.normal(normal),.empty_ok(empty_ok),.edge_strengths(strengths));
localparam N=33,WORDS=12544;
reg [19:0] fixture[0:N*WORDS-1];reg [31:0] edges[0:N-1];reg [1:0] flags[0:N-1];reg [39:0] bounds[0:N-1];reg kinds[0:N-1];
integer current=0,checks=0,reads=0,waits=0,negative=0,positive=0;
task clear_frame;begin @(negedge clk);cancel=1;we=0;measure=0;@(negedge clk);cancel=0;end endtask
task capture(input integer n,input integer skip_last);
integer yy,xx,k,idx;reg [19:0] word_gray;
begin
 idx=0;
 for(yy=225;yy<616;yy=yy+2)for(xx=388;xx<896;xx=xx+8)begin
  word_gray=fixture[n*WORDS+idx];wd=0;for(k=0;k<4;k=k+1)wd[k*8+:8]={word_gray[k*5+:5],3'b000};
  wx=xx;wy=yy;we=!(skip_last && idx==WORDS-1);@(negedge clk);idx=idx+1;
 end
 we=0;repeat(2)@(negedge clk);if(idx!=WORDS)$fatal(1,"capture extent");
end endtask
task start_measure(input integer n);
begin
 x0=bounds[n][9:0];x1=bounds[n][19:10];y0=bounds[n][29:20];y1=bounds[n][39:30];empty_kind=kinds[n];
 measure=1;@(negedge clk);measure=0;
end endtask
task await_result(input integer n,input integer valid_frame);
begin
 waits=0;while(!ready && waits<900)begin @(negedge clk);waits=waits+1;end
 if(!ready)$fatal(1,"deadline case%0d",n);
 if({empty_ok,normal}!==(valid_frame ? flags[n] : 2'd0))$fatal(1,"decision case%0d actual%0h expected%0h",n,{empty_ok,normal},flags[n]);
 if(valid_frame && strengths!==edges[n])$fatal(1,"Sobel exact sign/word/quantization case%0d actual%08h expected%08h",n,strengths,edges[n]);
 if(valid_frame)begin if(flags[n]!=0)positive=positive+1;else negative=negative+1;end
 checks=checks+1;
 $display("EDGE_UNIT case=%0d flags=%0h edge=%08h wait=%0d",n,{empty_ok,normal},strengths,waits);
end endtask
integer n,target,pause_count;
initial begin
 $readmemh("local_edge/fixtures.hex",fixture);$readmemh("local_edge/expected_edges.hex",edges);$readmemh("local_edge/expected_flags.hex",flags);$readmemh("local_edge/bounds.hex",bounds);$readmemh("local_edge/kinds.hex",kinds);
 repeat(5)@(negedge clk);rst=1;
 for(n=0;n<N;n=n+1)begin current=n;clear_frame;capture(n,0);start_measure(n);await_result(n,1);end
 clear_frame;capture(0,1);start_measure(0);await_result(0,0);
 for(target=2;target<=7;target=target+1)begin
  clear_frame;capture(26,0);start_measure(26);pause_count=0;
  while(dut.phase!=target && pause_count<900)begin @(negedge clk);pause_count=pause_count+1;end
  if(dut.phase!=target)$fatal(1,"abort phase not reached %0d",target);
  clear_frame;repeat(900)@(negedge clk);if(ready || normal || empty_ok)$fatal(1,"abort stale result %0d",target);
  start_measure(26);await_result(26,0);
 end
 clear_frame;capture(0,0);start_measure(0);await_result(0,1);start_measure(0);await_result(0,1);
 if(positive<20 || negative<5)$fatal(1,"nonzero positive/negative coverage");
 $display("PASS LOCAL_EDGE_UNIT: %0d requests; exact signed four-side Sobel and same-frame surface, %0d positive %0d negative, four RAM phases, missing capture, six cancel phases and restart",checks,positive,negative);$finish;
end
initial begin #30000000;$fatal(1,"unit watchdog");end
endmodule
