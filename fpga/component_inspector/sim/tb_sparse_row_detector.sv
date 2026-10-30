`timescale 1ns/1ps
module tb_sparse_row_detector;
reg clk=0;always #5 clk=~clk;
reg rst=0,fs=0,sof=0,accept=0,abort_frame=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire [127:0] trace,g_trace;
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
frame_shape_search #(.SPARSE_ROW_SCAN(1),.DUAL_REGION_COUNT(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1),.PRESENT_TRACE(1)) dut(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(abort_frame),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0),.ready(n_ready),.sample_new(n_sample_new),.located(n_located),.state(n_state),.foreground_count(n_foreground_count),.box_width(n_box_width),.box_height(n_box_height),.box_x0(n_box_x0),.box_x1(n_box_x1),.box_y0(n_box_y0),.box_y1(n_box_y1),.review_required(n_review_required),.objects(n_objects),.region_objects(n_region_objects),.empty_probe(n_empty_probe),.recorder_objects(n_recorder_objects),.probe_ready(n_probe_ready), .probe_record(trace));
frame_shape_search_r24 #(.DUAL_REGION_COUNT(1),.PRESENT_TRACE(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) golden(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(abort_frame),.pixel_x(x),.pixel_y(y),.rgb(rgb),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.ready(g_ready),.sample_new(g_sample_new),.located(g_located),.state(g_state),.foreground_count(g_foreground_count),.box_width(g_box_width),.box_height(g_box_height),.box_x0(g_box_x0),.box_x1(g_box_x1),.box_y0(g_box_y0),.box_y1(g_box_y1),.review_required(g_review_required),.objects(g_objects),.region_objects(g_region_objects),.empty_probe(g_empty_probe),.recorder_objects(g_recorder_objects),.probe_ready(g_probe_ready),.probe_record(g_trace));

integer rows=0,scene,px,py,l,v,waited,new_cycles;integer baseline_cycles[0:5];
function automatic integer image(input integer xx,yy);
integer k,ax,ay;begin image=scene==3 ? 220 : 30;
if(scene==3 && ((yy>=286 && yy<362)||(yy>=446 && yy<522)))image=30;
for(k=0;k<10;k=k+1)begin
 ax=xx-(412+k*46);ay=yy-298;
 if(rows!=2 && ax>=0 && ax<36 && ay>=0 && ay<44 && !((ax<4 || ax>=32)&&(ay<8 || ay>=36)))image=scene==4 ? 88 : 180;
 ay=yy-458;
 if(rows!=1 && ax>=0 && ax<36 && ay>=0 && ay<44 && !((ax<4 || ax>=32)&&(ay<8 || ay>=36)))image=scene==4 ? 88 : 180;
end
if(scene==5)image=30;
end endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
initial begin
 ticks(8);rst=1;ticks(4);
 for(scene=0;scene<6;scene=scene+1)begin
 rows=scene==0?1:scene==1?2:0;
 fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py=py+1)begin
 for(px=0;px<1280;px=px+4)begin
 x=px;y=py;sof=px==0 && py==0;accept=1;
 for(l=0;l<4;l=l+1)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
 ticks(1);accept=0;sof=0;
 end ticks(2);end
 waited=0;new_cycles=0;while((!n_ready || !g_ready) && waited<1000000)begin ticks(1);waited=waited+1;if(!n_ready)new_cycles=new_cycles+1;end
 if(!n_ready || !g_ready)$fatal(1,"dense analysis unfinished");
 if({n_located,n_state,n_foreground_count,n_box_width,n_box_height,n_box_x0,n_box_x1,n_box_y0,n_box_y1,n_review_required,n_objects,n_region_objects,n_empty_probe,n_recorder_objects,trace}!=={g_located,g_state,g_foreground_count,g_box_width,g_box_height,g_box_x0,g_box_x1,g_box_y0,g_box_y1,g_review_required,g_objects,g_region_objects,g_empty_probe,g_recorder_objects,g_trace})$fatal(1,"baseline dense golden mismatch");
 baseline_cycles[scene]=waited;
 $display("SPARSE_BUDGET scene=%0d rows=%0d old_cycles=%0d new_cycles=%0d objects=%h",scene,rows==0?2:1,waited,new_cycles,n_region_objects);if(new_cycles>=waited)$fatal(1,"no speedup");if(scene==2 && new_cycles>=125000)$fatal(1,"dense dual must fit 1.25ms budget");ticks(5);
 end
 $display("PASS SPARSE_ROW_DETECTOR: dense budget measurement upper=%0d lower=%0d both=%0d",baseline_cycles[0],baseline_cycles[1],baseline_cycles[2]);$finish;
end
initial begin #100000000;$fatal(1,"watchdog");end
endmodule
