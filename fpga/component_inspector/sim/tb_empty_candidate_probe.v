`timescale 1ns/1ps
// Actual pixels, paired detectors: enabling diagnostics must preserve all
// classification records and ready/sample timing, including rejected holes.
module tb_empty_candidate_probe;
 reg clk=0,rst_n=0,fs=0,sof=0,accept=0,cancel=0;
 always #5 clk=~clk;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sn,base_ready,base_sn;wire [303:0] objects,base_objects;wire [31:0] probe;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),.EMPTY_DIAGNOSTICS(1)) dut(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sn),.region_objects(objects),.empty_probe(probe));
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1)) baseline(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(base_ready),.sample_new(base_sn),.region_objects(base_objects));
 integer pattern=0,px,py,l,v,cycles,checks=0;
 function integer circle(input integer a,b,n);
  begin circle=a>=0 && b>=0 && a<n && b<n;
   if(n==5 && (a==0 || a==4) && (b==0 || b==4))circle=0;
   if(n==6 && (a==0 || a==5) && (b<2 || b>=4))circle=0;
   if(n==7 && (((a==0 || a==6) && (b<2 || b>=5)) || ((a==1 || a==5) && (b==0 || b==6))))circle=0;
  end
 endfunction
 function integer image(input integer xx,yy);
  integer n,dy,ax,ay;begin
   image=30;n=(pattern==2 || pattern==3 || pattern==5) ? 6 : pattern==6 ? 7 : 5;
   dy=pattern==2 ? 20 : 0;
   ax=xx-(640-(n & ~1));ay=yy-(320+dy-(n & ~1));
   if(pattern!=7 && ax>=0 && ay>=0 && ax<n*2 && ay<n*2 &&
      (pattern==3 || circle(ax/2,ay/2,n)))image=pattern==1 ? 110 : 90;
   if(pattern==4 && xx>=616 && xx<632 && yy>=312 && yy<328)image=150;
  end
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 always @(negedge clk)if(rst_n && (sn!==base_sn || ready!==base_ready || (sn && objects!==base_objects)))
  $fatal(1,"passive diagnostic changed classification or timing");
 always @(posedge clk)if(dut.empty_diagnostics.probe.ref_complete)
  $display("REF p%0d empty%0d xy%0d,%0d wh%0d,%0d best%0d,%0d %0d,%0d valid%0d ok%0d",pattern,dut.empty_diagnostics.probe.ref_empty,dut.empty_diagnostics.probe.ref_x,dut.empty_diagnostics.probe.ref_y,dut.empty_diagnostics.probe.ref_width,dut.empty_diagnostics.probe.ref_height,dut.empty_diagnostics.probe.best_x,dut.empty_diagnostics.probe.best_y,dut.empty_diagnostics.probe.best_width,dut.empty_diagnostics.probe.best_height,dut.empty_diagnostics.probe.best[31],dut.empty_diagnostics.probe.ref_ok);
 task frame(input integer p);
  integer empties,want;begin
   pattern=p;fs=1;ticks(1);fs=0;ticks(3);
   if(probe!==0)$fatal(1,"stale diagnostic at next source start");
   for(py=0;py<720;py=py+1)begin
    for(px=0;px<1280;px=px+4)begin
     x=px;y=py;accept=1;sof=px==0 && py==0;
     for(l=0;l<4;l=l+1)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end ticks(2);
   end
   ticks(5);cycles=0;while(!ready && cycles<400000)begin ticks(1);cycles=cycles+1;end
   if(!ready)$fatal(1,"probe source deadline");
   empties=0;for(integer k=0;k<4;k=k+1)if(objects[k*76+75] && objects[k*76+73+:2]==3)empties++;
   want=(p==0 || p==5) ? 1 : 0;
   if(empties!=want)$fatal(1,"physical fixture class p%0d empty%0d want%0d",p,empties,want);
   if(p==7)begin if(probe!==0)$fatal(1,"background diagnostic valid");end
   else begin
    if(!probe[31] || probe[30])$fatal(1,"probe valid/region p%0d",p);
    case(p)
     0,5:if(!probe[16] || !probe[15] || !probe[14] || probe[19:17]!=0 || !probe[11] || !probe[10] || !probe[9] || !probe[8] || !probe[7])$fatal(1,"good hole passive evidence p%0d word%08h",p,probe);
     1:if(probe[19:17]!=6 || !probe[16] || !probe[15] || probe[11] || probe[7])$fatal(1,"bright rejection evidence %08h",probe);
     2:if(probe[16] || probe[14] || probe[11] || probe[7] || probe[29:25]!=6 || probe[24:20]!=6)$fatal(1,"six-cell row rejection evidence %08h",probe);
     3:if(probe[15] || probe[11] || probe[7])$fatal(1,"shape rejection evidence %08h",probe);
     4:if(!probe[11] || !probe[10] || !probe[9] || probe[8] || probe[7])$fatal(1,"dark side rejection evidence %08h",probe);
     6:if(!probe[13] || probe[11] || probe[7])$fatal(1,"feed exclusion evidence %08h",probe);
    endcase
   end
   $display("OBS EMPTY PROBE pattern%0d word%08h empty%0d cycles%0d",p,probe,empties,cycles);checks++;
   cancel=1;ticks(1);cancel=0;ticks(2);if(probe!==0 || ready)$fatal(1,"canceled probe stayed valid");
  end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(5);
  for(integer p=0;p<8;p++)frame(p);
  $display("PASS EMPTY CANDIDATE PROBE: %0d pixel fixtures good5/good6/bright/row/shape/dark/feed/background,classes and timing identical,source/cancel clearing",checks);$finish;
 end
 initial begin #150000000;$fatal(1,"probe watchdog");end
endmodule
