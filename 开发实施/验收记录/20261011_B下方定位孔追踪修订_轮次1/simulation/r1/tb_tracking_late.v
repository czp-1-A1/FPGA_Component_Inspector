`timescale 1ns/1ps
module tb_tracking_late;
reg clk=0,rst=0,fs=0,sof=0,accept=0,commit=0,invalid=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire locked,located;wire [10:0] x0,x1;wire [9:0] y0,y1;wire [7:0] diag;
tape_hole_tracker #(.HOLE_Y(380),.LATE_HOLE(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.frame_commit(commit),.invalidate(invalid),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.frame_locked(locked),.roi_x0(x0),.roi_x1(x1),.roi_y0(y0),.roi_y1(y1),.located(located),.diagnostic(diag));
wire sv,sn;wire [7:0] mean;wire [19:0] count;
roi_statistics #(.DYNAMIC_ROI(1)) stats(.clk(clk),.rst_n(rst),.pixel_accept(accept),.pixel_sof(sof),.pixel_x(x),.pixel_y(y),.rgb(rgb),
 .frame_commit(commit),.invalidate(invalid),.sample_valid(sv),.sample_new(sn),.mean(mean),.minimum(),.maximum(),
 .sample_pixels(count),.sample_sum(),.frame_start(fs),.dynamic_x0(x0),.dynamic_x1(x1),.dynamic_y0(y0),.dynamic_y1(y1));
integer row,beat,lane,px,h,c,w,v,frozen_x,total;
task frame(input integer shift,input integer holes,input integer present,input integer expected_lock,input integer sampled_shift,input integer expected_reason);
 begin
  @(negedge clk);fs=1;@(negedge clk);fs=0;frozen_x=x0;total=0;
  if(x0!=472+sampled_shift) $fatal(1,"frame-held ROI wrong %0d expected %0d",x0,472+sampled_shift);
  for(row=0;row<400;row=row+1) begin
   for(beat=0;beat<256;beat=beat+1) begin
    @(negedge clk);x=beat*4;y=row;accept=1;sof=(row==0 && beat==0);
    for(lane=0;lane<4;lane=lane+1) begin
     px=beat*4+lane;v=20;
     if(holes && (row==372 || row==380 || row==388)) begin
      w=row==380 ? 32 : 24;
      for(h=-2;h<=2;h=h+1) begin
       c=464+shift+h*96;
       if(holes==2 && row==372) c=c+8;
       if(px>=c-w/2 && px<c+w/2) v=180;
      end
     end
     if(present && row>=260 && row<340 && px>=472+shift && px<552+shift) v=180;
     rgb[95-lane*24-:24]={3{v[7:0]}};
     if(row>=260 && row<340 && px>=472+sampled_shift && px<552+sampled_shift) total=total+v;
    end
    if(x0!=frozen_x || x1!=frozen_x+80) $fatal(1,"ROI changed after pixels sampled");
   end
   @(negedge clk);accept=0;sof=0;repeat(3) @(negedge clk);
   if(row==340 && locked) $fatal(1,"classified before lower hole proof");
  end
  repeat(3) @(negedge clk);
  if(locked!==expected_lock || diag[7:4]!=expected_reason) $fatal(1,"late lock shift%0d got%0d reason%0d expected%0d/%0d",shift,locked,diag[7:4],expected_lock,expected_reason);
  @(negedge clk);commit=1;@(negedge clk);commit=0;repeat(40) @(negedge clk);
  if(!sv || count!=6400 || mean!=total/6400) $fatal(1,"frame-held ROI wrong statistics %0d expected%0d count%0d",mean,total/6400,count);
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;
 frame(0,1,1,0,0,5);frame(0,1,1,1,0,0);
 frame(4,1,1,1,0,0);frame(8,1,0,1,4,0);frame(4,1,0,1,8,0);frame(0,1,1,1,4,0);
 frame(0,1,1,1,0,0);frame(0,0,1,0,0,2);
 frame(0,1,0,0,0,5);frame(0,1,0,1,0,0);
 frame(8,1,1,0,0,6);frame(0,1,1,0,0,5);frame(0,1,1,1,0,0);
 frame(0,2,0,0,0,3);
 @(negedge clk);invalid=1;@(negedge clk);invalid=0;
 if(locked || diag[7:4]!=7) $fatal(1,"bad frame retained late lock");
 $display("PASS tracking late: frame-held ROI, independent 6400-pixel statistics, bounded +/-4 motion, empty, pause, occlusion, over-speed, shape and invalidation");$finish;
end
initial begin #40000000;$fatal(1,"late tracking watchdog");end
endmodule
