`timescale 1ns/1ps
// Exercise the actual selector with the full valid-distance domain and all
// free-slot masks, including ties. The independent reference is the original
// ordered scan: first free slot; last maximum when full.
module tb_d3_distance_selection;
 frame_shape_search #(.DUAL_STOP(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720)) dut(
  .clk(1'b0),.rst_n(1'b0),.frame_start(1'b0),.pixel_sof(1'b0),.pixel_accept(1'b0),.invalidate(1'b0),
  .pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),.recorder_hold_valid(1'b0),.recorder_hold_valid2(1'b0),
  .recorder_hold_x(11'd0),.recorder_hold_x2(11'd0),.recorder_hold_y(10'd0),.recorder_hold_y2(10'd0),
  .station_hold_valid(2'd0),.station_hold_empty_only(2'd0),.station_hold_x(22'd0),.station_hold_y(20'd0),.station_hold_radius(12'd0));
 reg [14:0] actual,want;integer d[0:3];integer mask,k,n,slot,worst,checks=0;
 reg free_slot;reg [31:0] random_state=32'h286b274b;
 initial begin
  if(dut.DIST_BITS!=9 || $bits(dut.distance)!=12)$fatal(1,"distance widths changed incorrectly");
  for(mask=0;mask<16;mask++)for(n=0;n<4096;n++)begin
   for(k=0;k<4;k++)begin
    random_state=random_state^(random_state<<13);random_state=random_state^(random_state>>17);random_state=random_state^(random_state<<5);
    d[k]=(n<512 ? n : random_state%512);
    if(!((mask>>k)&1))d[k]=4095; // invalid reset differs after narrowing
   end
   slot=0;worst=0;free_slot=0;
   for(k=0;k<4;k++)if(!free_slot)begin
    if(!((mask>>k)&1))begin slot=k;free_slot=1;end
    else if(d[k]>=worst)begin worst=d[k];slot=k;end
   end
   want={free_slot,12'(worst),2'(slot)};
   actual=dut.high_slot_choice(4'(mask),12'(d[0]&511),12'(d[1]&511),12'(d[2]&511),12'(d[3]&511));
   if(actual!==want)$fatal(1,"selector changed mask%h n%0d got%h want%h",mask,n,actual,want);
   checks++;
  end
  $display("PASS D3_DISTANCE_SELECTION: %0d actual RTL comparisons, all masks/ties/full 9-bit distances and differing invalid reset values",checks);$finish;
 end
endmodule
