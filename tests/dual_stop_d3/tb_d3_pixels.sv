`timescale 1ns/1ps
module tb_d3_pixels;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,sof=0,accept=0,cancel=0;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sample,reference_ready,reference_sample;wire [607:0] records,station_records,reference_records;wire [303:0] display_objects;wire [127:0] probe,reference_probe;wire [1:0] occupied;
 frame_shape_search #(.DUAL_STOP(1),.DUAL_REGION_COUNT(1),.SPARSE_ROW_SCAN(1),.PRESENT_TRACE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0),.station_hold_valid(2'd0),.station_hold_x(22'd0),.station_hold_y(20'd0),.station_hold_radius({6'd12,6'd12}),.ready(ready),.sample_new(sample),.station_objects(station_records),.transport_occupied(occupied),.probe_record(probe),.recorder_objects(records),.region_objects(display_objects));
 r27b_reference_frame_shape_search #(.DUAL_REGION_COUNT(1),.SPARSE_ROW_SCAN(1),.PRESENT_TRACE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) baseline(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0),.ready(reference_ready),.sample_new(reference_sample),.probe_record(reference_probe),.recorder_objects(reference_records));
 integer pattern=0,checks=0,frames=0,px,py,l,n,v,waited;
 reg [75:0] rec;integer lane,slot,cx,cy,expected,found;
 function integer ellipse(input integer xx,yy,cx,cy,w,h);
  integer dx,dy;begin dx=2*(xx-(cx-w/2))+1-w;dy=2*(yy-(cy-h/2))+1-h;ellipse=dx*dx*h*h+dy*dy*w*w<=w*w*h*h;end
 endfunction
 function integer wanted(input integer row,index);
  begin wanted=(row==0 ? index==2 : index==1) ? 3 : 2;
   if(pattern==1)wanted=row==0 && (index==1 || index==2) ? 3 : 2;
   if(pattern==2 && row<2 || pattern==3 && row>=2 || pattern==4)wanted=0;
  end
 endfunction
 function integer image(input integer xx,yy);
  integer row,k,xxc,yyc,dx,dy,kind;
  begin image=30;
   for(row=0;row<4;row++)for(k=0;k<4;k++)begin
    xxc=row>=2 ? 120+k*80 : 520+k*80;yyc=row%2 ? 516 : 320;dx=xx-xxc;dy=yy-yyc;kind=wanted(row,k);
    if(kind==3 && ellipse(xx,yy,xxc,yyc,14,12))image=180;
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
   if(records!==reference_records || probe!==reference_probe)$fatal(1,"R27B main result changed scene%0d records%h expected%h probe%h ref%h",p,records,reference_records,probe,reference_probe);
   for(lane=0;lane<4;lane++)begin
    found=0;
    for(slot=0;slot<4;slot++)begin
     rec=lane>=2 ? station_records[((lane-2)*4+slot)*76+:76] : records[(lane*4+slot)*76+:76];
     if(rec[75])begin found++;checks++;cx=(rec[41:31]+rec[30:20])/2;cy=(rec[19:10]+rec[9:0])/2;
      if(lane<2 ? cx<400 || cx>=880 : cx<64 || cx>=400)$fatal(1,"wrong ROI X");
      if(lane%2 ? cy<432 || cy>=600 : cy<240 || cy>=400)$fatal(1,"wrong ROI Y");
      n=lane>=2 ? (cx-120+40)/80 : (cx-520+40)/80;
      if(n<0 || n>3 || (lane>=2 ? cx<120+n*80-2 || cx>120+n*80+2 : cx<520+n*80-2 || cx>520+n*80+2))$fatal(1,"not a physical in-ROI object lane%0d cx%0d cy%0d rec%h",lane,cx,cy,rec);
      if(rec[74:73]!=wanted(lane,n))$fatal(1,"scene%0d lane%0d object%0d wrong P/E class got%0d want%0d",p,lane,n,rec[74:73],wanted(lane,n));
     end
    end
    expected=(p==2 && lane<2 || p==3 && lane>=2 || p==4) ? 0 : 4;
    if(found!=expected)$fatal(1,"scene%0d lane%0d retained%0d want%0d",p,lane,found,expected);
   end
   if(display_objects!=={records[455:304],records[151:0]})$fatal(1,"display pair mapped to wrong lane");
   frames++;
  end
 endtask
 initial begin
  ticks(5);rst=1;ticks(3);frame(0);frame(1);frame(2);frame(3);frame(4);
  cancel=1;ticks(3);cancel=0;ticks(2);if(ready || sample || records!=0 || station_records!=0)$fatal(1,"canceled result remained valid");frame(0);
  $display("PASS D3 FOUR ZONES R27B MAIN EQUIVALENCE: %0d full RGB frames, %0d real object checks, upper/lower count+station P/E, independent empty ROI, feed/outside rejection, cancel/restart, four candidates per zone, original R27B main608 and trace unchanged",frames,checks);$finish;
 end
 initial begin #200000000;$fatal(1,"dual pixels watchdog");end
endmodule
