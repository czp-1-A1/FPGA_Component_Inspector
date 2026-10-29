`timescale 1ns/1ps
module tb_tracking;
reg clk=0,rst=0,fs=0,sof=0,accept=0,commit=0,invalid=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire locked,located;wire [10:0] x0,x1;wire [9:0] y0,y1;
tape_hole_tracker dut(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.frame_commit(commit),.invalidate(invalid),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.frame_locked(locked),.roi_x0(x0),.roi_x1(x1),.roi_y0(y0),.roi_y1(y1),.located(located),.diagnostic());
wire sv,sn;wire [7:0] mean,lo,hi;wire [19:0] count;
roi_statistics #(.DYNAMIC_ROI(1),.X0(472),.X1(552),.Y0(260),.Y1(340)) stats(
 .clk(clk),.rst_n(rst),.pixel_accept(accept),.pixel_sof(sof),.pixel_x(x),.pixel_y(y),.rgb(rgb),
 .frame_commit(commit),.invalidate(invalid),.sample_valid(sv),.sample_new(sn),.mean(mean),.minimum(lo),.maximum(hi),
 .sample_pixels(count),.sample_sum(),.frame_start(fs),.dynamic_x0(x0),.dynamic_x1(x1),.dynamic_y0(y0),.dynamic_y1(y1));
integer row,beat,lane,px,h,d,c,w,v;
task frame(input integer shift,input integer holes,input integer present,input integer expected_locked);
 begin
  @(negedge clk);fs=1;@(negedge clk);fs=0;
  for(row=0;row<342;row=row+1) begin
   for(beat=0;beat<256;beat=beat+1) begin
    @(negedge clk);x=beat*4;y=row;accept=1;sof=(row==0 && beat==0);
    for(lane=0;lane<4;lane=lane+1) begin
     px=beat*4+lane;v=20;
     if(holes && (row==212 || row==220 || row==228)) begin
      w=holes==5 ? 80 : (row==220 ? 32 : 24);
      for(h=-2;h<=2;h=h+1) begin
       c=464+shift+h*(holes==3 ? 40 : 96);
       if(holes==4 && row==212) c=c+8;
       if(holes==2 && h==0) c=c-20;
       if(holes==2 && h==1) c=484+shift;
       if(px>=c-w/2 && px<c+w/2) v=180;
      end
     end
     if(present && row>=260 && row<340 && px>=472+shift && px<552+shift) v=180;
     rgb[95-lane*24-:24]={3{v[7:0]}};
    end
   end
   // Exercise sparse input beats and row gaps.
   @(negedge clk);accept=0;sof=0;repeat(3) @(negedge clk);
   if(row==240) begin
    if(locked!==expected_locked) $fatal(1,"tracking lock shift %0d holes %0d expected %0d got %b",shift,holes,expected_locked,locked);
    if(expected_locked && (x0!=472+shift || x1!=552+shift)) $fatal(1,"same-frame ROI did not follow %0d: %0d %0d",shift,x0,x1);
   end
  end
  @(negedge clk);accept=0;sof=0;commit=1;@(negedge clk);commit=0;
  repeat(40) @(negedge clk);
  if(!sv || count!=6400) $fatal(1,"dynamic ROI incomplete");
  if(expected_locked && mean!=(present ? 180 : 20)) $fatal(1,"dynamic ROI sampled wrong pocket mean %0d",mean);
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;
 frame(0,1,1,0);frame(0,1,1,1);
 frame(12,1,1,1);frame(24,1,0,1);frame(16,1,0,1);frame(0,1,1,1);
 frame(0,0,1,0);frame(0,1,0,0);frame(0,1,0,1);
 frame(32,1,1,0);frame(0,1,1,0);frame(0,1,1,1);
 frame(0,0,0,0);frame(0,2,0,0);frame(0,3,0,0);frame(0,4,0,0);frame(0,5,0,0);
 frame(0,1,0,0);frame(0,1,0,1);
 @(negedge clk);invalid=1;@(negedge clk);invalid=0;
 if(locked) $fatal(1,"invalid acquisition retained lock");
 $display("PASS tracking: same-frame bidirectional ROI, empty pocket, pause, occlusion, excessive step, recovery, invalidation");
 $finish;
end
initial begin #40000000;$fatal(1,"tracking watchdog");end
endmodule
