`timescale 1ns/1ps
module tb_two_region_count;
 reg clk=0,rst_n=0,fs=0,commit=0,sn=0,bad=0;
 always #5 clk=~clk;
 reg [607:0] objects=0;reg [16:0] command=0;
 wire [511:0] packet,live;wire ready;wire [1:0] ev;
 wire [31:0] er;wire [17:0] ei;wire [63:0] ef;wire [3:0] ek;wire [7:0] em;
 integer events[0:1];integer f,n,scenario,bank,frame_no=0;
 wire [255:0] original_live;
 // The unmodified single-region pipeline sees the same two-bank observations.
 classified_count_pipeline #(.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),
  .OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.LOCAL_RECOVERY(1),
  .STOP_CYCLES(2000000)) original_single_region(
  .clk(clk),.rst_n(rst_n),.source_start(fs),.frame_commit(commit),.frame_bad(bad),.sample_new(sn),
  .config_tag(64'd1),.objects(objects),.empty_probe(32'd0),.command(command),.live_record(original_live));
 dual_region_count_pipeline #(.STOP_CYCLES(2000000),.PAGE_CYCLES(1733)) dut(
  .clk(clk),.rst_n(rst_n),.source_start(fs),.frame_commit(commit),.frame_bad(bad),.sample_new(sn),
  .config_tag(64'd1),.objects(objects),.empty_probe(32'd0),.command(command),
  .frame_record(packet),.live_record(live),.record_ready(ready),
  .event_valid(ev),.event_run(er),.event_id(ei),.event_frame(ef),.event_kind(ek),.event_reason(em));
 function [75:0] object_at(input integer cx,cy,kind,mask);
  integer half;begin half=kind==3?4:19;
   object_at={1'b1,2'(kind),4'(mask),13'd100,7'd38,7'd38,11'(cx-half),11'(cx+half),10'(cy-10),10'(cy+10)};
  end
 endfunction
 always @(negedge clk)for(integer b=0;b<2;b++)if(ev[b])begin
  events[b]++;
  if(ei[b*9+:9]!=events[b] || er[b*16+:16]!=scenario+1)$fatal(1,"region%0d wrong per-run ID",b);
  if(scenario==0)begin
   if(ef[b*32+:32]!=(events[b]==1?8:events[b]==2?13:18))$fatal(1,"wrong source frame");
   if(ek[b*2+:2]!=(b==0 ? (events[b]==1?3:2) : (events[b]==3?3:2)))$fatal(1,"wrong per-ID class");
   if(em[b*4+:4]!=(b==0 ? (events[b]==3?4:0) : (events[b]==2?1:0)))$fatal(1,"wrong per-ID review reason");
  end
 end
 task send;
  begin
   @(negedge clk);fs=1;frame_no++;@(negedge clk);fs=0;
   repeat(3)@(negedge clk);commit=1;@(negedge clk);commit=0;
   repeat(3)@(negedge clk);sn=1;@(negedge clk);sn=0;
   repeat(2)@(negedge clk);n=0;
   while(!ready)begin @(negedge clk);n++;if(n>4000)$fatal(1,"unbounded dual work");end
   repeat(3)@(negedge clk);
   for(integer b=0;b<2;b++)begin
    if(packet[b*256+:32]!=frame_no || !packet[b*256+223])$fatal(1,"mixed source record");
    if(packet[b*256+66-:9]!=packet[b*256+75-:9]+packet[b*256+84-:9])$fatal(1,"count partition");
   end
  end
 endtask
 initial begin
  events[0]=0;events[1]=0;repeat(5)@(negedge clk);rst_n=1;
  for(scenario=0;scenario<3;scenario++)begin
   @(negedge clk);command={16'(scenario*2+1),1'b0};events[0]=0;events[1]=0;
   repeat(120)@(negedge clk);
   if(live[66:58]!=0 || live[322:314]!=0)$fatal(1,"new-run stale totals");
   for(f=0;f<=25;f++)begin
    objects=0;
    for(bank=0;bank<2;bank++)for(integer slot=0;slot<3;slot++)begin
     integer cx,kind,mask;
     cx=480+50*slot+10*f;
     if(bank==1)cx=1280-cx;
     if(scenario==1 && bank==0 && f>=5)cx=480+50*slot+40-10*(f-4);
     kind=bank==0 ? (slot==2?3:2) : (slot==0?3:2);
     mask=bank==0 ? (slot==0?4:0) : (slot==1?1:0);
     if(!(scenario==2 && bank==0 && f>=4))objects[bank*304+slot*76+:76]=object_at(cx,bank==0?320:480,kind,mask);
    end
    send();
   end
   if(live[322:314]!=3 || live[331:323]!=2 || live[340:332]!=1 || live[349:341]!=1 || events[1]!=3)
    $fatal(1,"ROI2 was blocked by ROI1 scenario%0d T%0d P%0d E%0d R%0d",scenario,live[322:314],live[331:323],live[340:332],live[349:341]);
   if(scenario==0)begin
    if(original_live[66:58]!=0 || original_live[50:48]!=1 || original_live[54:51]!=2)
     $fatal(1,"original single-region C2 conflict was not reproduced");
    if(live[66:58]!=3 || live[75:67]!=2 || live[84:76]!=1 || live[93:85]!=1 || events[0]!=3)$fatal(1,"ROI1 totals");
    if(dut.regions[0].pipeline.counter.ledger[0]!={2'd3,4'd0} ||
       dut.regions[0].pipeline.counter.ledger[1]!={2'd2,4'd0} ||
       dut.regions[0].pipeline.counter.ledger[2]!={2'd2,4'd4} ||
       dut.regions[1].pipeline.counter.ledger[0]!={2'd2,4'd0} ||
       dut.regions[1].pipeline.counter.ledger[1]!={2'd2,4'd1} ||
       dut.regions[1].pipeline.counter.ledger[2]!={2'd3,4'd0})$fatal(1,"per-number state ledger");
    repeat(10)send();
    if(events[0]!=3 || events[1]!=3)$fatal(1,"stationary/repeated display duplicate");
   end else if(events[0]!=0)$fatal(1,"absent/reversed ROI1 fabricated event");
   if(scenario==1 && (live[50:48]!=3 || live[54:51]!=5))$fatal(1,"ROI1 reverse protection");
   @(negedge clk);command={16'(scenario*2+2),1'b1};repeat(150)@(negedge clk);
   if(live[66:58]!=0 || live[322:314]!=0 || live[201:130]!=0 || live[457:386]!=0)$fatal(1,"dual full clear");
  end
  $display("PASS two region count: independent opposite directions, per-ID P/E/review ledger and events, pauses, one-region reverse/loss, source binding, reset");$finish;
 end
 initial begin #20000000;$fatal(1,"dual count watchdog");end
endmodule
