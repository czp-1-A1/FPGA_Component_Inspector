`timescale 1ns/1ps
module tb_standing_surface;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,cancel=0,we=0,measure=0;
reg [10:0] wx=0;reg [9:0] wy=0;reg [31:0] wd=0;
reg [9:0] xmin=0,xmax=0,ymin=0,ymax=0;
wire ready,normal,old_ready,old_normal;
present_surface_check #(.STANDING_REVIEW(1)) dut(clk,rst_n,cancel,we,measure,wx,wy,wd,xmin,xmax,ymin,ymax,ready,normal);
present_surface_check_p02 baseline(clk,rst_n,cancel,we,measure,wx,wy,wd,xmin,xmax,ymin,ymax,old_ready,old_normal);
integer mode=0,cx=640,cy=320,checks=0,features=0;
integer expected[0:4],expected_total[0:4];integer ex_old,old_only=0;integer actual_feature,waits,saved_features,ex_normal;
function integer gray(input integer x,y);
 integer v;
 begin
  if(mode==6)gray=(x*11+y*17+(x/8)*3)&255;
  else begin
   v=(mode==7 || mode==8) ? 200 : mode==9 ? 104 : mode==5 ? 96 : 248;
   if(mode==11)v=254;if(mode==12)v=242;if(mode==13)v=175;
   if(mode>=14 && mode<=18)v=192;
   if(mode==19 || mode==20)v=200;
   if(mode==21)v=255;if(mode==22)v=176;
   if(x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8)
    v=mode==3 ? 176 : (mode==7 || mode==8) ? 160 : mode==11 ? 224 : mode==12 ? 238 : mode==13 ? 214 : v;
   if(x>=cx+8 && x<cx+16 && y>=cy-8 && y<cy+8)
    v=mode==4 ? 176 : (mode==7 || mode==8) ? 160 : mode==11 ? 219 : mode==12 ? 226 : mode==13 ? 126 : v;
   if(y>=cy-16 && y<cy-8 && x>=cx-8 && x<cx+8)
    v=mode==1 ? 176 : mode==7 ? 160 : mode==8 ? 152 : mode==11 ? 229 : mode==12 ? 181 : mode==13 ? 157 : v;
   if(y>=cy+8 && y<cy+16 && x>=cx-8 && x<cx+8)
    v=mode==2 ? 176 : (mode==7 || mode==8) ? 160 : mode==11 ? 232 : mode==12 ? 206 : mode==13 ? 174 : v;
   if(mode==14)begin
    if(x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8)v=205;
    if(x>=cx+8 && x<cx+16 && y>=cy-8 && y<cy+8)v=186;
    if(y>=cy-16 && y<cy-8 && x>=cx-8 && x<cx+8)v=171;
    if(y>=cy+8 && y<cy+16 && x>=cx-8 && x<cx+8)v=189;
   end
   if(mode==15 && x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8)v=208;
   if(mode==16 && x>=cx+8 && x<cx+16 && y>=cy-8 && y<cy+8)v=208;
   if(mode==17 && y>=cy-16 && y<cy-8 && x>=cx-8 && x<cx+8)v=208;
   if(mode==18 && y>=cy+8 && y<cy+16 && x>=cx-8 && x<cx+8)v=208;
   if((mode==19 || mode==20) && x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8 &&
      (((y-(cy-8))/2)*4+(x-(cx-16))/2)<(mode==19 ? 8 : 9))v=208;
   if(mode==22 && x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8)v=206;
   gray=v;
  end
 end
endfunction
task clear_frame;
 begin @(negedge clk);cancel=1;we=0;measure=0;@(negedge clk);cancel=0;end
endtask
task capture(input integer skip_last);
 integer x,y,k;reg [31:0] word_value;
 begin
  for(y=225;y<616;y=y+2)for(x=388;x<896;x=x+8)begin
   word_value=0;for(k=0;k<4;k=k+1)word_value[k*8+:8]=gray(x-4+2*k,y-1);
   @(negedge clk);wx=x;wy=y;wd=word_value;we=!(skip_last && x==892 && y==615);
  end
  @(negedge clk);we=0;repeat(2)@(negedge clk);
 end
endtask
task reference;
 integer f,x,y,x0,x1,y0,y1,total,n,minimum,maximum;
 begin
  for(f=0;f<5;f=f+1)begin
   x0=cx-8;x1=cx+8;y0=cy-8;y1=cy+8;
   case(f)
    1:begin x0=cx-16;x1=cx-8;end
    2:begin x0=cx+8;x1=cx+16;end
    3:begin y0=cy-16;y1=cy-8;end
    4:begin y0=cy+8;y1=cy+16;end
   endcase
   total=0;n=0;
   for(y=y0;y<y1;y=y+2)for(x=x0;x<x1;x=x+2)begin total=total+(gray(x,y)>>3);n=n+1;end
   expected_total[f]=total;expected[f]=total/n;
  end
  minimum=expected[1];for(f=2;f<5;f=f+1)if(expected[f]<minimum)minimum=expected[f];
  ex_old=expected[0]>=13 && 5*minimum>=4*expected[0];
  maximum=expected_total[1];for(f=2;f<5;f=f+1)if(expected_total[f]>maximum)maximum=expected_total[f];
  ex_normal=ex_old && maximum*2<=expected_total[0]+16;
 end
endtask
always @(negedge clk)if(rst_n && !cancel && dut.phase==4 && dut.sample==(dut.feature==0 ? 63 : 31))begin
 actual_feature=dut.feature;
 if(ready!==old_ready)$fatal(1,"P03 changed measurement latency");
 if(dut.next_sum!==expected_total[actual_feature])$fatal(1,"exact sum mismatch feature%0d",actual_feature);
 if(dut.mean!==expected[actual_feature])$fatal(1,"feature %0d actual=%0d expected=%0d mode=%0d center=%0d,%0d",actual_feature,dut.mean,expected[actual_feature],mode,cx,cy);
 features=features+1;
end
task request(input integer should_measure);
 begin
  reference;@(negedge clk);xmin=(cx-18)/2;xmax=xmin+17;ymin=(cy-24)/2;ymax=ymin+23;measure=1;
  saved_features=features;@(negedge clk);measure=0;waits=0;
  while(!ready && waits<700)begin @(negedge clk);waits=waits+1;end
  if(!ready || normal!==(should_measure ? ex_normal : 0))$fatal(1,"completion mode=%0d ready=%b normal=%b expected=%0d",mode,ready,normal,should_measure ? ex_normal : 0);
  if(old_ready!==ready || old_normal!==(should_measure ? ex_old : 0))$fatal(1,"frozen P02 reference disagreement");
  if(should_measure && old_normal && !normal)old_only++;
  if(features-saved_features!=(should_measure ? 5 : 0))$fatal(1,"unexpected feature count");
  checks=checks+1;
 end
endtask
integer k;
initial begin
 repeat(4)@(negedge clk);rst_n=1;
 for(k=0;k<4;k=k+1)begin cx=400+2*k;cy=240;mode=6;clear_frame;capture(0);request(1);end
 cx=878;cy=598;mode=6;clear_frame;capture(0);request(1);
 cx=640;cy=320;
 for(k=0;k<23;k=k+1)begin mode=k;clear_frame;capture(0);request(1);end
 for(k=0;k<4;k=k+1)begin cx=400+2*k;cy=240;mode=14;clear_frame;capture(0);request(1);end
 cx=640;cy=320;mode=0;clear_frame;capture(1);request(0);
 clear_frame;capture(0);cx=382;request(0);cx=640;
 reference;@(negedge clk);xmin=312;xmax=326;ymin=148;ymax=171;measure=1;
 @(negedge clk);measure=0;repeat(3)@(negedge clk);if(!ready || normal)$fatal(1,"narrow body accepted");checks=checks+1;
 clear_frame;capture(0);reference;
 @(negedge clk);xmin=311;xmax=328;ymin=148;ymax=171;measure=1;
 @(negedge clk);measure=0;repeat(20)@(negedge clk);clear_frame;
 repeat(700)@(negedge clk);if(ready || normal)$fatal(1,"cancel leaked completion");checks=checks+1;
 request(0);clear_frame;capture(0);request(1);request(1);
 if(old_only<11)$fatal(1,"new bright-edge fixtures did not isolate old P02 false accepts");
 $display("PASS P03 standing surface: %0d requests, %0d exact independent five-bit means; four RAM phases, ROI edges, all dark-strip directions, ratio boundary, narrow/missing/cancel/restart",checks,features);
 $finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
