`timescale 1ns/1ps
module tb_demo_select_stage;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,invalidate=0;reg[11:0]distance_drive=0;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(
 .clk(clk),.rst_n(rst_n),.frame_start(1'b0),.pixel_sof(1'b0),.pixel_accept(1'b0),.invalidate(invalidate),
 .pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
 .repair_hold_valid(1'b0),.repair_hold_x(11'd0),.repair_hold_y(10'd0),.repair_hold_radius(6'd0),.repair_empty_only(1'b0),.repair_hold_id(9'd0));
 reg[11:0]values[0:7];reg[7:0]valids;reg region;reg[31:0]rng=32'h20261101;
 reg[2:0]expected_index;reg[11:0]expected_worst;reg expected_free,accept;
 reg[7:0]expected_valid;integer n=0,i,j,bank,mask,pattern,rank;
 task check_case;
  integer k;begin
   @(negedge clk);force dut.phase=dut.SCALE;
   dut.candidate_region=region;dut.high_valid=valids;
   for(k=0;k<8;k=k+1)dut.high_distances[k]=values[k];
   expected_index={region,2'b00};expected_worst=0;expected_free=0;
   // Frozen RL7 selection reference, including last-index tie preference.
   for(k=0;k<4;k=k+1)begin
    if(!valids[region*4+k])begin
     if(!expected_free)expected_index=region*4+k;
     expected_free=1;
    end else if(!expected_free && values[region*4+k]>=expected_worst)begin
     expected_index=region*4+k;expected_worst=values[region*4+k];
    end
   end
   @(posedge clk);#1;
   if({dut.high_free_held,dut.high_write_held,dut.high_worst_held}!=={expected_free,expected_index,expected_worst})
    $fatal(1,"SCALE capture mismatch case%0d",n);
   @(negedge clk);force dut.phase=dut.COMPARE;
   accept=expected_free || distance_drive<expected_worst;
   expected_valid=valids;if(accept)expected_valid[expected_index]=1;
   @(posedge clk);#1;
   if(dut.high_valid!==expected_valid)$fatal(1,"COMPARE write-enable mismatch case%0d",n);
   for(k=0;k<8;k=k+1)begin
    if(dut.high_distances[k]!==((accept && k==expected_index) ? distance_drive:values[k]))
     $fatal(1,"COMPARE changed wrong distance case%0d slot%0d",n,k);
   end
   n=n+1;
  end
 endtask
 initial begin
  force dut.high_shape=1'b1;force dut.candidate_allowed=1'b1;force dut.border=1'b0;
  force dut.component_count=18'd8;force dut.width_now=10'd7;force dut.height_now=10'd7;
  force dut.distance=distance_drive;
  repeat(3)@(negedge clk);rst_n=1;
  for(bank=0;bank<2;bank=bank+1)begin
   region=bank;
   for(mask=0;mask<16;mask=mask+1)begin
    valids=bank ? {mask[3:0],4'b1010}:{4'b0101,mask[3:0]};
    for(pattern=0;pattern<256;pattern=pattern+1)begin
     for(i=0;i<8;i=i+1)values[i]=12'habc;
     for(i=0;i<4;i=i+1)begin
      rank=(pattern>>(i*2))&3;
      case(rank)0:values[bank*4+i]=0;1:values[bank*4+i]=1;2:values[bank*4+i]=2048;3:values[bank*4+i]=4095;endcase
     end
     distance_drive=pattern[1:0]==0 ? 0:pattern[1:0]==1 ? 1:pattern[1:0]==2 ? 2048:4095;
     check_case;
    end
   end
  end
  for(j=0;j<65536;j=j+1)begin
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};region=rng[0];valids=rng[15:8];distance_drive=rng[27:16];
   for(i=0;i<8;i=i+1)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};values[i]=rng[19:8];end
   check_case;
  end
  @(negedge clk);invalidate=1;
  @(posedge clk);#1;release dut.phase;
  if(dut.high_valid!==0)$fatal(1,"invalidated work wrote high-bank valid bits");
  @(negedge clk);invalidate=0;rst_n=0;
  @(posedge clk);#1;
  if({dut.high_free_held,dut.high_write_held,dut.high_worst_held}!==16'd0)$fatal(1,"held selection not reset");
  $display("PASS DEMO_SELECT_STAGE: %0d actual production SCALE->COMPARE cases; same first-free, tie, prefix maximum, distance acceptance and exact bank writes; reset/invalid work cancelled",n);$finish;
 end
endmodule
