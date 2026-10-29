`timescale 1ns/1ps
module tb_dual_pixels;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,sof=0,accept=0,cancel=0;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sample;wire [607:0] records;wire [303:0] display_objects;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),
  .ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),
  .COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(
  .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sample),.recorder_objects(records),.region_objects(display_objects),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .repair_hold_valid(1'b0),.repair_hold_x(11'd0),.repair_hold_y(10'd0),.repair_hold_radius(6'd12),.repair_empty_only(1'b0),.repair_hold_id(9'd0));
 integer pattern=0,checks=0,frames=0,px,py,l,n,v,waited;
 reg [75:0] rec;integer lane,slot,cx,cy,expected,found;
 function integer ellipse(input integer xx,yy,cx,cy,w,h);
  integer dx,dy;begin dx=2*(xx-(cx-w/2))+1-w;dy=2*(yy-(cy-h/2))+1-h;ellipse=dx*dx*h*h+dy*dy*w*w<=w*w*h*h;end
 endfunction
 function integer wanted(input integer row,index);
  begin wanted=(row==0 ? index==2 : index==1) ? 3 : 2;
   if(pattern==1)wanted=row==0 && (index==1 || index==2) ? 3 : 2;
   if(pattern==2 && row==1 || pattern==3 && row==0 || pattern==4)wanted=0;
  end
 endfunction
 function integer image(input integer xx,yy);
  integer row,k,xxc,yyc,dx,dy,kind;
  begin image=30;
   for(row=0;row<2;row++)for(k=0;k<4;k++)begin
    xxc=520+k*80;yyc=row==0 ? 320 : 520;dx=xx-xxc;dy=yy-yyc;kind=wanted(row,k);
    if(kind==3 && ellipse(xx,yy,xxc,yyc,14,12))image=180;
    if(kind==2 && dx>=-18 && dx<18 && dy>=-22 && dy<22 && !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))image=180;
    if(ellipse(xx,yy,xxc,yyc+40,16,14))image=180;
   end
   // Valid-looking bodies OUTSIDE both ROIs may not consume lane slots.
   if(xx>=180 && xx<216 && yy>=298 && yy<342 || xx>=1000 && xx<1036 && yy>=498 && yy<542)image=180;
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
   waited=0;while(!sample && waited<1500000)begin ticks(1);waited++;end
   if(!sample || !ready)$fatal(1,"dual analysis timeout");ticks(2);
   for(lane=0;lane<2;lane++)begin
    found=0;
    for(slot=0;slot<4;slot++)begin
     rec=records[(lane*4+slot)*76+:76];
     if(rec[75])begin found++;checks++;cx=(rec[41:31]+rec[30:20])/2;cy=(rec[19:10]+rec[9:0])/2;
      if(cx<400 || cx>=880 || (lane==0 ? cy<240 || cy>=400 : cy<432 || cy>=600))$fatal(1,"ROI source membership mismatch");
      n=(cx-520+40)/80;
      if(n<0 || n>3 || cx<520+n*80-2 || cx>520+n*80+2)$fatal(1,"not a physical in-ROI object");
      if(rec[74:73]!=wanted(lane,n))$fatal(1,"scene%0d lane%0d object%0d wrong P/E class got%0d want%0d",p,lane,n,rec[74:73],wanted(lane,n));
     end
    end
    expected=(p==2 && lane==1 || p==3 && lane==0 || p==4) ? 0 : 4;
    if(found!=expected)$fatal(1,"scene%0d lane%0d retained%0d want%0d",p,lane,found,expected);
   end
   if(display_objects!=={records[455:304],records[151:0]})$fatal(1,"display pair mapped to wrong lane");
   frames++;
  end
 endtask
 initial begin
  ticks(5);rst=1;ticks(3);frame(0);frame(1);frame(2);frame(3);frame(4);
  cancel=1;ticks(3);cancel=0;ticks(2);if(ready || sample || records!=0)$fatal(1,"canceled result remained valid");frame(0);
  $display("PASS DUAL PIXELS: %0d full RGB frames, %0d real object checks, both upper/lower P/E, independent empty ROI, feed/outside rejection, cancel/restart, four candidates and two visible per ROI",frames,checks);$finish;
 end
 initial begin #200000000;$fatal(1,"dual pixels watchdog");end
endmodule
