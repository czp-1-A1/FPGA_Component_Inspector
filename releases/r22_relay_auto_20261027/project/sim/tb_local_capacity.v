`timescale 1ns/1ps
// Adversarial page/result phases. Every hole is empty so page truth is the
// independent arithmetic sequence 1..300, including the partial final page.
module tb_local_capacity;
 reg clk=0,rst_n=0,fs=0,commit=0,sn=0,bad=0;
 always #5 clk=~clk;
 reg [607:0] objects=0;reg [16:0] command=0;
 wire [255:0] live,packet;wire ready,ev;wire [15:0] er;wire [8:0] ei;wire [31:0] ef;wire [1:0] ek;wire [3:0] em;
 classified_count_pipeline #(.LOCAL_RECOVERY(1),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(3000),.PAGE_CYCLES(403)) dut(
 .clk(clk),.rst_n(rst_n),.source_start(fs),.frame_commit(commit),.frame_bad(bad),.sample_new(sn),
 .config_tag(64'h100),.objects(objects),.command(command),.frame_record(packet),.record_ready(ready),.live_record(live),
 .event_valid(ev),.event_run(er),.event_id(ei),.event_frame(ef),.event_kind(ek),.event_reason(em));
 function [75:0] object_at(input integer center);
  begin object_at={1'b1,2'd3,4'd0,13'd80,7'd8,7'd8,11'(center-4),11'(center+4),10'd316,10'd324};end
 endfunction
 integer frame_no,offset=0,center0,center1,index0,index1,k,checks=0,events=0,wanted;
 reg [255:0] previous=0;reg [63:0] pages_seen=0;
 always @(negedge clk)begin
  if(ev)begin events++;if(ei!=events || er!=1 || ek!=3)$fatal(1,"page test event truth");end
  if(rst_n && live!==previous && live[223])begin
   previous=live;
   if(live[84:76]!=live[66:58] || live[75:67]!=0)$fatal(1,"empty totals torn");
   for(integer lane=0;lane<8;lane++)begin
    wanted=live[222:217]*8+lane+1;if(wanted>live[84:76])wanted=0;
    if(live[130+lane*9+:9]!=wanted)$fatal(1,"torn empty page page%0d lane%0d got%0d expected%0d count%0d",live[222:217],lane,live[130+lane*9+:9],wanted,live[84:76]);
    checks++;
   end
   if(live[84:76]==300)pages_seen[live[222:217]]=1;
  end
 end
 task ticks(input integer count);begin repeat(count)@(negedge clk);end endtask
 initial begin
  ticks(5);rst_n=1;ticks(5);command=2;ticks(5);
  for(frame_no=0;frame_no<4100;frame_no++)begin
   // Two nearest observed targets on an infinite80px tape, sorted by x.
   center0=640+offset%80;center1=center0-80;
   if(center0-640>40)begin center0=center1;center1=center1+80;end
   if(center0>center1)begin k=center0;center0=center1;center1=k;end
   objects={456'd0,object_at(center1),object_at(center0)};
   fs=1;ticks(1);fs=0;ticks(2);commit=1;ticks(1);commit=0;ticks(1);sn=1;ticks(1);sn=0;ticks(494);
   if(live[50:48]==3)$fatal(1,"page race lost reason%0d",live[54:51]);
   offset=offset+6;
  end
  ticks(17000);
  if(events!=300 || live[66:58]!=300 || live[50:48]!=4 || pages_seen[37:0]!={38{1'b1}})$fatal(1,"full page/300 coverage events%0d seen%h",events,pages_seen);
  command=4;ticks(100);if(live[66:58]!=0 || live[84:76]!=0 || live[201:130]!=0)$fatal(1,"new-run page leaked old IDs");
  fs=1;ticks(1);fs=0;ticks(100); // no commit: next epoch must stop safely
  fs=1;ticks(1);fs=0;ticks(100);
  if(live[50:48]!=3 || live[54:51]!=6 || live[66:58]!=0)$fatal(1,"unproved source counted");
  $display("PASS local capacity: %0d atomic page checks, 300 all-empty events, all38 pages, overlapping page/result phases, new-run stale rejection, unproved-frame stop",checks);$finish;
 end
 initial begin #50000000;$fatal(1,"page race timeout");end
endmodule
