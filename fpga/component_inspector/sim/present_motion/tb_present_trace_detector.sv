`timescale 1ns/1ps
module tb_present_trace_detector;
reg clk=0;always #5 clk=~clk;
reg rst=0,fs=0,sof=0,accept=0,abort_frame=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire [127:0] trace;
wire n_ready,g_ready;
wire n_sample_new,g_sample_new;
wire n_located,g_located;
wire [1:0] n_state,g_state;
wire [12:0] n_foreground_count,g_foreground_count;
wire [6:0] n_box_width,g_box_width;
wire [6:0] n_box_height,g_box_height;
wire [10:0] n_box_x0,g_box_x0;
wire [10:0] n_box_x1,g_box_x1;
wire [9:0] n_box_y0,g_box_y0;
wire [9:0] n_box_y1,g_box_y1;
wire n_review_required,g_review_required;
wire [151:0] n_objects,g_objects;
wire [303:0] n_region_objects,g_region_objects;
wire [31:0] n_empty_probe,g_empty_probe;
wire [607:0] n_recorder_objects,g_recorder_objects;
wire n_probe_ready,g_probe_ready;
frame_shape_search #(.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1),.PRESENT_TRACE(1)) dut(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(abort_frame),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.ready(n_ready),.sample_new(n_sample_new),.located(n_located),.state(n_state),.foreground_count(n_foreground_count),.box_width(n_box_width),.box_height(n_box_height),.box_x0(n_box_x0),.box_x1(n_box_x1),.box_y0(n_box_y0),.box_y1(n_box_y1),.review_required(n_review_required),.objects(n_objects),.region_objects(n_region_objects),.empty_probe(n_empty_probe),.recorder_objects(n_recorder_objects),.probe_ready(n_probe_ready), .probe_record(trace));
frame_shape_search_r22 #(.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) golden(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(abort_frame),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.ready(g_ready),.sample_new(g_sample_new),.located(g_located),.state(g_state),.foreground_count(g_foreground_count),.box_width(g_box_width),.box_height(g_box_height),.box_x0(g_box_x0),.box_x1(g_box_x1),.box_y0(g_box_y0),.box_y1(g_box_y1),.review_required(g_review_required),.objects(g_objects),.region_objects(g_region_objects),.empty_probe(g_empty_probe),.recorder_objects(g_recorder_objects),.probe_ready(g_probe_ready));
integer scenario=0,px,py,l,v,fd,ticks_count,cycles=0,checks=0,weak_cases=0,swap_cases=0,roi1_cases=0,no_p_cases=0,abort_checks=0;
integer shift_x=0,body_y=320,left_x=602,right_x=690,body_level=180,second_level=180,with_second=1,with_empty=0,with_roi1=0,only_roi1=0,thin=0,hot_edge=0,no_body=0,left_only_hot=0;
always @(posedge clk)begin #1;if(rst)begin
 if({n_ready,n_sample_new,n_located,n_state,n_foreground_count,n_box_width,n_box_height,n_box_x0,n_box_x1,n_box_y0,n_box_y1,n_review_required,n_objects,n_region_objects,n_empty_probe,n_recorder_objects,n_probe_ready} !== {g_ready,g_sample_new,g_located,g_state,g_foreground_count,g_box_width,g_box_height,g_box_x0,g_box_x1,g_box_y0,g_box_y1,g_review_required,g_objects,g_region_objects,g_empty_probe,g_recorder_objects,g_probe_ready} || dut.phase!==golden.phase)$fatal(1,"cycle exact public/FSM mismatch scene%0d phase%0d/%0d",scenario,dut.phase,golden.phase);
 cycles++;
end end
function automatic integer part(input integer xx,yy,bx,by,level);
integer ax,ay,ww;begin ax=xx-bx;ay=yy-(by-22);ww=thin ? 14 : 36;
 part=(ax>=0 && ax<ww && ay>=0 && ay<44 && !((ax<4 || ax>=ww-4)&&(ay<8 || ay>=36))) ? level : 30;
 if((hot_edge || (left_only_hot && bx==left_x+shift_x)) && ax>=2 && ax<10 && ay>=8 && ay<36)part=230;
end endfunction
function automatic integer image(input integer xx,yy);
integer q;begin image=30;
 if(!no_body && !only_roi1)begin
  q=part(xx,yy,left_x+shift_x,body_y,body_level);if(q>image)image=q;
  if(with_second)begin q=part(xx,yy,right_x+shift_x,body_y,second_level);if(q>image)image=q;end
 end
 if(with_roi1 || only_roi1)begin q=part(xx,yy,650+shift_x,500,second_level);if(q>image)image=q;end
 if(with_empty && (xx-640)*(xx-640)*144+(yy-320)*(yy-320)*144<=5184)image=170;
end endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task configure(input integer n);begin
 shift_x=n%4;body_y=320;left_x=602;right_x=690;body_level=180;second_level=180;
 with_second=1;with_empty=0;with_roi1=0;only_roi1=0;thin=0;hot_edge=0;no_body=0;left_only_hot=0;
 case(n)
  1:begin left_x=540;right_x=640;end
  2:begin only_roi1=1;with_second=0;end
  3:begin no_body=1;with_empty=1;end
  4:begin body_level=88;with_second=0;end
  5:begin hot_edge=1;with_second=0;end
  6:begin thin=1;with_second=0;end
  7:begin left_x=560;with_second=0;with_empty=1;end
  8:begin with_roi1=1;second_level=210;end
  9:begin left_x=399;with_second=0;end
  10:begin left_x=872;with_second=0;end
  11:begin shift_x=1;body_y=321;end
 endcase
end endtask
task send_frame;begin
 fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;sof=px==0 && py==0;accept=1;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};if(fd!=0)$fwrite(fd,"%c",8'(v));end
   ticks(1);accept=0;sof=0;
  end ticks(2);
 end
end endtask
reg [75:0] ob;integer slot,number_p;
task finish_frame;begin
 ticks_count=0;while(!n_ready && ticks_count<600000)begin ticks(1);ticks_count++;end
 if(!n_ready)$fatal(1,"analysis deadline scene%0d",scenario);ticks(2);
 number_p=0;for(slot=0;slot<4;slot++)if(n_region_objects[slot*76+75] && n_region_objects[slot*76+73+:2]==2)number_p++;
 if(number_p==0)begin if(trace!==0)$fatal(1,"no P but trace valid");no_p_cases++;end
 else begin
  if(trace[127:124]!==1 || !trace[123] || trace[121])$fatal(1,"trace format/selection");
  slot=trace[122]*2+trace[120];ob=n_region_objects[slot*76+:76];
  if(!ob[75] || ob[74:73]!=2 || ob[72:69]!==trace[17:14])$fatal(1,"final public object/reason mapping scene%0d slot%0d rec%019h trace%032h",scenario,slot,ob,trace);
  if(scenario==16 && (trace[17:14]==0 || trace[120]!=0))$fatal(1,"review-priority observer missed the reviewed left P beside the normal right P; objects%076h trace%032h",n_region_objects,trace);
  if(trace[119])begin weak_cases++;if(trace[118] || trace[117:110]!==8'h80 || trace[109:18]!==0)$fatal(1,"weak P must be unmeasured");end
  if(trace[120])swap_cases++;if(trace[122])roi1_cases++;
 end
 $display("PTRACE_DETECTOR scene=%0d diag=%032h objects=%076h candidates=%0152h wait=%0d",scenario,trace,n_region_objects,n_recorder_objects,ticks_count);checks++;
end endtask
integer a;
initial begin
 ticks(5);rst=1;ticks(5);
 for(scenario=0;scenario<12;scenario++)begin
  configure(scenario);fd=$fopen($sformatf("present_motion/detector_out/scene_%02d.pgm",scenario),"wb");if(fd==0)$fatal(1,"capture open");$fwrite(fd,"P5\n1280 720\n255\n");
  send_frame;$fclose(fd);fd=0;finish_frame;
 end
 for(a=0;a<3;a++)begin
  scenario=12+a;configure(0);fd=0;send_frame;ticks_count=0;
  while(!(a==0 ? dut.phase==dut.REF_BOX : a==1 ? dut.phase==dut.SURFACE_WAIT : dut.phase==dut.PACK_SCAN) && ticks_count<600000)begin ticks(1);ticks_count++;end
  if(ticks_count==600000)$fatal(1,"cancel phase coverage");abort_frame=1;ticks(1);abort_frame=0;ticks(20);
  if(trace!==0 || n_ready || n_located)$fatal(1,"canceled diagnostic stale");abort_checks++;
 end
 scenario=15;configure(1);fd=$fopen("present_motion/detector_out/scene_15.pgm","wb");$fwrite(fd,"P5\n1280 720\n255\n");send_frame;$fclose(fd);fd=0;finish_frame;
 scenario=16;configure(1);left_only_hot=1;fd=$fopen("present_motion/detector_out/scene_16.pgm","wb");$fwrite(fd,"P5\n1280 720\n255\n");send_frame;$fclose(fd);fd=0;finish_frame;
 if(weak_cases<1 || swap_cases<1 || roi1_cases<1 || no_p_cases<1 || abort_checks!=3)$fatal(1,"missing nonzero path coverage W%0d S%0d R%0d N%0d",weak_cases,swap_cases,roi1_cases,no_p_cases);
 $display("PASS PRESENT_TRACE_DETECTOR: %0d native frames, %0d exact public/FSM cycles, weak%0d swapped%0d ROI1%0d noP%0d, %0d cancel phases; independent gray/CCL reference pending",checks,cycles,weak_cases,swap_cases,roi1_cases,no_p_cases,abort_checks);$finish;
end
initial begin #3000000000;$fatal(1,"watchdog");end
endmodule
