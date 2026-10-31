`timescale 1ns/1ps
// Pair complete production modules through the existing RAM wait/check clocks.
// The old RAM output differs from the fresh word; no prepared predicate may
// depend on that old output. Injected states supplement real-pixel tests.
module d3_fss_ref_prepare_case #(parameter C=0)(output reg done=0);
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,fs=0,cancel=0,sof=0;reg [7:0] threshold=0;
 localparam R=C!=0,D=C>=2,CTX=C>=3;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(R),.DUAL_STOP(D),.DUAL_REGION_COUNT(D),.COUNT_CANDIDATES(D),.SMALL_HOLES(R),.ROBUST_EMPTY_CONTEXT(CTX),.REVIEW_PROBE(1),.LOCAL_EDGE_ASSIST(0)) dut(.clk(clk),.rst_n(rst_n),.frame_start(fs),.invalidate(cancel),.pixel_sof(sof),.pixel_accept(1'b0),.pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),.station_hold_valid(2'd0),.recorder_hold_valid(1'b0),.recorder_hold_valid2(1'b0));
 r50_reference_frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(R),.DUAL_STOP(D),.DUAL_REGION_COUNT(D),.COUNT_CANDIDATES(D),.SMALL_HOLES(R),.ROBUST_EMPTY_CONTEXT(CTX),.REVIEW_PROBE(1),.LOCAL_EDGE_ASSIST(0)) baseline(.clk(clk),.rst_n(rst_n),.frame_start(fs),.invalidate(cancel),.pixel_sof(sof),.pixel_accept(1'b0),.pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),.station_hold_valid(2'd0),.recorder_hold_valid(1'b0),.recorder_hold_valid2(1'b0));
 integer n,j,seed=192713+C,checks=0,mode,body_finals=0,empty_finals=0,context_checks=0;reg [7:0] fresh;reg [8:0] value;
 `define SAME(field,val) begin dut.field=val;baseline.field=val;end
 task compare_state;
 begin
  if({dut.phase,dut.left_dark,dut.right_dark,dut.context_dark,dut.context_good,dut.context_vertical_ok,dut.context_left_ok,dut.context_left_edge,dut.context_edge_dark,dut.context_upper_edge_ok,dut.ref_index,dut.ref_row,dut.ref_side,dut.ref_word,dut.ready,dut.sample_new,dut.state,dut.review_required} !==
     {baseline.phase,baseline.left_dark,baseline.right_dark,baseline.context_dark,baseline.context_good,baseline.context_vertical_ok,baseline.context_left_ok,baseline.context_left_edge,baseline.context_edge_dark,baseline.context_upper_edge_ok,baseline.ref_index,baseline.ref_row,baseline.ref_side,baseline.ref_word,baseline.ready,baseline.sample_new,baseline.state,baseline.review_required})
   $fatal(1,"FSS REF_CHECK state/cancellation changed case%0d sample%0d mode%0d",C,n,mode);
  for(integer s=0;s<dut.SLOTS;s++)
   if({dut.reason_bank[s],dut.state_bank[s],dut.dark_bank[s]} !== {baseline.reason_bank[s],baseline.state_bank[s],baseline.dark_bank[s]})
    $fatal(1,"FSS reference writeback changed C%0d n%0d slot%0d",C,n,s);
 end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;repeat(2)@(negedge clk);
  force dut.ref_min=threshold;force baseline.ref_min=threshold;
  for(n=0;n<2000;n++)begin
   @(negedge clk);fs=0;cancel=0;sof=0;rst_n=1;mode=n%17;
   `SAME(phase,5'd16);`SAME(ref_index,0);`SAME(ref_side,n[0]);`SAME(ref_word,3'(n%3));
   for(j=0;j<dut.SLOTS;j++)begin
    `SAME(found_bank[j],1'b1);`SAME(state_bank[j],2'(n%3+1));`SAME(reason_bank[j],4'(n%16));`SAME(dark_bank[j],16'd0);
   end
   `SAME(ref_row,7'(n%4==0 ? (R && n%3==2 ? 7 : 39) : n%8));
   if(n%7==0)begin
    `SAME(ref_side,1'b1);`SAME(ref_word,3'd2);`SAME(ref_row,7'(R && n%3==2 ? 7 : 39));
   end
   `SAME(ref_mask,4'(n%16));`SAME(small_pass,1'b0);
   threshold=8'(n%256);value=n%5==0 ? 9'(508+n%4) : 9'($random(seed));`SAME(right_dark,value);
   value=9'($random(seed));`SAME(left_dark,value);
   `SAME(context_dark,6'(n%64));`SAME(context_good,2'(n%4));`SAME(context_vertical_ok,n[1]);
   `SAME(context_left_ok,n[2]);`SAME(context_left_edge,n[3]);`SAME(context_edge_dark,3'(n%8));`SAME(context_upper_edge_ok,n[4]);
   `SAME(origin_x,10'd260);`SAME(origin_y,10'd160);`SAME(forward_valid,1'b0);
   // A real synchronous read changes mask_read on the REF_WAIT edge.
   fresh=8'($random(seed));`SAME(mask[0],fresh);`SAME(mem_addr,16'd0);`SAME(mask_read,~fresh);
   @(negedge clk);
   if(dut.phase!==5'd17 || baseline.phase!==5'd17 || dut.mem_q!==fresh)$fatal(1,"fresh RAM wait sequencing failed");
   if(dut.dark_word>4 || dut.background_reference_ok!==baseline.background_reference_ok || dut.reference_ok!==baseline.reference_ok)
    $fatal(1,"prepared predicate differs with fresh RAM C%0d n%0d dark%0d min%0d left%0d right%0d",C,n,dut.dark_word,threshold,dut.left_dark,dut.right_dark);
   if(dut.context_ref)context_checks++;
   if(dut.ref_side && dut.ref_word==2 && dut.ref_last_row && mode>4)begin
    if(dut.state_bank[0]==2 && dut.reason_bank[0]!=4'hf)body_finals++;
    if(dut.state_bank[0]==3)empty_finals++;
   end
   // Exercise actual final reference and generic-F bypass writes as well as
   // in-loop context updates. Cancel on the consuming edge for three modes.
   if(mode==1)fs=1;
   if(mode==2)cancel=1;
   if(mode==3)rst_n=0;
   if(mode==4)sof=1;
   @(negedge clk);compare_state();checks++;
   fs=0;cancel=0;sof=0;rst_n=1;
  end
  if(body_finals<40 || empty_finals<40 || CTX && context_checks<100)$fatal(1,"reference final/context coverage missing");
  $display("PASS FSS full-module REF_WAIT/CHECK case%0d: %0d pairs, %0d body finals %0d empty finals %0d context checks; fresh RAM/writeback/threshold/wrap/reset/cancel",C,checks,body_finals,empty_finals,context_checks);
  done=1;
 end
 `undef SAME
endmodule
module tb_d3_fss_ref_prepare;
 wire [3:0] done;
 genvar c;
 generate for(c=0;c<4;c++)begin : pair
  d3_fss_ref_prepare_case #(.C(c)) test_case(done[c]);
 end endgenerate
 initial begin wait(&done);$display("PASS FSS prepared reference full-module boundary suite: 8000 paired two-clock cases, legacy/region/indexed/four-zone/context, no extra phase");$finish;end
 initial begin #500000;$fatal(1,"FSS reference preparation watchdog");end
endmodule
