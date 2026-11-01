`timescale 1ns/1ps
// Full native processing raster: real segmentation/shape/reference/ranking.
// No forced internal signal, invented records or reduced image dimensions.
module tb_relay_left_pixels;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,sof=0,accept=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sn,occupied;wire [607:0] records;reg hold=0;
 frame_shape_search #(.RELAY_LEFT_LAYOUT(1),.LOCAL_EDGE_ASSIST(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),
  .STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),
  .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(
  .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(1'b0),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sn),.recorder_objects(records),
  .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
  .repair_hold_valid(hold),.repair_hold_x(11'd96),.repair_hold_y(10'd320),.transport_occupied(occupied));
 integer scene=0,px,py,l,v,waited,n,i,xx,yy,cx,checks=0,main_e,left_e,left_n;reg found_head;reg [75:0] ob;
 function integer ellipse(input integer ax,ay,bx,by,w,h);
  integer dx,dy;begin dx=2*(ax-(bx-w/2))+1-w;dy=2*(ay-(by-h/2))+1-h;ellipse=dx*dx*h*h+dy*dy*w*w<=w*w*h*h;end
 endfunction
 function integer body(input integer ax,ay,bx);
  integer dx,dy;begin dx=ax-bx;dy=ay-320;body=dx>=-18 && dx<18 && dy>=-22 && dy<22 && !((dx<-14 || dx>=14)&&(dy<-14 || dy>=14));end
 endfunction
 function integer image(input integer ax,ay);
  integer k,bx;begin
   image=scene==0 ? 150 : 30;
   if(scene==1 || scene==2)begin
    for(k=0;k<6;k++)begin
     bx=96+k*64;
     if(k==0 ? ellipse(ax,ay,bx,320,14,12) : body(ax,ay,bx))image=180;
     if(ellipse(ax,ay,bx,360,16,14))image=180;
    end
    if(body(ax,ay,576) || body(ax,ay,704) || ellipse(ax,ay,640,320,14,12))image=180;
    for(k=0;k<3;k++)if(ellipse(ax,ay,576+k*64,360,16,14))image=180;
   end
   if(scene==3 && body(ax,ay,704))image=180;
   if(scene==4 && body(ax,ay,620))image=180;
  end
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task frame;
  begin
   fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px+=4)begin
     x=px;y=py;sof=px==0 && py==0;accept=1;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   waited=0;while(!ready && waited<600000)begin ticks(1);waited++;end
   if(!ready)$fatal(1,"pixel analysis deadline");
   main_e=0;left_e=0;left_n=0;found_head=0;
   for(i=0;i<8;i++)begin
    ob=records[i*76+:76];if(ob[75] && ob[74:73]>=2)begin
     xx=(integer'(ob[41:31])+integer'(ob[30:20]))/2;
     yy=(integer'(ob[19:10])+integer'(ob[9:0]))/2;
     if(yy<240 || yy>=400)$fatal(1,"wrong row");
     if(i<4)begin if(xx<448 || xx>=832)$fatal(1,"main bank spatial binding");if(ob[74:73]==3)main_e++;end
     else begin
      if(xx<64 || xx>=448)$fatal(1,"left bank spatial binding");
      left_n++;if(ob[74:73]==3)left_e++;if(xx>=94 && xx<=98 && ob[74:73]==3)found_head=1;
     end
    end
   end
   $display("PIX scene%0d hold%0d mainE%0d leftE%0d leftN%0d head%0d occupied%0d cap%0d words%0d phase%0d pending%0d",scene,hold,main_e,left_e,left_n,found_head,occupied,dut.cap_count,dut.WORDS,dut.phase,dut.occupied_pending);
   case(scene)
    0:if(occupied || records!=0)$fatal(1,"clear belt must be clear");
    1:if(!occupied || main_e!=1 || left_n!=4 || found_head)$fatal(1,"unreserved distant head should be pruned, both ROI active");
    2:if(!occupied || main_e!=1 || left_n!=4 || !found_head)$fatal(1,"reserved real left head lost among six candidates");
    3:if(occupied)$fatal(1,"upstream-only material prevents clear alignment");
    4:if(!occupied)$fatal(1,"uncounted downstream material bypassed alignment");
   endcase
   checks++;
  end
 endtask
 initial begin
  ticks(5);rst=1;ticks(5);frame();scene=1;frame();scene=2;hold=1;frame();hold=0;scene=3;frame();scene=4;frame();
  $display("PASS left pixels: %0d full1280x720 rasters; two ROI banks, real E/P proof, six candidates, query retention, pre-ranking transport occupancy",checks);$finish;
 end
 initial begin #100000000;$fatal(1,"pixel watchdog");end
endmodule
