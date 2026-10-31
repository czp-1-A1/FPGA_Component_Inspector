`timescale 1ns/1ps
module tb_result_recorder_pipeline;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,source_start=0,frame_commit=0,frame_bad=0,sample_new=0;
 reg [303:0] objects=0;reg [16:0] command=0;
 wire [255:0] live,record;wire ready,ev;wire [15:0] er;wire [8:0] eid;wire [31:0] ef;wire [1:0] ek;wire [3:0] em;
 classified_count_pipeline #(.RECORD_ONLY(1),.STOP_CYCLES(200000),.PAGE_CYCLES(20000)) dut(
  .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(frame_commit),.frame_bad(frame_bad),.sample_new(sample_new),
  .config_tag(64'd123),.objects(objects),.empty_probe(32'hffffffff),.command(command),
  .frame_record(record),.record_ready(ready),.live_record(live),.event_valid(ev),.event_run(er),.event_id(eid),.event_frame(ef),.event_kind(ek),.event_reason(em));
 integer checks=0,events=0,k,saved_generation,saved_frame;
 function [75:0] obj(input integer x,kk);begin obj={1'b1,kk[1:0],4'd0,13'd100,7'd40,7'd40,11'(x-4),11'(x+4),10'd312,10'd328};end endfunction
 task check(input good,input [511:0] msg);begin checks++;if(!good)$fatal(1,"%s live=%h record=%h",msg,live,record);end endtask
 task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
 task frame(input integer x,kk);
  begin
   @(negedge clk);source_start=1;@(negedge clk);source_start=0;frame_commit=1;
   @(negedge clk);frame_commit=0;ticks(2);objects={228'd0,obj(x,kk)};sample_new=1;
   @(negedge clk);sample_new=0;ticks(400);
   check(ready && record[31:0]==dut.source_id,"ready metadata bound to source");
  end
 endtask
 always @(negedge clk)if(ev)begin events++;check(er==dut.counter.run_id && eid==events && ef==dut.source_id,"source event identity");end
 initial begin
  ticks(4);rst_n=1;ticks(10);command=2;ticks(200);
  check(live[50:48]==1 && live[239:224]==1,"new visible run1");
  for(k=0;k<16;k++)frame(560+k*8,3);
  check(events==1 && live[66:58]==1 && live[84:76]==1 && live[138:130]==1 && live[210:202]==1,"empty count and page1 before clear");
  saved_generation=live[47:32];saved_frame=live[31:0];
  // Clear while pixels/CSI are stopped; no hardware reset or further frame.
  command=5;ticks(500);
  check(live[50:48]==0 && live[239:224]==0 && live[93:58]==0,"clear RUN and all totals without CSI");
  check(live[222:217]==0 && live[201:94]==0 && live[216:202]==0 && !ready && record==0,"clear IDs/last/page and invalidate old frame");
  check(live[47:32]==saved_generation && live[31:0]==saved_frame,"internal generation/source do not rewind");
  ticks(2000);check(events==1 && live[50:48]==0 && live[239:224]==0,"held clear request cannot repeat or restart");
  command=6;events=0;ticks(200);
  check(live[239:224]==1 && live[47:32]==saved_generation+1,"new visible run1 distinct internal generation");
  for(k=0;k<16;k++)frame(560+k*8,2);
  check(events==1 && live[66:58]==1 && live[75:67]==1 && live[84:76]==0 && live[201:130]==0,"no stale empty list in next run");
  // Clear preempts the core while association/page fetch is still busy.
  @(negedge clk);source_start=1;@(negedge clk);source_start=0;frame_commit=1;@(negedge clk);frame_commit=0;
  ticks(2);objects={228'd0,obj(600,3)};sample_new=1;@(negedge clk);sample_new=0;ticks(12);command=9;ticks(500);
  check(live[50:48]==0 && live[239:224]==0 && live[93:58]==0 && live[216:94]==0 && !ready,"clear busy event/fetch cannot resurrect data");
  $display("PASS result recorder pipeline: %0d checks, source/empty pages/CSI stop/clear/busy/generation",checks);$finish;
 end
 initial begin #10000000;$fatal(1,"pipeline timeout");end
endmodule
