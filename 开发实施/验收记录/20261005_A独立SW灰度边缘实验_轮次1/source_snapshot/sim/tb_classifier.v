`timescale 1ns/1ps
module tb_classifier;
reg clk=0,dclk=0,rst=0,fs=0,fe=0,hs=0,rv=0,cfg=1,pv=0,ps=0,pl=0,cal=0;
reg [1:0] lane=0;
reg [95:0] rgb=0;
reg [7:0] threshold=60;
reg high_side=1;
always #5 clk=~clk;
always #7 dclk=~dclk;
wire [10:0] x;
wire [9:0] y;
wire accept,commit,invalid,sv,new_sample;
wire [7:0] mean,lo,hi;
wire [19:0] count;
wire [27:0] sum;
wire [1:0] state;
wire cancel=invalid || !cfg || |lane;
wire [26:0] display;
roi_frame_guard #(.WIDTH(20),.HEIGHT(12)) guard(clk,rst,fs,fe,hs,rv,lane,cfg,pv,ps,pl,x,y,accept,commit,invalid);
roi_statistics #(.X0(1),.X1(17),.Y0(2),.Y1(10)) stats(clk,rst,accept,ps,x,y,rgb,commit,cancel,sv,mean,lo,hi,count,sum,new_sample,fs);
roi_classifier classifier(clk,rst,cal,fs,cancel,sv,new_sample,mean,threshold,high_side,state);
status_cdc #(.WIDTH(27)) mailbox(clk,dclk,rst,{state,sv,mean,lo,hi},display);
integer updates=0,frames=0;
reg saved_valid;
reg [27:0] saved_sum;
reg [7:0] saved_mean;
always @(posedge clk) if(rst && new_sample) updates=updates+1;
task ticks; input integer n; begin repeat(n) @(negedge clk); end endtask
task expect_state;input [1:0] expected;begin
 #1;if(state!==expected) $fatal(1,"state frame %0d expected=%d got=%d fs=%b child_fs=%b cancel=%b fresh=%b",frames,expected,state,fs,classifier.frame_start,cancel,classifier.fresh);
end endtask
task start_frame;begin
 @(negedge clk);frames=frames+1;updates=0;
 saved_valid=sv && guard.reported;saved_sum=sum;saved_mean=mean;
 fs=1;expect_state(cal ? 1 : 0);ticks(1);fs=0;ticks(4);
 expect_state(cal ? 1 : 0);
 if(saved_valid && (!sv || sum!=saved_sum || mean!=saved_mean)) $fatal(1,"new FS discarded completed tuning statistics");
end endtask
task native_frame;input integer short_row;
integer r,b;
begin
 for(r=0;r<12;r=r+1) begin
  hs=1;for(b=0;b<((short_row && r==4)?4:5);b=b+1) begin rv=1;ticks(1);rv=0;ticks(1);end
  hs=0;ticks(20);
 end
 fe=1;ticks(1);fe=0;ticks(2);
end endtask
// Four independently specified images over 16x8 ROI; outside brightness is separate.
task pixel_frame;input integer pattern,outside,short_line;
integer r,b,l,px,index,value;
begin
 for(r=0;r<12;r=r+1) begin
  for(b=0;b<((short_line && r==6)?4:5);b=b+1) begin
   for(l=0;l<4;l=l+1) begin
    px=b*4+l;value=outside;
    if(px>=1 && px<17 && r>=2 && r<10) begin
     index=(r-2)*16+px-1;
     case(pattern)
      0: value=40;
      1: value=index<96 ? 40 : 200;
      2: value=index==127 ? 255 : 40;
      3: value=60;
     endcase
    end
    rgb[95-l*24-:24]={8'(value),8'(value),8'(value)};
   end
   pv=1;ps=r==0 && b==0;pl=b==((short_line && r==6)?3:4);
   ticks(1);pv=0;ps=0;pl=0;ticks(1+b%3);
  end
  ticks(3);
 end
end endtask
task check_sample;input integer expected_sum,expected_mean,expected_lo,expected_hi;
input [1:0] expected_state;
begin
 ticks(40);
 if(!sv || updates!=1 || count!=128 || sum!=expected_sum || mean!=expected_mean || lo!=expected_lo || hi!=expected_hi)
  $fatal(1,"math frame %0d updates=%d pixels=%d sum=%d mean/min/max=%d/%d/%d",frames,updates,count,sum,mean,lo,hi);
 expect_state(expected_state);
 repeat(35) @(negedge dclk);
 if(display!=={expected_state,1'b1,8'(expected_mean),8'(expected_lo),8'(expected_hi)}) $fatal(1,"27-bit mailbox snapshot mismatch");
 $display("OBS classifier image=%0d sum=%0d mean=%0d min/max=%0d/%0d state=%0d",frames,sum,mean,lo,hi,state);
 @(negedge clk);
end endtask
task good_image;input integer pattern,outside,s,m,l,h;input [1:0] expected;
begin start_frame;native_frame(0);pixel_frame(pattern,outside,0);check_sample(s,m,l,h,expected);end endtask

// Direct classifier probe exercises endpoint comparisons and rearming without a new pulse.
reg ucal=0,ufs=0,uinvalid=0,uvalid=0,unew=0,uhigh=1;
reg [7:0] umean=0,uthreshold=0;
wire [1:0] ustate;
roi_classifier unit(clk,rst,ucal,ufs,uinvalid,uvalid,unew,umean,uthreshold,uhigh,ustate);
task probe;input integer value,t;input integer direction;input [1:0] expected;
begin
 ucal=0;ticks(1);umean=value;uthreshold=t;uhigh=direction;ucal=1;uvalid=1;unew=0;ticks(2);
 if(ustate!==1) $fatal(1,"rearm revived old sample");
 unew=1;ticks(1);unew=0;#1;if(ustate!==expected) $fatal(1,"threshold boundary %0d/%0d direction %d",value,t,direction);
end endtask
initial begin
 ticks(4);rst=1;ticks(4);expect_state(0);
 good_image(1,255,10240,80,40,200,0); // Valid statistics cannot classify without calibration.
 cal=1;ticks(3);expect_state(1); // Existing valid sample is deliberately insufficient.
 good_image(0,255,5120,40,40,40,3);
 good_image(1,0,10240,80,40,200,2);
 good_image(2,255,5335,41,40,255,3); // A single specular pixel does not cross T=60 here.
 good_image(3,0,7680,60,60,60,2); // Equal threshold belongs to presence.
 good_image(0,0,5120,40,40,40,3); // Outside ROI changed from 255 to 0; stats remain exact.
 start_frame;native_frame(1);pixel_frame(1,0,0);ticks(40);
 if(sv || updates) $fatal(1,"short native frame accepted");expect_state(1);
 good_image(1,0,10240,80,40,200,2);
 start_frame;native_frame(0);pixel_frame(1,0,1);ticks(40);
 if(sv || updates) $fatal(1,"truncated processed frame accepted");expect_state(1);
 good_image(0,0,5120,40,40,40,3);
 start_frame;native_frame(0);pixel_frame(1,0,0);
 cfg=0;ticks(1);cfg=1;ticks(40);
 if(sv || updates) $fatal(1,"config change did not cancel pending division");expect_state(1);
 good_image(1,0,10240,80,40,200,2);
 start_frame;native_frame(0);pixel_frame(1,0,0);
 fs=1;ticks(1);fs=0;ticks(40);
 if(updates) $fatal(1,"old division survived new FS");expect_state(1);
 good_image(0,0,5120,40,40,40,3);
 lane=1;expect_state(1);ticks(1);lane=0;ticks(3);expect_state(1);
 good_image(1,0,10240,80,40,200,2);
 cal=0;ticks(1);high_side=0;cal=1;ticks(2);expect_state(1);
 good_image(0,255,5120,40,40,40,2);
 good_image(1,0,10240,80,40,200,3);
 good_image(3,255,7680,60,60,60,2);
 probe(59,60,1,3);probe(60,60,1,2);probe(61,60,1,2);
 probe(59,60,0,2);probe(60,60,0,2);probe(61,60,0,3);
 probe(0,0,1,2);probe(255,255,1,2);probe(254,255,1,3);
 probe(255,255,0,2);probe(0,0,0,2);probe(1,0,0,3);
 ufs=1;#1;if(ustate!==1) $fatal(1,"FS did not suppress result immediately");ticks(1);ufs=0;
 unew=1;ticks(1);unew=0;uinvalid=1;#1;if(ustate!==1) $fatal(1,"invalidate suppression");ticks(1);uinvalid=0;
 rst=0;ticks(2);rst=1;ticks(2);expect_state(1);if(ustate!==1) $fatal(1,"reset revived classification");
 $display("PASS classifier: independent 128-pixel sums, both polarities/equality/0/255, bubbles/outside/specular, UNCAL/rearm/FS/config/lane/truncation/reset/recovery and 27-bit CDC");
 $finish;
end
initial begin #1000000;$fatal(1,"classifier watchdog");end
endmodule
