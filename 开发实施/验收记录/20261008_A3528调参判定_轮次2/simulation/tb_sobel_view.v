`timescale 1ns/1ps
module tb_sobel_view;
localparam W=32,H=12,PIXELS=W*H,BITS=PIXELS*24;
reg clk=0,rst=0,pv=0,sof=0,last=0,early=0,invalid=0;
reg [95:0] rgb=0;reg [1:0] mode=0;
always #5 clk=~clk;
wire ov,ol,oe,frame_bad;wire [95:0] color;wire [10:0] ox;wire [9:0] oy;
wire [12:0] cp,ec;wire [23:0] es;
roi_sobel_view #(.WIDTH(W),.HEIGHT(H),.X0(3),.X1(29),.Y0(1),.Y1(11),
 .CORE_X0(9),.CORE_X1(19),.CORE_Y0(4),.CORE_Y1(8)) dut(
 .clk(clk),.rst_n(rst),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(early),
 .rgb(rgb),.mode(mode),.invalidate(invalid),.out_valid(ov),.out_last(ol),.out_early_sof(oe),
 .view_ready(1'b1),.frame_bad(frame_bad),.out_rgb(color),.out_x(ox),.out_y(oy),.core_pixels(cp),.edge_count(ec),.edge_sum(es));
wire packed_valid,packed_sof;wire [127:0] packed_data;
data_96bit_to_128bit pack(clk,rst,oe,ov,color,packed_sof,packed_valid,packed_data);
reg [23:0] original[0:PIXELS-1],expected[0:PIXELS-1];
integer luminance[0:PIXELS-1];
reg [BITS-1:0] stream;
integer seen=0,words=0,early_count=0,cycles=0,early_cycle=0,frame_number=0;
integer ref_edges=0,ref_sum=0,x,y,i,j,k,xx,yy,gx,gy,mag,r,g,b;
reg checking=0;
function [23:0] pixel;
 input integer x,y,pattern;integer a,rr,gg,bb;
 begin
  case(pattern)
   0: pixel=24'h214365;
   1: begin a=x<13 ? 31 : 201;pixel={8'(a),8'(a),8'(a)};end
   2: begin a=y<6 ? 200 : 24;pixel={8'(a),8'(a),8'(a)};end
   3: begin a=x+y<20 ? 11 : 230;pixel={8'(a),8'(a),8'(a)};end
   default: begin rr=(x*17+y*37)&255;gg=(x*29+y*11)&255;bb=(x*7+y*19)&255;pixel={8'(rr),8'(gg),8'(bb)};end
  endcase
 end
endfunction
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task reference;input integer pattern;
 begin
  ref_edges=0;ref_sum=0;
  for(y=0;y<H;y=y+1) for(x=0;x<W;x=x+1) begin
   i=y*W+x;original[i]=pixel(x,y,pattern);
   r=original[i][23:16];g=original[i][15:8];b=original[i][7:0];luminance[i]=(r+2*g+b)/4;
  end
  for(y=0;y<H;y=y+1) for(x=0;x<W;x=x+1) begin
   i=y*W+x;mag=0;
   if(x>3 && x<28 && y>1 && y<10) begin
    gx=0;gy=0;
    // Integer 2-D kernel reference, independent of the RTL group/window logic.
    for(j=-1;j<=1;j=j+1) for(k=-1;k<=1;k=k+1) begin
     gx=gx+k*(j==0 ? 2 : 1)*luminance[(y+j)*W+x+k];
     gy=gy+j*(k==0 ? 2 : 1)*luminance[(y+j)*W+x+k];
    end
    mag=(gx<0 ? -gx : gx)+(gy<0 ? -gy : gy);
   end
   if(x>=9 && x<19 && y>=4 && y<8) begin ref_sum=ref_sum+mag;if(mag>=80) ref_edges=ref_edges+1;end
   expected[i]=original[i];
   if(x>=3 && x<29 && y>=1 && y<11 && mode[0]) expected[i]={3{8'(luminance[i])}};
   if(x>3 && x<28 && y>1 && y<10 && mode[1] && mag>=80) expected[i]=24'hffae64;
   stream[BITS-1-i*24-:24]=expected[i];
  end
 end
endtask
always @(posedge clk) cycles=cycles+1;
always @(negedge clk) if(checking) begin
 if(oe) begin early_count=early_count+1;early_cycle=cycles;if(seen!=0) $fatal(1,"early notification overlapped prior RGB");end
 if(ov) begin
  if(seen==0 && (early_count!=1 || cycles-early_cycle<32)) $fatal(1,"DDR reset notification is not early enough");
  if(seen>=PIXELS || ox!=(seen%W) || oy!=seen/W || ol!=(seen%W==W-4)) $fatal(1,"video coordinates/EOL frame %0d seen %0d at %0d,%0d",frame_number,seen,ox,oy);
  for(integer n=0;n<4;n=n+1) if(color[95-n*24-:24]!==expected[seen+n])
   $fatal(1,"Sobel RGB frame=%0d mode=%0d pixel=%0d xy=%0d,%0d actual=%h expected=%h",frame_number,mode,seen+n,(seen+n)%W,(seen+n)/W,color[95-n*24-:24],expected[seen+n]);
  seen=seen+4;
 end
 if(packed_valid) begin
  if(words>=BITS/128 || packed_data!==stream[BITS-1-words*128-:128]) $fatal(1,"128-bit byte stream frame=%0d word=%0d",frame_number,words);
  words=words+1;
 end
end
task frame;input integer pattern,bubbles,cancel;
 begin
  frame_number=frame_number+1;reference(pattern);seen=0;words=0;early_count=0;checking=1;
  early=1;ticks(1);early=0;
  // Old AWB valid can survive the early notification, before the true SOF.
  pv=1;rgb=96'hf12345_f12345_f12345_f12345;ticks(4);pv=0;ticks(36);
  if(frame_bad) $fatal(1,"pre-SOF old pixels poisoned new frame %0d",frame_number);
  for(yy=0;yy<H;yy=yy+1) begin
   for(xx=0;xx<W;xx=xx+4) begin
    rgb={original[yy*W+xx],original[yy*W+xx+1],original[yy*W+xx+2],original[yy*W+xx+3]};
    pv=1;sof=yy==0 && xx==0;last=xx==W-4;ticks(1);pv=0;sof=0;last=0;
    if(bubbles) ticks((xx/4+yy)%3);
   end
   if(cancel && yy==6) begin invalid=1;ticks(1);invalid=0;end
   if(bubbles) ticks(7);else ticks(0); // consecutive rows must not need a pipeline drain gap
  end
  ticks(100);
  if(seen!=PIXELS || words!=BITS/128 || early_count!=1) $fatal(1,"frame replay/count/packer %0d pixels=%0d words=%0d",frame_number,seen,words);
  if(cancel) begin if(cp!=0 || ec!=0 || es!=0) $fatal(1,"invalidated edge statistics revived");end
  else if(mode[1] ? (cp!=40 || ec!=ref_edges || es!=ref_sum) : (cp!=0 || ec!=0 || es!=0)) $fatal(1,"edge statistics frame %0d count=%0d edge=%0d/%0d strength=%0d/%0d",frame_number,cp,ec,ref_edges,es,ref_sum);
  $display("OBS Sobel frame=%0d mode=%0d pattern=%0d bubbles=%0d core=%0d edges=%0d strength=%0d",frame_number,mode,pattern,bubbles,cp,ec,es);
  checking=0;ticks(5);
 end
endtask
initial begin
 ticks(4);rst=1;ticks(4);
 for(integer view=0;view<4;view=view+1) begin mode=2'(view);frame(1,view%2,0);end
 mode=3;frame(0,0,0);frame(2,1,0);frame(3,0,0);frame(4,0,0);frame(4,1,1);frame(4,1,0);
 rst=0;ticks(3);rst=1;ticks(4);mode=0;frame(4,0,0);
 $display("PASS Sobel view: independent all-pixel 4-mode RGB, 3x3 gradients, nonaligned ROI, horizontal/vertical/diagonal/color, bubbles, 128-bit packing, pre-SOF old pixels, tail, cancellation and reset warmup");$finish;
end
initial begin #1000000;$fatal(1,"Sobel watchdog");end
endmodule
