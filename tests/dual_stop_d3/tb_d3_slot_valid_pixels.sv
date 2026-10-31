`timescale 1ns/1ps
module tb_d3_slot_valid_pixels;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,sof=0,accept=0,cancel=0;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sample,reference_ready,reference_sample;wire [607:0] records,station_records,reference_records;wire [303:0] display_objects;wire [127:0] probe,reference_probe;wire [1:0] occupied;
 wire [607:0] reference_station;wire [303:0] reference_display;wire [1:0] reference_occupied;reg hold=0;
 frame_shape_search #(.DUAL_STOP(1),.DUAL_REGION_COUNT(1),.SPARSE_ROW_SCAN(1),.PRESENT_TRACE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(hold),.recorder_hold_x(11'd440),.recorder_hold_y(10'd320),.recorder_hold_valid2(hold),.recorder_hold_x2(11'd440),.recorder_hold_y2(10'd516),.station_hold_valid({2{hold}}),.station_hold_empty_only(2'b11),.station_hold_x({11'd88,11'd88}),.station_hold_y({10'd516,10'd320}),.station_hold_radius({6'd12,6'd12}),.ready(ready),.sample_new(sample),.station_objects(station_records),.transport_occupied(occupied),.probe_record(probe),.recorder_objects(records),.region_objects(display_objects)); r50_reference_frame_shape_search #(.DUAL_STOP(1),.DUAL_REGION_COUNT(1),.SPARSE_ROW_SCAN(1),.PRESENT_TRACE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) baseline(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(hold),.recorder_hold_x(11'd440),.recorder_hold_y(10'd320),.recorder_hold_valid2(hold),.recorder_hold_x2(11'd440),.recorder_hold_y2(10'd516),.station_hold_valid({2{hold}}),.station_hold_empty_only(2'b11),.station_hold_x({11'd88,11'd88}),.station_hold_y({10'd516,10'd320}),.station_hold_radius({6'd12,6'd12}),.ready(reference_ready),.sample_new(reference_sample),.station_objects(reference_station),.transport_occupied(reference_occupied),.probe_record(reference_probe),.recorder_objects(reference_records),.region_objects(reference_display));
 integer pattern=0,checks=0,frames=0,px,py,l,n,v,waited;
 integer compared_clocks=0;
 // Compare every public candidate/control/diagnostic bit on every pixel clock,
 // including analysis cycles, held targets, cancellation and frame boundaries.
 always @(negedge clk)if(rst)begin
  #1;
  if({ready,sample,records,station_records,display_objects,probe,occupied,
      dut.located,dut.state,dut.foreground_count,dut.box_width,dut.box_height,
      dut.box_x0,dut.box_x1,dut.box_y0,dut.box_y1,dut.review_required,dut.objects,dut.empty_probe,dut.probe_ready,dut.phase} !==
     {reference_ready,reference_sample,reference_records,reference_station,reference_display,reference_probe,reference_occupied,
      baseline.located,baseline.state,baseline.foreground_count,baseline.box_width,baseline.box_height,
      baseline.box_x0,baseline.box_x1,baseline.box_y0,baseline.box_y1,baseline.review_required,baseline.objects,baseline.empty_probe,baseline.probe_ready,baseline.phase})
   $fatal(1,"R50 FSS cycle equivalence changed clock%0d frame%0d phase%0d",compared_clocks,frames,dut.phase);
  compared_clocks++;
 end

 reg [75:0] rec;integer lane,slot,cx,cy,expected,found;
 function integer ellipse(input integer xx,yy,cx,cy,w,h);
  integer dx,dy;begin dx=2*(xx-(cx-w/2))+1-w;dy=2*(yy-(cy-h/2))+1-h;ellipse=dx*dx*h*h+dy*dy*w*w<=w*w*h*h;end
 endfunction
 function integer image(input integer xx,yy);
  integer zone,k,xxc,yyc,dx,dy,kind,extent;
  begin image=30;
   for(zone=0;zone<4;zone++)for(k=0;k<8;k++)begin
    xxc=zone>=2 ? 88+k*44 : 440+k*60;yyc=zone%2 ? 516 : 320;
    dx=xx-xxc;dy=yy-yyc;kind=pattern==0 ? 2 : pattern==1 || pattern==3 || pattern==4 ? 3 : k%3==0 ? 3 : 2;
    if(pattern==4 && k==0)kind=0;
    if(pattern==5 || pattern==6)kind=1;
    if(pattern==7)kind=0;
    if(kind==3 && ellipse(xx,yy,xxc,yyc,14,12))image=180;
    if(kind==2 && dx>=-18 && dx<18 && dy>=-22 && dy<22 && !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))image=180;
    if(kind==1 && dx>=-9 && dx<9 && dy>=-(9+k%2) && dy<9+k%2)image=180;
    if(ellipse(xx,yy,xxc,yyc+40,16,14))image=180;
   end
   if(pattern==6)begin
    image=30;
    for(zone=0;zone<4;zone++)for(k=0;k<4;k++)begin
     xxc=zone>=2 ? 88+k*96 : 460+k*120;yyc=zone%2 ? 516 : 320;dx=xx-xxc;dy=yy-yyc;extent=k%2 ? 57 : 55;
     // Half-scale areas exceed 2047; full ranking counts must not truncate.
     if(dx>=-41 && dx<41 && dy>=-extent && dy<extent)image=180;
    end
   end
  end
 endfunction
 task ticks(input integer k);repeat(k)@(negedge clk);endtask
 task frame(input integer p);
  begin pattern=p;hold=p==3 || p==4;fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px+=4)begin x=px;y=py;sof=px==0 && py==0;accept=1;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   waited=0;while(!(ready && reference_ready) && waited<1500000)begin ticks(1);waited++;end
   if(!reference_ready || !ready)$fatal(1,"rank analysis timeout");ticks(2);
   if(records!==reference_records || station_records!==reference_station || display_objects!==reference_display || probe!==reference_probe || occupied!==reference_occupied)
    $fatal(1,"rank semantics changed scene%0d main%h ref%h station%h refstation%h probe%h refprobe%h",p,records,reference_records,station_records,reference_station,probe,reference_probe);
   for(lane=0;lane<4;lane++)for(slot=0;slot<4;slot++)begin
    rec=lane>=2 ? station_records[((lane-2)*4+slot)*76+:76] : records[(lane*4+slot)*76+:76];
    if(rec[75])checks++;
   end
   frames++;
  end
 endtask
 initial begin
  ticks(5);rst=1;ticks(3);
  for(integer p=0;p<8;p++)frame(p);
  cancel=1;ticks(3);cancel=0;ticks(2);frame(2);
  if(checks<64)$fatal(1,"rank scenes retained too few candidates");
  $display("PASS slot-valid private result buffer every-clock equivalence vs exact R50: %0d full RGB frames %0d retained records, >4 candidate replacement/ties, held far-slot EMPTY, missing-held target, full18-bit large unknown count, FG saturation, empty/cancel/restart; all1216 candidate bits +304 UI +128 diagnostic +occupied exact",frames,checks);$finish;
 end
 initial begin #400000000;$fatal(1,"rank pixels watchdog");end
endmodule
