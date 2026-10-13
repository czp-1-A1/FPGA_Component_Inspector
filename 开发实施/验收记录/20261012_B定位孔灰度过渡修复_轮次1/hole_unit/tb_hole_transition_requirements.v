`timescale 1ns/1ps
module tb_hole_transition_requirements;
reg clk=0,rst=0,sof=0,accept=0;
reg [10:0] x=0;reg [9:0] y=380;reg [7:0] gray=0;
always #5 clk=~clk;
wire done,found;wire [10:0] center;wire [6:0] width;
hole_scanline #(.ROW(380)) dut(.clk(clk),.rst_n(rst),.sof(sof),.accept(accept),.x(x),.anchor(11'd464),.y(y),.gray(gray),.radius(6'd24),.done(done),.found(found),.center(center),.width(width));
integer cases=0,csv,phase,shoulder,l,r,beat;
// Profiles are specified independently in pixel coordinates. MID does not
// enlarge the >=120 bright core. Pattern 4/5 interrupt a required dark margin.
function integer value_at(input integer px,w,pitch,bg,fg,left_len,right_len,mid,shift,pattern);
 integer k,hc,vv;
 begin
  vv=bg;
  if(pattern==1 || pattern==6) vv=110;
  for(k=-2;k<=2;k=k+1) begin
   hc=464+shift+k*pitch;
   if(pattern!=1 && (pattern!=2 || k==0)) begin
    if(px>=hc-w/2-left_len && px<hc-w/2) vv=mid;
    if(px>=hc+w/2 && px<hc+w/2+right_len) vv=mid;
    if(px>=hc-w/2 && px<hc+w/2) vv=fg;
    if(pattern==3 && px>=hc && px<hc+8) vv=110;
    if(pattern==4 && px>=hc+w/2+right_len+4 && px<hc+w/2+right_len+8) vv=110;
    if(pattern==5 && px>=hc-w/2-left_len-8 && px<hc-w/2-left_len-4) vv=110;
    if(pattern==6 && px>=hc-w/2-left_len-4 && px<hc-w/2-left_len) vv=20;
   end
  end
  value_at=vv;
 end
endfunction
task run_case(input integer w,pitch,bg,fg,left_len,right_len,mid,shift,pattern,expected,expected_width);
 integer first_sample,last_sample,expected_center;
 begin
  @(negedge clk);sof=1;accept=0;
  @(negedge clk);sof=0;
  for(beat=0;beat<256;beat=beat+1) begin
   @(negedge clk);accept=1;x=beat*4;y=380;
   gray=value_at(beat*4,w,pitch,bg,fg,left_len,right_len,mid,shift,pattern);
   if(beat%7==0) begin @(negedge clk);accept=0;gray=255;x=0;y=0;end
  end
  @(negedge clk);accept=0;repeat(4)@(negedge clk);
  cases=cases+1;
  $display("CASE %0d w=%0d pitch=%0d bg=%0d fg=%0d left=%0d right=%0d mid=%0d shift=%0d pattern=%0d found=%0d center=%0d width=%0d",cases,w,pitch,bg,fg,left_len,right_len,mid,shift,pattern,found,center,width);
  $fdisplay(csv,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cases,w,pitch,bg,fg,left_len,right_len,mid,shift,pattern,expected,found,center,width);
  if(done!==1 || found!==expected) $fatal(1,"requirement case %0d expected found %0d",cases,expected);
  if(expected) begin
   first_sample=((464+shift-w/2+3)/4)*4;
   last_sample=((464+shift+w/2-1)/4)*4;
   if(mid>=120) begin first_sample=first_sample-left_len;last_sample=last_sample+right_len;end
   expected_center=(first_sample+last_sample+4)/2;
   if(center!==expected_center || width!==expected_width) $fatal(1,"bright core geometry case %0d expected center %0d width %0d",cases,expected_center,expected_width);
  end
 end
endtask
initial begin
 csv=$fopen("transition_cases.csv","w");$fdisplay(csv,"id,width,pitch,bg,fg,left,right,mid,shift,pattern,expected,found,center,measured_width");
 repeat(5)@(negedge clk);rst=1;
 // All sub-beat phases and independent 0/4/8-pixel boundaries, including
 // every middle-gray boundary value at both limits and the original failure.
 for(phase=0;phase<4;phase=phase+1)
  for(shoulder=0;shoulder<3;shoulder=shoulder+1)
   for(l=0;l<=8;l=l+4) for(r=0;r<=8;r=r+4)
    run_case(32,96,20,180,l,r,shoulder==0 ? 101 : shoulder==1 ? 110 : 119,phase,0,1,32);
 run_case(32,96,20,180,12,0,110,0,0,0,0);
 run_case(32,96,20,180,0,12,110,0,0,0,0);
 run_case(32,96,20,180,12,12,110,0,0,0,0);
 run_case(32,96,20,180,16,16,110,0,0,0,0);
 run_case(32,96,20,180,4,4,100,0,0,1,32);
 run_case(32,96,20,180,4,4,120,0,0,1,40);
 run_case(32,96,100,120,8,8,110,0,0,1,32);
 run_case(32,96,20,119,0,0,110,0,0,0,0);
 run_case(32,96,101,180,0,0,110,0,0,0,0);
 run_case(16,96,20,180,8,8,110,0,0,0,0);
 run_case(20,96,20,180,8,8,110,0,0,1,20);
 run_case(64,96,20,180,8,8,110,0,0,1,64);
 run_case(68,96,20,180,0,0,110,0,0,0,0);
 run_case(32,72,20,180,8,8,110,0,0,1,32);
 run_case(32,120,20,180,8,8,110,0,0,1,32);
 run_case(32,68,20,180,8,8,110,0,0,0,0);
 run_case(32,124,20,180,8,8,110,0,0,0,0);
 run_case(32,96,20,180,8,8,110,24,0,1,32);
 run_case(32,96,20,180,8,8,110,28,0,0,0);
 run_case(32,96,20,180,8,8,110,0,1,0,0);
 run_case(32,96,20,180,8,8,110,0,2,0,0);
 run_case(64,96,20,180,8,8,110,0,3,0,0);
 run_case(32,96,20,180,8,8,110,0,4,0,0);
 run_case(32,96,20,180,8,8,110,0,5,0,0);
 run_case(32,96,20,180,8,8,110,0,6,0,0);
 $display("PASS bounded hole transition requirements: %0d cases",cases);
 $fclose(csv);$finish;
end
initial begin #2000000;$fatal(1,"watchdog");end
endmodule
