`timescale 1ns/1ps
module tb_replay;
 reg clk=0;always #5 clk=~clk;reg rst=0,fs=0,sof=0,accept=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 reg [7:0] pixels[0:921599];wire ready,oldready;wire [607:0] rec,oldrec;
 frame_shape_search #(.RELAY_LEFT_LAYOUT(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(1'b0),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.ready(ready),.recorder_objects(rec),.repair_hold_valid(1'b0),.repair_hold_x(11'd0),.repair_hold_y(10'd0));
 frame_shape_search_baseline #(.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) baseline(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(1'b0),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.ready(oldready),.recorder_objects(oldrec));
 integer px,py,l,t;
 always @(posedge clk)if(rst)begin
  if(dut.phase==dut.COMPARE && dut.small_pass && dut.center_y>310 && dut.center_y<330)
   $display("NEW COMP x%0d y%0d wh%0d,%0d area%0d bright%0d circ%0d edge%0d base%0d empty%0d state%0d cover%0d row%0d",dut.center_x,dut.center_y,dut.width_now,dut.height_now,dut.component_count,dut.bright_count,dut.circular,dut.edge_aperture_shape,dut.base_empty_geometry,dut.empty_match,dut.candidate_state,dut.covers_body,dut.empty_row_delta);
  if(dut.phase==dut.REF_CHECK && dut.ref_side && dut.ref_word==2 && dut.ref_last_row)
   $display("NEW PROOF x%0d kind%0d ref%0d bg%0d sobel%0d role%0d edge%h",dut.ref_cx*2,dut.state_bank[dut.ref_index],dut.reference_ok,dut.background_reference_ok,dut.surface_empty_ok,dut.edge_role_ok,dut.local_edge_strengths);
  if(baseline.phase==baseline.REF_CHECK && baseline.ref_side && baseline.ref_word==2 && baseline.ref_last_row)
   $display("OLD PROOF x%0d kind%0d ref%0d bg%0d sobel%0d role%0d edge%h",baseline.ref_cx*2,baseline.state_bank[baseline.ref_index],baseline.reference_ok,baseline.background_reference_ok,baseline.surface_empty_ok,baseline.edge_role_ok,baseline.local_edge_strengths);
 end
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 initial begin
  $readmemh("native6.hex",pixels);ticks(5);rst=1;ticks(5);fs=1;ticks(1);fs=0;ticks(3);
  for(py=0;py<720;py++)begin for(px=0;px<1280;px+=4)begin
   x=px;y=py;sof=px==0 && py==0;accept=1;for(l=0;l<4;l++)rgb[95-l*24-:24]={3{pixels[py*1280+px+l]}};
   ticks(1);accept=0;sof=0;end ticks(2);end
  t=0;while((!ready || !oldready) && t<600000)begin ticks(1);t++;end
  if(!ready || !oldready)$fatal(1,"replay deadline");
  $display("NEW RECORD %0152h",rec);$display("OLD RECORD %0152h",oldrec);$finish;
 end
endmodule
