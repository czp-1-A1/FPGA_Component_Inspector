`timescale 1ns/1ps
module tb_hd_search;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #4.444 clk=~clk;
wire ready,fresh,located,review;wire [1:0] state;wire [12:0] fg;wire [6:0] w,h;wire [10:0] x0,x1;wire [9:0] y0,y1;wire [151:0] objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720)) dut(clk,rst,fs,sof,accept,cancel,x,y,rgb,ready,fresh,located,state,fg,w,h,x0,x1,y0,y1,review,objects);
integer pattern=0,mx=0,my=0,cycles,cases=0,i,j,l,value,pgm,checks=0;
integer left_cx=456,right_cx=552,cy=300;
reg [75:0] a,b;reg abort_processing=0;
function integer image(input integer px,py);
 integer dx,dy;begin
 image=30;
 if(pattern==5)image=(px>=40 && px<984 && py>=180 && py<440) ? 30 : 240;
 if(pattern==6)image=240;
 if(pattern!=6 && pattern!=7)begin
  if(px>=left_cx-32+mx && px<left_cx+32+mx && py>=cy-38+my && py<cy+38+my)image=180;
  if(pattern==1 || pattern==4 || pattern==5 || pattern==8 || pattern==9)begin
   if(px>=right_cx-32+mx && px<right_cx+32+mx && py>=cy-38+my && py<cy+38+my)image=180;
  end
  if(pattern==2 || pattern==3)begin
   dx=px-right_cx-mx;dy=py-cy-my;if(dx*dx+dy*dy<=81)image=150;
  end
  if(pattern==3)begin
   dx=px-left_cx-mx;dy=py-cy-my;
   if(px>=left_cx-32+mx && px<left_cx+32+mx && py>=cy-38+my && py<cy+38+my)image=30;
   if(dx*dx+dy*dy<=81)image=150;
  end
  // Rounded feed holes above the bodies must not displace the two pockets.
  if(pattern==4 || pattern==5)begin
   dx=px-left_cx-mx;dy=py-cy+80-my;if(dx*dx+dy*dy<=256)image=150;
   dx=px-right_cx-mx;if(dx*dx+dy*dy<=256)image=150;
  end
  // One recognized but low-fill body, independent of the second normal body.
  if(pattern==4 && px>=left_cx-12+mx && px<left_cx+12+mx && py>=cy-20+my && py<cy+20+my)image=30;
  // Border-connected remnants must not turn into false isolated objects.
  if(pattern==8)begin
   if(py<16 || (px>=1000 && px<1002 && py<280) ||
      (px>=1000 && px<1140 && py>=250 && py<400))image=240;
  end
  if(pattern==9 && px>=1260 && py>=100 && py<180)image=240;
 end
 end
endfunction
function integer reduced(input integer px,py);
 begin reduced=(image(px,py)+image(px+1,py)+image(px,py+1)+image(px+1,py+1))/4;end
endfunction
// Compare every captured bit with independent 2x2 source arithmetic, before
// processing clears the foreground. Includes PPC4 bubbles and odd offsets.
always @(posedge clk)if(rst && dut.cap_write && !cancel && !fs)begin
 for(integer lane=0;lane<4;lane++)begin
  integer xx,yy,g;
  xx=((dut.cap_addr%160)*4+lane)*2;yy=(dut.cap_addr/160)*2;g=reduced(xx,yy);
  if((dut.cap_data[lane] || dut.cap_ignored) !== (g>=100) || dut.cap_data[lane+4] !== (g<=100))$fatal(1,"full capture mismatch (%0d,%0d) gray=%0d data=%h",xx,yy,g,dut.cap_data);
  checks++;
 end
end
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer p,dx,dy,n,sa,sb);
 begin
 cases++;pattern=p;mx=dx;my=dy;fs=1;ticks(1);fs=0;ticks(3);
 pgm=$fopen($sformatf("hd_frame_case_%0d.pgm",cases),"w");$fwrite(pgm,"P2\n640 360\n255\n");
 for(j=0;j<360;j++)begin for(i=0;i<640;i++)$fwrite(pgm,"%0d ",reduced(i*2,j*2));$fwrite(pgm,"\n");end
 $fclose(pgm);
 for(j=0;j<720;j++)begin
  for(i=0;i<1280;i+=4)begin
   accept=1;sof=j==0 && i==0;x=i;y=j;
   for(l=0;l<4;l++)begin value=image(i+l,j);rgb[95-l*24-:24]={3{8'(value)}};end
   ticks(1);accept=0;sof=0;if((i%32)==0)ticks(2);
  end
  ticks(3);
 end
 accept=0;sof=0;ticks(5);
 if(abort_processing)begin ticks(1000);cancel=1;ticks(1);cancel=0;ticks(5);if(ready || located || objects!=0)$fatal(1,"canceled full-frame result survived");end
 else begin
  cycles=0;while(!ready && cycles<2300000)begin ticks(1);cycles++;end
  a=objects[75:0];b=objects[151:76];
  if(!ready || int'(a[75])+int'(b[75])!=n)$fatal(1,"full result count case%0d got%0d/%0d phase%0d captured%0d",cases,int'(a[75])+int'(b[75]),n,dut.phase,dut.cap_count);
  if(n>0 && a[74:73]!=sa || n>1 && b[74:73]!=sb)$fatal(1,"independent pocket classes case%0d %0d,%0d",cases,a[74:73],b[74:73]);
  if(n==2 && a[41:31]>=b[41:31])$fatal(1,"pocket numbering not left to right");
  if(p==4 && (!a[71] || b[72:69]!=0))$fatal(1,"fill diagnostic contaminated second body A%h B%h",a[72:69],b[72:69]);
  if((p==0 || p==1 || p==4 || p==5) && dx%2==0 && n>0 && (a[55:49]!=64 || a[48:42]!=76 || a[41:31]!=left_cx-34+dx || a[30:20]!=left_cx+34+dx))$fatal(1,"native-coordinate rectangle outside old ROI incorrect");
  $display("REF frame case=%0d objects=%h state=%0d FG=%0d W=%0d H=%0d X0=%0d X1=%0d Y0=%0d Y1=%0d cycles=%0d",cases,objects,state,fg,w,h,x0,x1,y0,y1,cycles);
 end
 end
endtask
initial begin
 ticks(5);rst=1;ticks(5);
 frame(1,0,0,2,2,2);frame(2,0,0,2,2,3);frame(3,0,0,2,3,3);
 frame(0,-320,-150,1,2,0);frame(1,640,300,2,2,2);
 frame(4,0,0,2,2,2);frame(5,0,0,2,2,2);frame(6,0,0,0,0,0);frame(7,0,0,0,0,0);
 abort_processing=1;frame(5,0,0,0,0,0);abort_processing=0;frame(1,0,0,2,2,2);
 // Every source pixel contributes even with odd source positioning.
 frame(1,1,1,2,2,2);frame(8,0,0,2,2,2);frame(9,0,0,2,2,2);
 $display("PASS hd search: %0d full images, %0d independent capture-bit checks, 2P/P+E/2E, far corners, feed rejection, fill reason, bright background, cancel/recovery, PPC4 bubbles",cases,checks);$finish;
end
initial begin #450000000;$fatal(1,"full search watchdog");end
endmodule
