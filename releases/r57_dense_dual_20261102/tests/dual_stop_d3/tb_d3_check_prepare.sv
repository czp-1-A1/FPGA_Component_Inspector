`timescale 1ns/1ps
// White-box boundary/cancellation test, separate from real transport tests.
// Stage identical original/candidate records, run the real READ_CHECK/CHECK
// clocks, then compare actual writeback. The old track_word is deliberately
// different from the newly read record to detect same-edge stale-record use.
module d3_check_prepare_case #(parameter C=0)(output reg done=0);
 localparam R=C!=0,M=C>=2,T=C==2 || C>=4,O=C>=2,Q=C>=3,V=C>=4,L=C>=4;
 localparam LINE=C==5 ? 256 : 640,H=R ? 4 : 3;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,start_run=0,finish_run=0,frame_bad=0,sample_new=0;
 wire [31:0] frame_id=0;wire [63:0] config_tag=1;wire [607:0] objects=0;
 wire [8:0] ledger_address=511,empty_address=511;
 observed_classified_pocket_counter #(.LINE_X(LINE),.HYST(H),.RECORD_ONLY(R),.MOTION_RECOVERY(M),.TAIL_RECOVERY(T),.OBS_PER_REGION(4),.ORDERED_HANDOFF(O),.RECOVERABLE(Q),.VELOCITY_ASSOC(V),.LOCAL_RECOVERY(L)) dut(.clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(finish_run),.frame_bad(frame_bad),.sample_new(sample_new),.frame_id(frame_id),.config_tag(config_tag),.objects(objects),.ledger_address(ledger_address),.empty_address(empty_address));
 classified_pocket_counter #(.LINE_X(LINE),.HYST(H),.RECORD_ONLY(R),.MOTION_RECOVERY(M),.TAIL_RECOVERY(T),.OBS_PER_REGION(4),.ORDERED_HANDOFF(O),.RECOVERABLE(Q),.VELOCITY_ASSOC(V),.LOCAL_RECOVERY(L)) reference_counter(.clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(finish_run),.frame_bad(frame_bad),.sample_new(sample_new),.frame_id(frame_id),.config_tag(config_tag),.objects(objects),.ledger_address(ledger_address),.empty_address(empty_address));
 integer seed=74123+C,n,j,k,mode,checks=0;reg [73:0] word;
 reg [31:0] flags;reg [12:0] step;reg [13:0] expected_distance;
 `define SAME(field,value) begin dut.field=value;reference_counter.field=value;end
 task compare;
 begin
  if({dut.phase,dut.state,dut.reason,dut.valid_tracks,dut.armed,dut.used,dut.quarantined,dut.cross_pending,dut.gap_open,dut.frame_trusted,dut.diagnostic,dut.uncertainty_from,dut.total,dut.empty_total,dut.object_ids,dut.busy} !==
     {reference_counter.phase,reference_counter.state,reference_counter.reason,reference_counter.valid_tracks,reference_counter.armed,reference_counter.used,reference_counter.quarantined,reference_counter.cross_pending,reference_counter.gap_open,reference_counter.frame_trusted,reference_counter.diagnostic,reference_counter.uncertainty_from,reference_counter.total,reference_counter.empty_total,reference_counter.object_ids,reference_counter.busy})
   $fatal(1,"CHECK writeback/cancellation changed C%0d sample%0d mode%0d",C,n,mode);
  for(integer z=0;z<32;z++)if(dut.tracks[z]!==reference_counter.tracks[z])
   $fatal(1,"CHECK track writeback changed C%0d sample%0d slot%0d",C,n,z);
 end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  for(j=0;j<32;j++)begin
   word={$random(seed),$random(seed),$random(seed)};
   dut.tracks[j]=word;reference_counter.tracks[j]=word;
  end
  for(n=0;n<5000;n++)begin
   @(negedge clk);mode=n%13;k=n%32;
   start_run=0;finish_run=0;frame_bad=0;sample_new=0;
   `SAME(phase,5'd15);`SAME(state,3'd2);`SAME(reason,4'd0);
   `SAME(busy,1'b1);`SAME(si,6'(k));`SAME(oi,3'd0);
   `SAME(direction_right,n[0]);`SAME(direction_valid,1'b1);
   step=$random(seed);`SAME(first_dx,step);
   step=$random(seed);`SAME(previous_dx,step);
   `SAME(positive,3'(n%4));`SAME(negative,3'((n/4)%4));
   `SAME(motion_count,3'((n/16)%5));`SAME(direct_anchor,n[1]);
   `SAME(motion_conflict,n[2]);`SAME(direct_count,3'(n%5));
   `SAME(visible,3'((n/8)%5));`SAME(pitch,11'(10+n%180));
   `SAME(pitch_valid,1'b1);`SAME(previous_speed,11'(n%33));
   `SAME(valid_tracks,32'hffffffff);`SAME(frame_tracks,32'hffffffff);
   flags=$random(seed);`SAME(used,flags);
   flags=$random(seed);`SAME(armed,flags);
   flags=$random(seed);`SAME(quarantined,flags);
   flags=$random(seed);`SAME(cross_pending,flags);
   `SAME(gap_open,1'b0);`SAME(frame_trusted,1'b1);
   `SAME(diagnostic,16'd0);`SAME(uncertainty_from,9'd0);
   // Alternate counted and armed/unrecorded records; include signed extremes.
   word={$random(seed),$random(seed),$random(seed)};
   word[51:43]=n[3] ? 9'(1+n%300) : 9'd0;
   if(n%17==0)word[73:64]=10'b1000000000;
   if(n%19==0)word[73:64]=10'b0111111111;
   dut.tracks[k]=word;reference_counter.tracks[k]=word;
   word=~word;`SAME(track_word,word);
   // Cancel in READ_CHECK or in CHECK, with the original priority signals.
   if(mode==6)start_run=1;
   if(mode==7)finish_run=1;
   if(mode==8)frame_bad=1;
   if(mode==9)sample_new=1;
   if(mode==10)rst_n=0;
   @(posedge clk);#2;compare();
   if(mode<6 || mode>10)begin
    if(dut.phase!=5)$fatal(1,"READ_CHECK gained a cycle");
    if(dut.track_word!==reference_counter.track_word ||
       dut.gap_motion!==reference_counter.gap_motion ||
       dut.counted_distance!==reference_counter.counted_distance ||
       dut.counted_retire_safe!==reference_counter.counted_retire_safe)
     $fatal(1,"fresh track/signed expression changed C%0d sample%0d",C,n);
    if(dut.check_gap_step!==dut.gap_step ||
       dut.check_retire_anchor!==(dut.motion_count!=0 && (T ? dut.measured_anchor : dut.anchor_consistent)))
     $fatal(1,"frame preparation mismatch C%0d",C);
   end
   @(negedge clk);
   if(mode==11)start_run=1;
   if(mode==12)finish_run=1;
   @(posedge clk);#2;compare();checks++;
   @(negedge clk);rst_n=1;start_run=0;finish_run=0;frame_bad=0;sample_new=0;
  end
  $display("CHECK_PREPARE C%0d checks%0d: original writeback, fresh 32-slot reads, signed boundaries, reset/start/finish/frame_bad/busy",C,checks);
  done=1;
 end
 `undef SAME
endmodule

module tb_d3_check_prepare;
 wire [5:0] done;
 for(genvar c=0;c<6;c++)begin : configurations
  d3_check_prepare_case #(.C(c)) test(done[c]);
 end
 initial begin wait(&done);$display("PASS D3 CHECK PREPARE: 30000 paired original/candidate READ_CHECK/CHECK tests, six configurations, both directions, current track and cancellation priorities");$finish;end
 initial begin #2000000;$fatal(1,"watchdog");end
endmodule
