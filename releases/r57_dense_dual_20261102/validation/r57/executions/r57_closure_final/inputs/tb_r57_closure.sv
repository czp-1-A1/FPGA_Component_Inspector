`timescale 1ns/1ps
module tb_r57_closure;
 reg clk=0,rst=0,fs=0,sof=0,accept=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sample;wire [303:0] display_objects;wire [607:0] main_objects,station_objects;
 frame_shape_search #(.DUAL_STOP(1),.DUAL_REGION_COUNT(1),.SPARSE_ROW_SCAN(1),
  .PRESENT_TRACE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),
  .EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),
  .STANDING_REVIEW(1),.SURFACE_REVIEW(1),.COUNT_EMPTY_MARGIN(1),
  .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(
  .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),
  .invalidate(1'b0),.pixel_x(x),.pixel_y(y),.rgb(rgb),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0),
  .station_hold_valid(2'd0),.station_hold_empty_only(2'd0),
  .station_hold_x(22'd0),.station_hold_y(20'd0),.station_hold_radius(12'd0),
  .ready(ready),.sample_new(sample),.region_objects(display_objects),
  .recorder_objects(main_objects),.station_objects(station_objects));

 reg [3:0] expected[0:255];integer fg,seed,k;
 initial begin
 $readmemh("closure_graph.hex",expected);
 for(fg=0;fg<16;fg++)for(seed=0;seed<16;seed++)begin
  if(dut.lane_closure(fg,seed)!==expected[fg*16+seed])$fatal(1,"four-connectivity closure mismatch");
  if(dut.lanes_count(fg)!=$countones(4'(fg)))$fatal(1,"area increment mismatch");
  if(fg!=0)begin
   k=0;while(!((fg>>k)&1))k++;
   if(dut.first_lane(fg)!=k)$fatal(1,"left bound mismatch");
   k=3;while(!((fg>>k)&1))k--;
   if(dut.last_lane(fg)!=k)$fatal(1,"right bound mismatch");
  end
 end
 $display("PASS R57_CLOSURE: all256 foreground/seed graphs vs independent BFS, exact area count and left/right bounds");$finish;
 end
endmodule

