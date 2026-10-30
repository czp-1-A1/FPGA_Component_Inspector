`timescale 1ns/1ps
module tb_high_slot_choice;
 reg [7:0] valid=0;
 reg region=0;
 reg [95:0] distances=0;
 integer checks=0,seed=271029,r,mask,other,code,q,j,n;
 reg [11:0] levels[0:4];
 frame_shape_search #(.WIDTH(64),.HEIGHT(48),.REGIONS(1),.SMALL_HOLES(0)) dut(
  .clk(1'b0),.rst_n(1'b0),.frame_start(1'b0),.pixel_sof(1'b0),.pixel_accept(1'b0),.invalidate(1'b0),
  .pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0));
 frame_shape_search_r27a #(.WIDTH(64),.HEIGHT(48),.REGIONS(1),.SMALL_HOLES(0)) previous(
  .clk(1'b0),.rst_n(1'b0),.frame_start(1'b0),.pixel_sof(1'b0),.pixel_accept(1'b0),.invalidate(1'b0),
  .pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0));
 task compare_choice;
  integer k;
  begin
   // The two detector clocks are held low: deposit selector storage directly,
   // then verify every deposited word before comparing the derived results.
   dut.high_valid=valid;previous.high_valid=valid;
   dut.candidate_region=region;previous.candidate_region=region;
   for(k=0;k<8;k=k+1)begin
    dut.high_distances[k]=distances[k*12+:12];
    previous.high_distances[k]=distances[k*12+:12];
   end
   #1;
   if(dut.high_valid!==valid || previous.high_valid!==valid ||
      dut.candidate_region!==region || previous.candidate_region!==region)
    $fatal(1,"selector stimulus was not applied");
   for(k=0;k<8;k=k+1)begin
    if(dut.high_distances[k]!==distances[k*12+:12] || previous.high_distances[k]!==distances[k*12+:12])
     $fatal(1,"selector distance stimulus was not applied slot=%0d",k);
   end
   if({dut.high_free,dut.high_worst,dut.high_write_index} !==
      {previous.high_free,previous.high_worst,previous.high_write_index})
    $fatal(1,"high-slot mismatch region=%0d valid=%h distances=%h old=%h new=%h",region,valid,distances,
     {previous.high_free,previous.high_worst,previous.high_write_index},
     {dut.high_free,dut.high_worst,dut.high_write_index});
   checks=checks+1;
  end
 endtask
 initial begin
  // Compare the actual old and new production modules. Full detector
  // behavior and source-frame cadence are tested separately without deposits.
  levels[0]=0;levels[1]=1;levels[2]=2;levels[3]=2048;levels[4]=4095;
  // All valid masks in both banks and all weak orderings of four distances,
  // including zero, ties and 12-bit boundaries. Four positive representatives
  // also cover the strictly ordered case without conflating it with zero.
  for(r=0;r<2;r=r+1)begin
   region=r;
   for(mask=0;mask<16;mask=mask+1)for(other=0;other<16;other=other+1)begin
    valid=r ? {mask[3:0],other[3:0]} : {other[3:0],mask[3:0]};
    for(code=0;code<625;code=code+1)begin
     distances={$random(seed),$random(seed),$random(seed)};
     q=code;
     for(j=0;j<4;j=j+1)begin
      distances[(4*r+j)*12+:12]=levels[q%5];q=q/5;
     end
     compare_choice;
    end
   end
  end
  for(n=0;n<100000;n=n+1)begin
   valid=$random(seed);region=$random(seed);
   distances={$random(seed),$random(seed),$random(seed)};
   compare_choice;
  end
  if(checks!=420000)$fatal(1,"incomplete high-slot equivalence run");
  $display("PASS HIGH_SLOT_CHOICE: %0d actual RTL comparisons; both regions, all valid masks, all ordering/tie classes and 100000 full-width random states",checks);
  $finish(0);
 end
endmodule
