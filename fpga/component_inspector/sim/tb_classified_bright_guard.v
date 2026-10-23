`timescale 1ns/1ps
// Held-out true-hole/negative RGB fixtures for the observed field rejection.
// Legacy comparator remains unchanged and runs beside the opt-in candidate.
module tb_classified_bright_guard;
 reg clk=0,rst_n=0,fs=0,sof=0,accept=0,cancel=0;
 always #5 clk=~clk;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,legacy_ready;wire [303:0] objects,legacy_objects;wire [31:0] probe,legacy_probe;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),.EMPTY_DIAGNOSTICS(1),.ROW_GUARDED_BRIGHT_EMPTY(1)) dut(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.region_objects(objects),.empty_probe(probe));
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),.EMPTY_DIAGNOSTICS(1)) legacy(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(legacy_ready),.region_objects(legacy_objects),.empty_probe(legacy_probe));
 integer pattern=0,px,py,l,v,cycles,checks=0;
 function integer circle(input integer a,b,n);
  begin circle=a>=0 && b>=0 && a<n && b<n;
   if(n==5 && (a==0 || a==4) && (b==0 || b==4))circle=0;
   if(n==6 && (a==0 || a==5) && (b<2 || b>=4))circle=0;
   if(n==7 && (((a==0 || a==6) && (b<2 || b>=5)) || ((a==1 || a==5) && (b==0 || b==6))))circle=0;
  end
 endfunction
 function integer image(input integer xx,yy);
  integer n,shift,row,ax,ay,body,feed,fy,bx,by;begin
   image=30;n=(pattern==0 || pattern==4 || pattern==5) ? 5 : pattern==6 ? 7 : 6;
   row=pattern==10 ? 516 : 320;
   shift=(pattern==1 || pattern==2 || pattern==7 || pattern==8 || pattern==10) ? 24 : pattern==4 ? 32 : 0;
   body=pattern==1 || pattern==2 || pattern==7 || pattern==10;
   feed=pattern==1 || pattern==2 || pattern==3 || pattern==7 || pattern==10;
   // Real rounded body, independently taught dimensions18x22 half cells.
   bx=xx-702;by=yy-(row+shift-22);
   if(body && bx>=0 && bx<36 && by>=0 && by<44 &&
      !((bx/2<2 || bx/2>=16) && (by/2<4 || by/2>=18)))image=180;
   ax=xx-(640-(n & ~1));ay=yy-(row+shift-(n & ~1));
   if(pattern!=7 && pattern!=9 && circle(ax/2,ay/2,n) && ax>=0 && ay>=0 && ax<n*2 && ay<n*2)image=110;
   // Phase-eroded locating6 above or below; normal locating7 is pattern6.
   fy=row+shift+(pattern==2 ? 40 : pattern==7 ? -38 : -40);
   ax=xx-660;ay=yy-(fy-6);
   if(feed && circle(ax/2,ay/2,6) && ax>=0 && ay>=0 && ax<12 && ay<12)image=90;
   // A nearby white fragment deliberately contaminates the local dark strip.
   if(pattern==5 && xx>=616 && xx<632 && yy>=row-8 && yy<row+8)image=150;
  end
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task frame(input integer p);
  integer empties,old_empty,want;begin
   pattern=p;fs=1;ticks(1);fs=0;ticks(3);
   if(probe!==0 || dut.row_anchor_valid!==0)$fatal(1,"source start reused old probe/row");
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px+=4)begin
     x=px;y=py;accept=1;sof=px==0 && py==0;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end ticks(2);
   end
   cycles=0;while((!ready || !legacy_ready) && cycles<500000)begin ticks(1);cycles++;end
   if(!ready || !legacy_ready)$fatal(1,"fixture deadline");
   empties=0;old_empty=0;
   for(integer k=0;k<4;k++)begin
    if(objects[k*76+75] && objects[k*76+73+:2]==3)begin
     empties++;
     if(objects[k*76+19-:10]+objects[k*76+:10]<(pattern==10 ? 1060 : pattern==1 || pattern==2 ? 668 : 620))$fatal(1,"feed row accepted as pocket");
    end
    if(legacy_objects[k*76+75] && legacy_objects[k*76+73+:2]==3)old_empty++;
   end
   want=(p==0 || p==1 || p==2 || p==3 || p==10) ? 1 : 0;
   if(empties!=want)$fatal(1,"fixture%0d empty%0d want%0d word%08h",p,empties,want,probe);
   if(p==0 && (old_empty!=0 || legacy_probe[19:17]!=6 || !legacy_probe[16] || !legacy_probe[15]))$fatal(1,"field bright5 gate not reproduced");
   if(p==1 && (old_empty!=0 || legacy_probe[16] || legacy_probe[19:17]!=6))$fatal(1,"field bright6/row gates not reproduced independently");
   if(want && (!probe[11] || !probe[9] || !probe[8] || !probe[7]))$fatal(1,"accepted hole lacked raw/dark/final proof");
   if(p==5 && (!probe[11] || !probe[9] || probe[8] || probe[7]))$fatal(1,"dark contamination guard removed");
   if(p==6 && !probe[13])$fatal(1,"normal feed geometry exclusion missing");
   if(p==7 && old_empty!=1)$fatal(1,"eroded feed6 alias counterexample not exercised");
   $display("BRIGHT GUARD fixture%0d oldEmpty%0d newEmpty%0d oldProbe%08h newProbe%08h",p,old_empty,empties,legacy_probe,probe);checks++;
   cancel=1;ticks(1);cancel=0;ticks(2);
   if(probe!==0 || dut.row_anchor_valid!==0 || ready)$fatal(1,"canceled source retained row/probe");
  end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(5);
  for(integer p=0;p<=10;p++)frame(p);
  $display("PASS classified bright guard:11 PPC4 RGB fixtures,field bright5/shift6,all-empty,upper/lower eroded locating6,local dark,normal feed7,stale source cancellation");$finish;
 end
 initial begin #180000000;$fatal(1,"bright guard watchdog");end
endmodule
