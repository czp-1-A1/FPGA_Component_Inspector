`timescale 1ns/1ps
module tb_shape_model;
reg clk=0,rst=0,fs=0,accept=0,sof=0,commit=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire valid;wire [1:0] state;wire [12:0] fg;wire [6:0] w,h;
always #5 clk=~clk;
// Deliberately non-PPC-aligned bounds verify all four lane masks.
roi_shape_model #(.X0(473),.X1(553)) dut(clk,rst,fs,accept,sof,x,y,rgb,commit,cancel,valid,state,fg,w,h);
integer xx,yy,l,c,ref_fg,ref_x0,ref_x1,ref_y0,ref_y1,tests=0,px,py;
function integer brightness(input integer pattern,px,py);
 integer dx,dy;begin
 dx=px-40;dy=py-40;brightness=30;
 case(pattern)
  0:if(px>=6 && px<74 && py>=13 && py<67) brightness=180;
  1:if(dx*dx+dy*dy<=100) brightness=150;
  2:if(dx*dx+dy*dy<=256) brightness=150;
  3:brightness=240;
  4:if(px<68 && py>=13 && py<67) brightness=180;
  5:brightness=30;
  6:if(dx*dx+dy*dy<=169) brightness=150;
  7:if(px>=6 && px<74 && py>=13 && py<67) brightness=100;
  8:if(px>=6 && px<74 && py>=13 && py<67) brightness=99;
 endcase
 end
endfunction
task tick(input integer n);begin repeat(n) @(negedge clk);end endtask
task frame(input integer pattern,fault,expected);
 begin
 fs=1;tick(1);fs=0;tick(4);sof=1;accept=1;x=0;y=0;rgb=0;tick(1);sof=0;accept=0;
 ref_fg=0;ref_x0=999;ref_y0=999;ref_x1=-1;ref_y1=-1;
 for(yy=260;yy<340;yy=yy+1) for(xx=472;xx<556;xx=xx+4) begin
  x=xx;y=yy;accept=!(fault==1 && xx==500 && yy==300);
  for(l=0;l<4;l=l+1) begin
   px=xx+l-473;py=yy-260;c=brightness(pattern,px,py);rgb[95-l*24-:24]={3{8'(c)}};
   if(px>=0 && px<80 && c>=100) begin
    ref_fg++;if(px<ref_x0)ref_x0=px;if(px>ref_x1)ref_x1=px;if(py<ref_y0)ref_y0=py;if(py>ref_y1)ref_y1=py;
   end
  end
  if(fault==2 && yy==300 && xx==500) begin cancel=1;tick(1);cancel=0;end
  tick(1);accept=0;tick((xx%12)==0 ? 2 : 1);
 end
 if(fault==3)begin accept=1;x=500;y=300;tick(1);accept=0;end
 tick(5);commit=1;tick(1);commit=0;
 if(fault==4)begin tick(2);cancel=1;tick(1);cancel=0;end
 tick(12);
 if(fault!=0) begin if(valid)$fatal(1,"invalid frame published fault=%0d",fault);end
 else begin
  if(!valid || state!==expected || fg!=ref_fg || w!=(ref_fg==0?0:ref_x1-ref_x0+1) || h!=(ref_fg==0?0:ref_y1-ref_y0+1))
   $fatal(1,"shape pattern=%0d state=%d/%d valid=%b fg=%d/%d box=%d,%d",pattern,state,expected,valid,fg,ref_fg,w,h);
 end
 tests++;$display("shape pattern=%0d fault=%0d state=%0d FG=%0d W=%0d H=%0d",pattern,fault,state,fg,w,h);
 end
endtask
initial begin
 tick(5);rst=1;tick(5);
 frame(0,0,2);frame(1,0,3);frame(2,0,0);frame(3,0,0);frame(4,0,0);frame(5,0,1);frame(6,0,1);frame(7,0,2);frame(8,0,1);
 frame(0,1,1);frame(0,2,1);frame(0,3,1);frame(0,4,1);frame(0,0,2);
 fs=1;tick(1);fs=0;tick(4);if(valid || state!=1)$fatal(1,"new FS retained result");
 rst=0;tick(1);if(valid || fg!=0)$fatal(1,"reset retained result");
 $display("PASS shape model: %0d cases, independent foreground/bbox counts, PPC4 unaligned, bubbles, four classes, borders, threshold, missing/duplicate/cancel, recovery",tests);$finish;
end
initial begin #5000000;$fatal(1,"shape watchdog");end
endmodule
