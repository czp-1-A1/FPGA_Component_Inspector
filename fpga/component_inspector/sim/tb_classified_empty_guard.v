`timescale 1ns/1ps
// Actual PPC4 pixels into the shared detector. Geometry and row truth are
// specified independently of its output. No force/label injection.
module tb_classified_empty_guard;
 reg clk=0,rst_n=0,fs=0,sof=0,accept=0,cancel=0;
 always #5 clk=~clk;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire ready,sn;wire [303:0] objects;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1)) dut(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sn),.region_objects(objects));
 integer pattern=0,px,py,l,v,cycles,checks=0;
 function integer round_cell(input integer xx,yy,n);
  begin round_cell=xx>=0 && xx<n && yy>=0 && yy<n;
   if(n==5 && (xx==0 || xx==4) && (yy==0 || yy==4))round_cell=0;
   if(n==6 && (xx==0 || xx==5) && (yy<2 || yy>=4))round_cell=0;
   if(n==7 && (((xx==0 || xx==6) && (yy<2 || yy>=5)) || ((xx==1 || xx==5) && (yy==0 || yy==6))))round_cell=0;
  end
 endfunction
 function integer image(input integer xx,yy);
  integer z,k,base,offset,n,dx,dy,ux,uy;
  begin image=30;
   for(z=0;z<2;z=z+1)begin
    base=z==0 ? 320 : 516;
    offset=pattern==2 ? 12 : pattern==3 ? 20 : pattern==4 ? -20 : pattern==7 ? 20 : 0;
    n=(pattern==6 || pattern==7) ? 5 : 6;
    for(k=0;k<2;k=k+1)begin
     dx=xx-(600+k*80);dy=yy-(base+offset);
     ux=(dx+n)/2;uy=(dy+n)/2;
     if(pattern!=5 && dx>=-n && dy>=-n && round_cell(ux,uy,n))image=pattern==6 ? 110 : 90;
     dy=yy-(base+offset+(pattern==1 ? 40 : -40));ux=(dx+7)/2;uy=(dy+7)/2;
     if(dx>=-7 && dy>=-7 && round_cell(ux,uy,7))begin
      image=90;if(ux>=2 && ux<5 && uy>=2 && uy<5)image=110;
     end
    end
   end
  end
 endfunction
 task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
 task frame(input integer p);
  integer found,want,k,base,cy;reg [75:0] rec;
  begin
   pattern=p;fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py=py+1)begin
    for(px=0;px<1280;px=px+4)begin
     x=px;y=py;accept=1;sof=px==0 && py==0;
     for(l=0;l<4;l=l+1)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   ticks(5);cycles=0;while(!ready && cycles<400000)begin ticks(1);cycles=cycles+1;end
   if(!ready)$fatal(1,"guarded empty timeout pattern%0d",p);
   found=0;want=(p==0 || p==1 || p==2 || p==7) ? 4 : 0;
   for(k=0;k<4;k=k+1)begin
    rec=objects[k*76+:76];base=k<2 ? 320 : 516;
    if(rec[75] && rec[74:73]==3)begin
     found=found+1;checks=checks+1;cy=(rec[19:10]+rec[9:0])/2;
     if(cy<base-4 || cy>base+24)$fatal(1,"feed row promoted pattern%0d y%0d",p,cy);
    end
   end
   if(found!=want)$fatal(1,"guarded geometry pattern%0d got%0d expected%0d records%076h",p,found,want,objects);
   $display("OBS guarded pattern=%0d empty=%0d cycles=%0d records=%076h",p,found,cycles,objects);
   cancel=1;ticks(1);cancel=0;ticks(3);if(ready || objects!==0)$fatal(1,"guarded stale result after cancel");
  end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(5);
  for(integer p=0;p<8;p=p+1)frame(p);
  $display("PASS classified empty guard: 8 actual RGB frames, %0d EMPTY results, both ROI rows, feed above/below and phase-eroded6 rejection, legacy offset, bright-noise refusal, ambiguous row no promotion, cancel",checks);$finish;
 end
 initial begin #150000000;$fatal(1,"guarded empty watchdog");end
endmodule
