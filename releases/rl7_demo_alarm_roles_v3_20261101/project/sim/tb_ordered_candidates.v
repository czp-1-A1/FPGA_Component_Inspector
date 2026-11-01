`timescale 1ns/1ps
module tb_ordered_candidates;
 reg clk=0,rst_n=0,fs=0,sof=0,accept=0,cancel=0;
 always #5 clk=~clk;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 reg held_valid=1;reg [10:0] held_x=772;reg [9:0] held_y=320;
 wire ready,old_ready;wire [303:0] original,old_original;wire [607:0] extended;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1)) dut(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),.pixel_x(x),.pixel_y(y),.rgb(rgb),
 .ready(ready),.region_objects(original),.recorder_objects(extended),.recorder_hold_valid(held_valid),.recorder_hold_x(held_x),.recorder_hold_y(held_y));
 frame_shape_search_R7 #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1)) golden(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),.pixel_x(x),.pixel_y(y),.rgb(rgb),
 .ready(old_ready),.region_objects(old_original));
 integer pattern=0,px,py,l,v,cycles,checks=0,p,region_no,row,empties,kept_main,valid_count;
 reg [75:0] a,b;integer cx,cy;
 function integer circle(input integer xx,yy,n);
  begin circle=xx>=0 && xx<n && yy>=0 && yy<n;
   if(n==5 && (xx==0 || xx==4) && (yy==0 || yy==4))circle=0;
   if(n==7 && (((xx==0 || xx==6) && (yy<2 || yy>=5)) || ((xx==1 || xx==5) && (yy==0 || yy==6))))circle=0;
  end
 endfunction
 function integer image(input integer xx,yy);
  integer r,j,rr,dx,dy,ux,uy;
  begin image=30;
   for(r=0;r<(pattern==2 ? 2 : 1);r++)begin
    rr=r==0 ? 320 : 516;
    for(j=0;j<7;j++)begin
     dx=xx-(508+j*44);dy=yy-rr;
     if(j<6)begin
      if(dx>=-18 && dx<18 && dy>=-22 && dy<22)begin
       ux=(dx+18)/2;uy=(dy+22)/2;
       if(!((ux<2 || ux>=16) && (uy<4 || uy>=18)))image=180;
      end
     end else if(pattern!=1)begin
      ux=(dx+4)/2;uy=(dy+4)/2;
      if(dx>=-4 && dy>=-4 && dx<6 && dy<6 && circle(ux,uy,5))image=110;
     end
     dy=yy-(rr-40);ux=(dx+7)/2;uy=(dy+7)/2;
     if(dx>=-7 && dy>=-7 && dx<7 && dy<7 && circle(ux,uy,7))begin image=90;if(ux>=2 && ux<5 && uy>=2 && uy<5)image=110;end
    end
    if(pattern==3 && xx>=748 && xx<764 && yy>=rr-8 && yy<rr+8)image=150;
   end
  end
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task check(input good,input [639:0] message);
  begin checks++;if(!good)begin $display("FAIL candidates pattern%0d %s objects%076h extended%0152h",pattern,message,original,extended);$fatal(1);end end
 endtask
 task run_frame(input integer pat);
  begin
   pattern=pat;held_y=pat==2 ? 516 : 320;fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px+=4)begin
     x=px;y=py;accept=1;sof=px==0 && py==0;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   cycles=0;while((!ready || !old_ready) && cycles<600000)begin ticks(1);cycles++;end
   check(ready && old_ready,"actual shared detector completes within source-frame budget");
   check(original===old_original,"original best2 UI records byte-identical to immutableR7");
   check(extended[151:0]===original[151:0] && extended[455:304]===original[303:152],"original2 display slots keep corresponding IDs");
   empties=0;kept_main=0;valid_count=0;
   for(integer i=0;i<8;i++)begin
    a=extended[i*76+:76];
    if(a[75] && a[74:73]>=2)begin
     valid_count++;cx=(a[41:31]+a[30:20])/2;cy=(a[19:10]+a[9:0])/2;
     if(a[74:73]==3)begin empties++;check(cy>310 && (cy<330 || (cy>506 && cy<526)),"locating row cannot become empty from priority");end
     if(a[74:73]==3 && cx>768 && cx<778 && cy>held_y-8 && cy<held_y+8)kept_main++;
     for(integer j=i+1;j<8;j++)begin b=extended[j*76+:76];if(b[75] && b[74:73]>=2)check(a[41:0]!=b[41:0],"priority copy never duplicates a physical hole");end
    end
   end
   check(valid_count>=3,"neighbour anchors retained with main observation");
   if(pat==0 || pat==2)check(kept_main==1,"held real empty retained beyond nearest4");
   else check(kept_main==0 && empties==0,"absent or dark-reference-invalid main cannot generate empty");
   $display("CANDIDATE_FRAME pattern%0d original=%076h extended=%0152h checks%0d cycles%0d",pat,original,extended,checks,cycles);
   cancel=1;ticks(1);cancel=0;ticks(2);check(extended===0 && !ready,"bad/source invalidation clears held candidate output");
  end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(5);
  for(p=0;p<4;p++)run_frame(p);
  $display("PASS ordered candidates: checks=%0d, actualPPC4 pixels, immutableR7 original2, main outside nearest4, duplicate/feed/dark/absent protection",checks);$finish;
 end
 initial begin #180000000;$fatal(1,"candidate watchdog");end
endmodule
