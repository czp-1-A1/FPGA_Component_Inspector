`timescale 1ns/1ps
// Held-out true-hole and counterexample pixels. No forced classifier labels.
module tb_dual_guard;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,fs=0,sof=0,accept=0,cancel=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire ready;wire [607:0] objects;
frame_shape_search #(.WIDTH(256),.HEIGHT(240),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.recorder_objects(objects),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
integer pattern=0,phase_x=0,phase_y=0,n,px,py,l,v,cycles,e,p,checks=0;
function integer rounded(input integer xx,yy,size);
 begin rounded=xx>=0 && xx<size && yy>=0 && yy<size && !((xx<2 || xx>=size-2) && (yy<2 || yy>=size-2));end
endfunction
function integer image(input integer xx,yy);
integer a,b;begin
 image=pattern==3?90:30;a=xx-phase_x;b=yy-phase_y;
 if(xx>=146 && xx<182 && yy>=90 && yy<134)image=180;
 case(pattern)
  0:if(rounded(a-108,b-108,10))image=110;
  1:begin
   if(rounded(a-104,b-104,16))image=90;
   if(rounded(a-108,b-108,8))image=150;
  end
  2:if(rounded(a-106,b-82,12))image=110;
  3:if(rounded(a-108,b-108,10))image=110;
  4:begin
   if(a>=106 && a<118 && b>=106 && b<118)image=90;
   if(rounded(a-108,b-108,8))image=150;
  end
  5:if(a>=108 && a<118 && b>=108 && b<118)image=110;
  6:if(a>=104 && a<120 && b>=108 && b<116)image=150;
  7:begin
   if(rounded(a-108,b-108,10))image=110;
   if(xx>=88 && xx<104 && yy>=105 && yy<121)image=180;
  end
  8:if(rounded(a-108,b-134,10))image=110;
  9:if(rounded(a-158,b-108,10))image=230;
  10:image=image;
 endcase
end endfunction
task ticks(input integer count);repeat(count)@(negedge clk);endtask
task frame;
begin
 fs=1;ticks(1);fs=0;ticks(3);
 if(dut.high_valid!==0)$fatal(1,"cache survived native start");
 for(py=0;py<240;py++)begin
  for(px=0;px<256;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;
  end
  ticks(2);
 end
 ticks(5);cycles=0;while(!ready && cycles<250000)begin ticks(1);cycles++;end
 if(!ready)$fatal(1,"frame deadline");e=0;p=0;
 for(integer j=0;j<8;j++)if(objects[j*76+75])begin
  if(objects[j*76+73+:2]==3)e++;
  if(objects[j*76+73+:2]==2)p++;
 end
 if(p!=1 || e!=(pattern==0?1:0))$fatal(1,"held-out pixel truth pattern%0d phase%0d,%0d P%0d E%0d",pattern,phase_x,phase_y,p,e);
 checks++;
 $display("GUARD case%0d phase%0d,%0d P%0d E%0d",pattern,phase_x,phase_y,p,e);
 cancel=1;ticks(1);cancel=0;ticks(3);
 if(ready || objects!==0 || dut.high_valid!==0)$fatal(1,"cancel retained evidence/outputs");
end endtask
initial begin
 ticks(5);rst_n=1;ticks(3);
 for(pattern=0;pattern<=10;pattern++)for(n=0;n<4;n++)begin phase_x=n%2;phase_y=n/2;frame();end
 pattern=0;phase_x=1;phase_y=1;frame();
 $display("PASS dual guard: %0d actual PPC4 frames, four phases, normal/on-row feed with bright core, eroded offrow feed, uniformT80 background, mismatched-box bright core, solid/elongated fragments, localdark, wrong row, body interior, source/cancel/new-frame proof",checks);$finish;
end
initial begin #250000000;$fatal(1,"guard watchdog");end
endmodule
