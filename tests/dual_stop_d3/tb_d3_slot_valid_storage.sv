`timescale 1ns/1ps
// Independent full R50 module is the oracle, including partial packets made
// visible by malformed capture completion. A single global valid bit would fail.
module d3_slot_valid_case #(parameter C=0)(output reg done=0);
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,fs=0,sof=0,cancel=0,capture=0,last=0;
 reg [75:0] word_value=0;reg [3:0] destination=0,duplicate=0;
 localparam D=C!=0,I=C!=2,SMALL=C!=3;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.DUAL_STOP(D),.DUAL_REGION_COUNT(D),.INDEXED_CANDIDATES(I),.COUNT_CANDIDATES(1),.SMALL_HOLES(SMALL)) dut(.clk(clk),.rst_n(rst_n),.frame_start(fs),.invalidate(cancel),.pixel_sof(sof),.pixel_accept(1'b0),.pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),.station_hold_valid(2'd0),.recorder_hold_valid(1'b0),.recorder_hold_valid2(1'b0));
 r50_reference_frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.DUAL_STOP(D),.DUAL_REGION_COUNT(D),.INDEXED_CANDIDATES(I),.COUNT_CANDIDATES(1),.SMALL_HOLES(SMALL)) baseline(.clk(clk),.rst_n(rst_n),.frame_start(fs),.invalidate(cancel),.pixel_sof(sof),.pixel_accept(1'b0),.pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),.station_hold_valid(2'd0),.recorder_hold_valid(1'b0),.recorder_hold_valid2(1'b0));
 integer n,seed=83091+C,mode,checks=0,clears=0,writes=0,partial_publications=0;
 reg [5:0] phase_value;
 task compare;
 begin
  if(dut.recorder_storage!==baseline.recorder_storage)
   $fatal(1,"word-valid buffer value changed C%0d n%0d mode%0d dest%0d",C,n,mode,destination);
  if({dut.phase,dut.ready,dut.sample_new,dut.located,dut.state,dut.foreground_count,dut.box_width,dut.box_height,dut.box_x0,dut.box_x1,dut.box_y0,dut.box_y1,dut.review_required,dut.objects,dut.region_objects,dut.recorder_objects,dut.station_objects,dut.probe_record,dut.transport_occupied} !==
     {baseline.phase,baseline.ready,baseline.sample_new,baseline.located,baseline.state,baseline.foreground_count,baseline.box_width,baseline.box_height,baseline.box_x0,baseline.box_x1,baseline.box_y0,baseline.box_y1,baseline.review_required,baseline.objects,baseline.region_objects,baseline.recorder_objects,baseline.station_objects,baseline.probe_record,baseline.transport_occupied})
   $fatal(1,"word-valid public behavior changed C%0d n%0d",C,n);
 end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;repeat(2)@(negedge clk);
  force dut.packed_one=word_value;force baseline.packed_one=word_value;
  force dut.pack_destination=destination;force baseline.pack_destination=destination;
  force dut.pack_duplicate=duplicate;force baseline.pack_duplicate=duplicate;
  force dut.cap_write=capture;force baseline.cap_write=capture;
  force dut.cap_last=last;force baseline.cap_last=last;
  for(n=0;n<5000;n++)begin
   @(negedge clk);rst_n=1;fs=0;sof=0;cancel=0;capture=0;last=0;mode=n%47;
   word_value={$random(seed),$random(seed),$random(seed)};
   destination=4'(n%(D ? 16 : 8));duplicate=4'($random(seed));
   phase_value=n%10<6 ? 6'd32 : n%10==6 ? 6'd33 : n%10==7 ? 6'd20 : 6'd0;
   dut.phase=phase_value;baseline.phase=phase_value;
   dut.seen=1;baseline.seen=1;
   if(mode==1)begin fs=1;clears++;end
   if(mode==2)begin cancel=1;clears++;end
   if(mode==3)begin sof=1;clears++;end
   if(mode==4)begin rst_n=0;clears++;end
   if(mode>=5 && mode<=7)begin capture=1;last=mode==6;partial_publications+=mode==6;end
   writes+=phase_value==32 && mode>7;
   #1;compare();
   @(posedge clk);#1;compare();checks++;
  end
  if(clears<400 || writes<1000 || partial_publications<100)$fatal(1,"buffer coverage missing");
  $display("PASS full R50 slot-valid storage case%0d: %0d edge pairs, %0d resets/cancels/SOF, %0d word writes, %0d malformed partial-publication captures",C,checks,clears,writes,partial_publications);
  done=1;
 end
endmodule
module tb_d3_slot_valid_storage;
 wire [3:0] done;
 genvar c;
 generate for(c=0;c<4;c++)begin : pair
  d3_slot_valid_case #(.C(c)) testcase(done[c]);
 end endgenerate
 initial begin wait(&done);$display("PASS SLOT VALID STORAGE: 20000 paired full-module operations, exact private buffer and all public bits before/after clocks, partial/error/reset/legacy modes");$finish;end
 initial begin #1000000;$fatal(1,"slot-valid watchdog");end
endmodule
