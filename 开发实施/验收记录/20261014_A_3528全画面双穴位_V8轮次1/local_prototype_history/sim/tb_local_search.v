`timescale 1ns/1ps
module tb_local_search;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready,fresh,located,review;wire [1:0] state;wire [12:0] fg;wire [6:0] w,h;wire [10:0] x0,x1;wire [9:0] y0,y1;
roi_shape_search dut(clk,rst,fs,sof,accept,cancel,x,y,rgb,ready,fresh,located,state,fg,w,h,x0,x1,y0,y1,review,);
reg force_cancel=0;integer tests=0,shift_x,shift_y,pattern,ref_fg,cycles,i,j,l,v;
function integer image(input integer px,py);
 integer dx,dy;begin
 dx=px-512-shift_x;dy=py-300-shift_y;image=30;
 case(pattern)
  0,6:if(px>=481+shift_x && px<544+shift_x && py>=263+shift_y && py<338+shift_y)image=180;
  1:if(dx*dx+dy*dy<=81)image=150;
  2:if(dx*dx+dy*dy<=256)image=150;
  3:image=240;
  4:image=30;
  5:if(dx>=-10 && dx<10 && dy>=-10 && dy<10)image=150;
 endcase
 if(pattern==6)begin
  if(py<235 || py>=367)image=220; // border-connected background strips
  if((px-512-shift_x)*(px-512-shift_x)+(py-234-shift_y)*(py-234-shift_y)<=256)image=150;
  if(py>=263+shift_y && py<338+shift_y && ((px>=577+shift_x && px<640+shift_x) || (px>=385+shift_x && px<448+shift_x)))image=180;
 end
 end
endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer p,dx,dy,expected,expect_location);
 begin
 pattern=p;shift_x=dx;shift_y=dy;fs=1;ticks(1);fs=0;ticks(3);sof=1;accept=1;x=0;y=0;rgb=0;ticks(1);sof=0;accept=0;ticks(3);
 ref_fg=0;
 for(j=228;j<372;j++)for(i=416;i<608;i+=4)begin
  x=i;y=j;accept=1;
  for(l=0;l<4;l++)begin v=image(i+l,j);rgb[95-l*24-:24]={3{8'(v)}};
   // Independent truth mask for the central component only.
   if((p==0 || p==6) && i+l>=481+dx && i+l<544+dx && j>=263+dy && j<338+dy)ref_fg++;
   if((p==1 || p==2) && (i+l-512-dx)*(i+l-512-dx)+(j-300-dy)*(j-300-dy)<=(p==1?81:256))ref_fg++;
  end
  ticks(1);accept=0;ticks((i%16)==0?2:1);
 end
 if(force_cancel)begin ticks(5000);cancel=1;ticks(1);cancel=0;ticks(8);if(ready || located || state!=1)$fatal(1,"processing cancellation retained a model");tests++;end
 else begin
 cycles=0;while(!ready && cycles<900000)begin ticks(1);cycles++;end
 if(!ready || state!==expected || located!==expect_location)$fatal(1,"search p=%0d move=%0d,%0d got=%0d/%0d located=%b/%b phase=%d",p,dx,dy,state,expected,located,expect_location,dut.phase);
 if((p==0 || p==6) && expect_location)begin
  if(fg!=ref_fg || w!=63 || h!=75 || x0!=479+dx || x1!=546+dx || y0!=261+dy || y1!=340+dy)
   $fatal(1,"independent complete rectangle mismatch FG%0d/%0d W/H%0d/%0d box%0d..%0d,%0d..%0d",fg,ref_fg,w,h,x0,x1,y0,y1,review,);
 end
 if(p==1 || p==2)begin
  if(fg!=ref_fg || w!=(p==1?19:33) || h!=(p==1?19:33))$fatal(1,"circle truth mismatch");
 end
 tests++;$display("OBS local search case=%0d p=%0d move=%0d,%0d state=%0d FG=%0d W/H=%0d/%0d postcapture_cycles=%0d",tests,p,dx,dy,state,fg,w,h,cycles);
 end
 end
endtask
initial begin
 ticks(5);rst=1;ticks(5);
 frame(0,0,0,2,1);frame(0,20,12,2,1);frame(0,-20,-12,2,1);frame(0,32,24,2,1);
 frame(0,64,0,0,0);frame(6,12,6,2,1);frame(1,20,12,3,1);frame(2,0,0,0,1);frame(3,0,0,0,0);frame(4,0,0,1,0);frame(5,0,0,1,1);
 // Capture and processing canceled before completion must not publish a stale box.
 fs=1;ticks(1);fs=0;cancel=1;ticks(1);cancel=0;ticks(10);if(ready || located)$fatal(1,"canceled box retained");
 force_cancel=1;frame(0,20,12,1,0);force_cancel=0;frame(0,0,0,2,1);
 $display("PASS local search: %0d independent shape/position cases, outside old 80 core, neighbors/feed/background separated, unchanged strict model, PPC4 bubbles, cancel/recovery",tests);$finish;
end
initial begin #150000000;$fatal(1,"local search watchdog");end
endmodule
