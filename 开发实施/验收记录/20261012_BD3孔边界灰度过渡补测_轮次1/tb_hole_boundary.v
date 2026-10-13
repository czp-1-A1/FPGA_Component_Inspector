`timescale 1ns/1ps
module tb_hole_boundary;
reg clk=0,rst=0,fs=0,sof=0,accept=0,commit=0;
reg [10:0] x=0;reg [9:0] y=0;reg [7:0] gray=0;
wire [95:0] rgb={12{gray}};
always #5 clk=~clk;
wire done,found;wire [10:0] center;wire [6:0] width;
hole_scanline #(.ROW(380)) line_dut(.clk(clk),.rst_n(rst),.sof(sof||fs),.accept(accept),.x(x),.anchor(11'd464),.y(y),.gray(gray),.radius(6'd24),.done(done),.found(found),.center(center),.width(width));
wire locked,located;wire [7:0] diag;wire [10:0] x0,x1;
tape_hole_tracker #(.HOLE_Y(380),.LATE_HOLE(1)) tracker(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.frame_commit(commit),.invalidate(1'b0),.pixel_x(x),.pixel_y(y),.rgb(rgb),.frame_locked(locked),.roi_x0(x0),.roi_x1(x1),.roi_y0(),.roi_y1(),.located(located),.diagnostic(diag));
integer cases=0,rows,beat,h,c,v,csv;
function integer value_at(input integer px,w,pitch,bg,fg,left_shoulder,right_shoulder,shoulder_gray,shift);
 integer k,hc,vv;
 begin
  vv=bg;
  for(k=-2;k<=2;k=k+1) begin
   hc=464+shift+k*pitch;
   if(left_shoulder && px>=hc-w/2-4 && px<hc-w/2) vv=shoulder_gray;
   if(right_shoulder && px>=hc+w/2 && px<hc+w/2+4) vv=shoulder_gray;
   if(px>=hc-w/2 && px<hc+w/2) vv=fg;
  end
  value_at=vv;
 end
endfunction
task run_case(input integer id,w,pitch,bg,fg,left_shoulder,right_shoulder,shoulder_gray,shift,expected);
 begin
  @(negedge clk);fs=1;accept=0;@(negedge clk);fs=0;sof=1;x=0;y=0;accept=1;gray=bg;
  @(negedge clk);sof=0;accept=0;
  for(rows=0;rows<3;rows=rows+1) begin
   for(beat=0;beat<256;beat=beat+1) begin
    @(negedge clk);accept=1;x=beat*4;y=372+rows*8;
    gray=value_at(beat*4,w,pitch,bg,fg,left_shoulder,right_shoulder,shoulder_gray,shift);
    if(beat%7==0) begin @(negedge clk);accept=0;end
   end
   @(negedge clk);accept=0;repeat(4)@(negedge clk);
  end
  repeat(4)@(negedge clk);
  cases=cases+1;
  $display("CASE id=%0d width=%0d pitch=%0d bg=%0d fg=%0d left=%0d right=%0d shoulder=%0d shift=%0d found=%0d measured_center=%0d measured_width=%0d ROW=%0d reason=%0d lock=%0d",id,w,pitch,bg,fg,left_shoulder,right_shoulder,shoulder_gray,shift,found,center,width,diag[2:0],diag[7:4],locked);
  $fdisplay(csv,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",id,w,pitch,bg,fg,left_shoulder,right_shoulder,shoulder_gray,shift,found,center,width,diag[2:0],diag[7:4],locked);
  if(done!==1 || located!==1 || found!==expected || diag[2:0]!=(expected ? 7 : 0)) $fatal(1,"characterization mismatch case %0d expected %0d",id,expected);
  if(id==1 && (locked!==1 || diag[7:4]!=0)) $fatal(1,"abrupt profile did not acquire on second frame");
  if(!expected && (locked!==0 || diag[7:4]!=2)) $fatal(1,"rejected profile must report NO HOLE and revoke lock");
  @(negedge clk);commit=1;@(negedge clk);commit=0;
 end
endtask
initial begin
 csv=$fopen("cases.csv","w");$fdisplay(csv,"id,width,pitch,bg,fg,left,right,shoulder,shift,found,center,measured_width,row,reason,lock");
 repeat(5)@(negedge clk);rst=1;
 run_case(0,32,96,20,180,0,0,0,0,1);
 run_case(1,32,96,20,180,0,0,0,0,1);
 run_case(2,32,96,20,180,1,0,110,0,0);
 run_case(3,32,96,20,180,0,1,110,0,0);
 run_case(4,32,96,20,180,1,1,110,0,0);
 run_case(5,32,96,20,180,1,1,100,0,1);
 run_case(6,32,96,20,180,1,1,101,0,0);
 run_case(7,32,96,20,180,1,1,119,0,0);
 run_case(8,32,96,20,180,1,1,120,0,1);
 run_case(9,32,96,100,120,0,0,0,0,1);
 run_case(10,32,96,20,119,0,0,0,0,0);
 run_case(11,32,96,101,180,0,0,0,0,0);
 run_case(12,16,96,20,180,0,0,0,0,0);
 run_case(13,20,96,20,180,0,0,0,0,1);
 run_case(14,64,96,20,180,0,0,0,0,1);
 run_case(15,68,96,20,180,0,0,0,0,0);
 run_case(16,32,72,20,180,0,0,0,0,1);
 run_case(17,32,120,20,180,0,0,0,0,1);
 run_case(18,32,68,20,180,0,0,0,0,0);
 run_case(19,32,124,20,180,0,0,0,0,0);
 run_case(20,32,96,20,180,0,0,0,24,1);
 run_case(21,32,96,20,180,0,0,0,28,0);
 $display("PASS frozen D3 hole boundary characterization: %0d cases, abrupt acquisition, gray transition rejection, brightness/width/pitch/anchor limits and bubbles",cases);
 $fclose(csv);$finish;
end
initial begin #1000000;$fatal(1,"watchdog");end
endmodule
