`timescale 1ns/1ps
module tb_empty_probe_pipeline;
 reg clk=0,rst_n=0,fs=0,commit=0,bad=0,sn=0;
 always #5 clk=~clk;
 reg [16:0] command=0;reg [303:0] objects=0;reg [31:0] probe=0;
 wire [255:0] packet,live;wire ready;
 classified_count_pipeline #(.DIAGNOSTICS(1),.STOP_CYCLES(100000),.PAGE_CYCLES(200000)) dut(
  .clk(clk),.rst_n(rst_n),.source_start(fs),.frame_commit(commit),.frame_bad(bad),.sample_new(sn),
  .config_tag(64'h0444002800006464),.objects(objects),.empty_probe(probe),.command(command),
  .frame_record(packet),.record_ready(ready),.live_record(live));
 function [75:0] body(input integer center);
  body={1'b1,2'd2,4'd0,13'd1500,7'd36,7'd44,11'(center-20),11'(center+20),10'd296,10'd344};
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task start_frame;
  begin fs=1;ticks(1);fs=0;ticks(2);if(ready)$fatal(1,"new source kept prior ready");end
 endtask
 task deliver(input [31:0] value,input integer source);
  integer n;begin
   objects={152'd0,body(600+source*4),body(520+source*4)};probe=value;
   commit=1;ticks(1);commit=0;ticks(2);sn=1;ticks(1);sn=0;
   // A later combinational producer value must never leak into this source.
   probe=32'hffffffff;objects=0;n=0;
   while(!ready && n<1000)begin ticks(1);n++;end
   if(!ready || packet[31:0]!=source || packet[255:224]!==value)
    $fatal(1,"diagnostic/source tuple mixed source%0d packet%064h",source,packet);
  end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(5);command=2;ticks(5);
  start_frame();deliver(32'h8a51cfc0,1);
  ticks(20);if(packet[255:224]!==32'h8a51cfc0)$fatal(1,"post-accept producer changed frozen diagnostic");
  start_frame();probe=32'h8a5dc440;commit=1;ticks(1);commit=0;bad=1;ticks(1);bad=0;sn=1;ticks(1);sn=0;ticks(200);
  if(ready)$fatal(1,"canceled source published a diagnostic");
  command=4;ticks(5);start_frame();deliver(32'h8c61cfff,3);
  start_frame();probe=32'h8a51ce40;sn=1;ticks(1);sn=0;ticks(200);
  if(ready)$fatal(1,"unproved source published diagnostic");
  // A next start revokes an unfinished old epoch. Recover with a new segment.
  start_frame();command=6;ticks(5);deliver(32'h8a51ce40,5);
  $display("PASS empty probe pipeline: same-source32bit reserved metadata,post-accept changes ignored,bad/unproved source suppressed,next epoch no stale probe");$finish;
 end
 initial begin #2000000;$fatal(1,"probe pipeline watchdog");end
endmodule
