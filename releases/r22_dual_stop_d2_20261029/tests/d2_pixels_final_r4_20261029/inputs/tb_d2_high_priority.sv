`timescale 1ns/1ps
module tb_d2_high_priority;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,sof=0,accept=0,cancel=0;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sample;wire [303:0] lower_records;wire [607:0] reference_records;wire reference_ready,reference_sample;wire [127:0] probe,reference_probe;wire occupied,reference_occupied;wire [607:0] records;wire [303:0] display_objects;
 frame_shape_search #(.SECOND_LANE(1),.RELAY_LEFT_LAYOUT(1),.ADJACENT_V6(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),
  .ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),
  .COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(
  .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sample),.second_lane_objects(lower_records),.transport_occupied(occupied),.probe_record(probe),.recorder_objects(records),.region_objects(display_objects),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .repair_hold_valid(1'b0),.repair_hold_x(11'd0),.repair_hold_y(10'd0),.repair_hold_radius(6'd12),.repair_empty_only(1'b0),.repair_hold_id(9'd0));
 d2_reference_frame_shape_search #(.RELAY_LEFT_LAYOUT(1),.ADJACENT_V6(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),
  .ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),
  .COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) baseline(
  .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(reference_ready),.sample_new(reference_sample),.transport_occupied(reference_occupied),.probe_record(reference_probe),.recorder_objects(reference_records),.region_objects(),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .repair_hold_valid(1'b0),.repair_hold_x(11'd0),.repair_hold_y(10'd0),.repair_hold_radius(6'd12),.repair_empty_only(1'b0),.repair_hold_id(9'd0));
 integer pattern=0,checks=0,frames=0,px,py,l,n,v,waited;
 reg [75:0] rec;integer lane,slot,cx,cy,expected,found;
 function integer ellipse(input integer xx,yy,cx,cy,w,h);
  integer dx,dy;begin dx=2*(xx-(cx-w/2))+1-w;dy=2*(yy-(cy-h/2))+1-h;ellipse=dx*dx*h*h+dy*dy*w*w<=w*w*h*h;end
 endfunction
 function integer wanted(input integer row,index);wanted=3;endfunction
 function integer image(input integer xx,yy);
  integer row,k,xxc,yyc,dx,dy,kind;
  begin image=30;
   for(row=0;row<3;row++)for(k=0;k<6;k++)begin
    xxc=row==1 ? 80+k*56 : 480+k*56;yyc=row==2 ? 516 : 320;dx=xx-xxc;dy=yy-yyc;kind=wanted(row,k);
    if(kind==3 && xx>=xxc-4 && xx<xxc+6 && yy>=yyc-4 && yy<yyc+6 && !(((xx-(xxc-4))/2==0 || (xx-(xxc-4))/2==4) && ((yy-(yyc-4))/2==0 || (yy-(yyc-4))/2==4)))image=150;
    if(kind==2 && dx>=-18 && dx<18 && dy>=-22 && dy<22 && !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))image=180;
    if(ellipse(xx,yy,xxc,yyc+40,16,14))image=180;
   end
   // Valid-looking bodies OUTSIDE both ROIs may not consume lane slots.
   if(xx>=20 && xx<56 && yy>=298 && yy<342 || xx>=1000 && xx<1036 && yy>=498 && yy<542)image=180;
  end
 endfunction
 task ticks(input integer k);repeat(k)@(negedge clk);endtask
 task frame(input integer p);
  begin pattern=p;fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px+=4)begin x=px;y=py;sof=px==0 && py==0;accept=1;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   waited=0;while(!(ready && reference_ready) && waited<1500000)begin ticks(1);waited++;end
   if(!reference_ready || !ready)$fatal(1,"dual analysis timeout");ticks(2);
   if(records!==reference_records || probe!==reference_probe || occupied!==reference_occupied)$fatal(1,"original RL7 count/station result changed scene%0d records%h expected%h probe%h ref%h",p,records,reference_records,probe,reference_probe);
   for(lane=0;lane<3;lane++)begin
    found=0;
    for(slot=0;slot<4;slot++)begin
     rec=lane==2 ? lower_records[slot*76+:76] : records[(lane*4+slot)*76+:76];
     if(rec[75])begin found++;checks++;cx=(rec[41:31]+rec[30:20])/2;cy=(rec[19:10]+rec[9:0])/2;
      if(lane==0 ? cx<448 || cx>=832 || cy<240 || cy>=400 : lane==1 ? cx<64 || cx>=448 || cy<240 || cy>=400 : cx<400 || cx>=880 || cy<432 || cy>=600)$fatal(1,"ROI source membership mismatch");
      n=lane==1 ? (cx-80+28)/56 : (cx-480+28)/56;
      if(n<0 || n>5 || (lane==1 ? cx<80+n*56-2 || cx>80+n*56+2 : cx<480+n*56-2 || cx>480+n*56+2))$fatal(1,"not a physical in-ROI object lane%0d cx%0d cy%0d rec%h",lane,cx,cy,rec);
      if(rec[74:73]!=wanted(lane,n))$fatal(1,"scene%0d lane%0d object%0d wrong P/E class got%0d want%0d",p,lane,n,rec[74:73],wanted(lane,n));
     end
    end
    expected=(p==2 && lane==2 || p==3 && lane<2 || p==4) ? 0 : 4;
    if(found!=expected)$fatal(1,"scene%0d lane%0d retained%0d want%0d",p,lane,found,expected);
   end
   if(display_objects!=={records[455:304],records[151:0]})$fatal(1,"display pair mapped to wrong lane");
   for(integer z=0;z<8;z++)begin
    if(dut.high_valid[z]!==baseline.high_valid[z])$fatal(1,"original high-proof validity changed");
    if(dut.high_valid[z] && (dut.high_boxes[z]!==baseline.high_boxes[z] || dut.high_distances[z]!==baseline.high_distances[z]))$fatal(1,"original high-proof selection changed");
   end
   for(integer z=0;z<4;z++)begin
    if(!dut.high_valid[8+z])$fatal(1,"lower high-proof bank not filled");
    if(dut.high_distances[8+z]>104)$fatal(1,"lower high-proof bank kept far object instead of nearer measured hole");
   end
   frames++;
  end
 endtask
 integer attempts=0,full_choices=0;
 always @(posedge clk)if(rst && dut.phase==dut.COMPARE && dut.high_shape && dut.candidate_allowed)begin attempts++;if(!dut.selected_high_free)full_choices++;end
 initial begin
  ticks(5);rst=1;ticks(3);frame(0);
  if(attempts<18 || full_choices<6)$fatal(1,"did not exercise full replacement/drop decisions attempts%0d full%0d",attempts,full_choices);
  $display("PASS D2 HIGH PRIORITY PIPELINE: 18 actual high-threshold holes, 12 retained P/E checks across3zones, original RL7 high proofs identical, full bank replacement and rejection, attempts%0d full%0d",attempts,full_choices);$finish;
 end
 initial begin #200000000;$fatal(1,"dual pixels watchdog");end
endmodule
