`timescale 1ns/1ps
// Diagnostic sweep of the unchanged R18 production detector. These are
// synthetic RGB stimuli, not reconstructed camera RAW or field accuracy.
module tb_context_abort;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;
always #5 clk=~clk;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire ready,old_ready,sn;wire [607:0] records,old_records;
frame_shape_search #(.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),
 .COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),
 .MULTITHRESHOLD_EMPTY(1),.SURFACE_REVIEW(1),.STANDING_REVIEW(1),.REVIEW_PROBE(0)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sn),.recorder_objects(records),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
frame_shape_search_r19 #(.ROBUST_SMALL_EMPTY(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),
 .COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),
 .MULTITHRESHOLD_EMPTY(1),.SURFACE_REVIEW(1),.STANDING_REVIEW(1),.REVIEW_PROBE(0)) reference(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(old_ready),.recorder_objects(old_records),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
integer scenario=0,phase_x=0,phase_y=0,blur_radius=0,px,py,l,v,cycles;
integer rows,baseline_empty=0,lost_cases=0,old_sum=0,new_sum=0,empty_left=636,empty_top=316,empty_size=10;
function automatic integer point(input integer xx,yy);
 integer ax,ay;
 begin
  ax=xx-(empty_left+phase_x);ay=yy-(empty_top+phase_y);
  point=(ax>=0 && ax<empty_size && ay>=0 && ay<empty_size &&
    !((ax<2 || ax>=empty_size-2) && (ay<2 || ay>=empty_size-2))) ? 110 : 30;
 end
endfunction
function automatic integer image(input integer xx,yy);
 integer sum,k,bx,by;
 begin
  image=30;
  // Limit convolution to the small target neighbourhood; identical dark
  // pixels elsewhere. Two neighbouring real bodies teach the current row.
  if(scenario!=16 && xx>=empty_left-14 && xx<empty_left+empty_size+14 && yy>=empty_top-4 && yy<empty_top+empty_size+4)begin
   sum=0;for(k=-blur_radius;k<=blur_radius;k=k+1)sum=sum+point(xx+k,yy);
   image=sum/(2*blur_radius+1);
  end
  for(k=0;k<2;k=k+1)begin
   bx=xx-(k==0 ? 572 : 684);by=yy-298;
   if(scenario!=23 && bx>=0 && bx<36 && by>=0 && by<44 &&
      !((bx<4 || bx>=32) && (by<8 || by>=36)))image=180;
  end
  if(scenario==20 && point(xx,yy)>30)image=220;
  if(scenario==21 && xx>=616 && xx<632 && yy>=312 && yy<328)image=150;
 end
endfunction
always @(posedge clk)if(rst && dut.phase==dut.REF_CHECK && dut.context_ref && dut.ref_word==2 && dut.ref_row[1:0]==3)
 $display("CONTEXT case=%0d x0=%0d x1=%0d y0=%0d y1=%0d side=%0d half=%0d dark=%0d edge=%0d upper=%0d vertical=%0d left=%0d leftedge=%0d pass=%0d",scenario,dut.context_x0,dut.context_x1,dut.context_y0,dut.context_y1,dut.ref_side,dut.ref_row[2],dut.context_sum,dut.context_edge_sum,dut.context_upper_edge_ok,dut.context_vertical_ok,dut.context_left_ok,dut.context_left_edge,dut.reference_ok);
integer input_fd;
task ticks(input integer n);repeat(n)@(negedge clk);endtask
always @(posedge clk)if(rst)begin
 if(dut.phase==dut.COMPARE && dut.small_pass && dut.center_x>=620 && dut.center_x<=660 && dut.center_y>=305 && dut.center_y<=335)
  $display("GATE case=%0d phase=%0d,%0d blur=%0d FG=%0d W=%0d H=%0d shape=%b geometry=%b raw_empty=%b high_lookup=%b bright=%0d row_delta=%0d border=%b covered=%b",scenario,phase_x,phase_y,2*blur_radius+1,dut.component_count,dut.width_now,dut.height_now,dut.circular,dut.empty_geometry,dut.empty_match,dut.high_lookup,dut.bright_count,dut.empty_row_delta,dut.border,dut.covers_body);
 if(dut.phase==dut.REF_CHECK && dut.ref_side && dut.ref_word==2 && dut.ref_last_row && dut.origin_x>=310 && dut.origin_x<=330)
  $display("DARK case=%0d kind=%0d left=%0d right=%0d min=%0d",scenario,dut.state_bank[dut.ref_index],dut.left_dark,dut.right_dark+dut.dark_word,dut.ref_min);
end
task send_pixels;
 begin
  input_fd=$fopen($sformatf("input_%02d.pgm",scenario),"wb");
  if(input_fd==0)$fatal(1,"inputcapture open failed");
  $fwrite(input_fd,"P5\n288 128\n255\n");
  fs=1;ticks(1);fs=0;ticks(3);
  for(py=0;py<720;py=py+1)begin
   for(px=0;px<1280;px=px+4)begin
    x=px;y=py;accept=1;sof=px==0 && py==0;
    for(l=0;l<4;l=l+1)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};if(py>=256 && py<384 && px+l>=512 && px+l<800)$fwrite(input_fd,"%c",8'(v));end
    ticks(1);accept=0;sof=0;
   end ticks(2);
  end
  $fclose(input_fd);
 end
endtask
task frame;
 integer empty_count,present_count,old_empty_count,want;reg [75:0] rec;
 begin
  send_pixels();
  cycles=0;while((!ready || !old_ready) && cycles<500000)begin ticks(1);cycles=cycles+1;end
  if(!ready || !old_ready)$fatal(1,"detector diagnostic deadline case%0d",scenario);
  empty_count=0;present_count=0;old_empty_count=0;
  for(integer k=0;k<4;k=k+1)begin
   rec=records[k*76+:76];
   if(rec[75] && rec[74:73]==3)empty_count=empty_count+1;
   if(old_records[k*76+75] && old_records[k*76+73+:2]==3)old_empty_count=old_empty_count+1;
   if(rec[75] && rec[74:73]==2)present_count=present_count+1;
  end
  want=scenario<12 ? 1 : 0;
  if(empty_count!=want)$fatal(1,"study truth case%0d new%0d want%0d",scenario,empty_count,want);
  old_sum=old_sum+old_empty_count;new_sum=new_sum+empty_count;
  $display("AB case=%0d old_empty=%0d new_empty=%0d expected=%0d",scenario,old_empty_count,empty_count,want);
  if(scenario<4)baseline_empty=baseline_empty+empty_count;
  else if(empty_count==0)lost_cases=lost_cases+1;
  $display("RESULT case=%0d px=%0d py=%0d blur=%0d empty=%0d present=%0d analysis_cycles=%0d records=%0152h",scenario,phase_x,phase_y,2*blur_radius+1,empty_count,present_count,cycles,records);
 end
endtask
initial begin
 ticks(5);rst=1;ticks(5);scenario=0;frame();
 for(integer j=0;j<10;j=j+1)begin
  send_pixels();cycles=0;
  while(!((j<8 && dut.phase==dut.REF_CHECK && dut.context_ref && dut.ref_side==(j/4) && dut.ref_row==((j%4)*2) && dut.ref_word==1) ||
          (j==8 && dut.phase==dut.PACK_SCAN) || (j==9 && ready)) && cycles<500000)begin ticks(1);cycles=cycles+1;end
  if(cycles==500000)$fatal(1,"cancel phase not reached %0d",j);
  cancel=1;ticks(1);cancel=0;ticks(3);
  if(ready || records!==608'd0 || sn)$fatal(1,"cancel leaked stale ready/result %0d",j);
  $display("CANCEL point=%0d phase_reached=1 cleared=1",j);
  frame();
 end
 $display("PASS CONTEXT_ABORT:10 real cancel points, stale publication suppressed, next actual RGB frame recovers");$finish;
end
initial begin #1000000000;$fatal(1,"diagnostic watchdog");end
endmodule
