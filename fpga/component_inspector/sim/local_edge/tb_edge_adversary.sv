`timescale 1ns/1ps
// Truth is fixed before execution. Literal native RGB is captured for an
// independent pixel/CCL/Sobel reference; source IDs are not invented.
module tb_edge_adversary;
reg clk=0;always #5 clk=~clk;
reg rst=0,fs=0,sof=0,accept=0,abort_frame=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire ready,old_ready;wire [607:0] records,old_records;
frame_shape_search #(.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(abort_frame),.pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.recorder_objects(records),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
frame_shape_search_r21 #(.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) reference(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(abort_frame),.pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(old_ready),.recorder_objects(old_records),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
integer scenario=0,phase_x=0,phase_y=0,ap_w=14,ap_h=12,level=160,with_body=1,with_feed=1,has_empty=1,empty_y=320,filled=0,blur=0,body_y=320;
integer px,py,l,v,fd,ticks_new,ticks_old,seen_new,seen_old,checks=0,wins=0,empty_count,present_count,review_count,old_empty;
function automatic integer ellipse(input integer xx,yy,cx,cy,w,h);
integer ax,ay;begin ax=2*(xx-(cx-w/2))+1-w;ay=2*(yy-(cy-h/2))+1-h;ellipse=ax*ax*h*h+ay*ay*w*w<=w*w*h*h;end
endfunction
function automatic integer aperture(input integer xx,yy);
begin aperture=ellipse(xx,yy,640+phase_x,empty_y+phase_y,ap_w,ap_h) ? level : 30;
 if(filled)aperture=(xx>=640+phase_x-ap_w/2 && xx<640+phase_x-ap_w/2+ap_w && yy>=empty_y+phase_y-ap_h/2 && yy<empty_y+phase_y-ap_h/2+ap_h) ? level : 30;
end endfunction
function automatic integer image(input integer xx,yy);
integer k,bx,by,total;begin
 image=30;
 if(has_empty && xx>=620 && xx<660 && yy>=empty_y-16 && yy<empty_y+16)begin
  total=0;for(k=-blur;k<=blur;k=k+1)total=total+aperture(xx+k,yy);image=total/(2*blur+1);
 end
 if(with_body)for(k=0;k<2;k=k+1)begin
  bx=xx-(k==0 ? 572 : 684);by=yy-(body_y-22);
  if(bx>=0 && bx<36 && by>=0 && by<44 && !((bx<4 || bx>=32)&&(by<8 || by>=36)))image=180;
 end
 if(with_feed)for(k=0;k<3;k=k+1)if(ellipse(xx,yy,584+k*56,360,16,14))image=180;
end endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
always @(posedge clk)if(rst && dut.phase==dut.COMPARE && dut.small_pass && dut.center_x>=620 && dut.center_x<=660)
 $display("COMP case=%0d xy=%0d,%0d wh=%0d,%0d fg=%0d circle=%0d row=%0d anchor=%0d feed=%0d rescue=%0d hint=%0d",scenario,dut.center_x,dut.center_y,dut.width_now,dut.height_now,dut.component_count,dut.circular,dut.empty_row_delta,dut.row_anchor_available,dut.sprocket_match,dut.edge_aperture_shape,dut.edge_feed_observed);
always @(posedge clk)if(rst && dut.phase==dut.REF_CHECK && dut.ref_side && dut.ref_word==2 && dut.ref_last_row && dut.state_bank[dut.ref_index]==3)
 $display("PROOF case=%0d bbox=%0d,%0d,%0d,%0d edge=%08h edge_ok=%0d role=%0d bg=%0d",scenario,dut.read_xmin,dut.read_xmax,dut.read_ymin,dut.read_ymax,dut.local_edge_strengths,dut.surface_empty_ok,dut.edge_role_ok,dut.background_reference_ok);
task frame(input integer want_empty,input integer want_present);
reg [75:0] rec;integer k;begin
 fd=$fopen($sformatf("rgb_%02d.pgm",scenario),"wb");if(fd==0)$fatal(1,"capture open");$fwrite(fd,"P5\n512 192\n255\n");
 fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py=py+1)begin
  for(px=0;px<1280;px=px+4)begin
   x=px;y=py;sof=px==0 && py==0;accept=1;
   for(l=0;l<4;l=l+1)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};if(py>=224 && py<416 && px+l>=384 && px+l<896)$fwrite(fd,"%c",8'(v));end
   ticks(1);accept=0;sof=0;
  end ticks(2);
 end
 $fclose(fd);seen_new=0;seen_old=0;ticks_new=0;ticks_old=0;
 while((!seen_new || !seen_old) && ticks_new<600000)begin
  ticks(1);if(!seen_new)ticks_new=ticks_new+1;if(!seen_old)ticks_old=ticks_old+1;
  if(ready)seen_new=1;if(old_ready)seen_old=1;
 end
 if(!ready || !old_ready)$fatal(1,"analysis deadline case%0d",scenario);
 empty_count=0;present_count=0;review_count=0;old_empty=0;
 for(k=0;k<4;k=k+1)begin
  rec=records[k*76+:76];if(rec[75] && rec[74:73]==3)empty_count++;
  if(rec[75] && rec[74:73]==2)begin present_count++;if(rec[72:69]!=0)review_count++;end
  rec=old_records[k*76+:76];if(rec[75] && rec[74:73]==3)old_empty++;
 end
 $display("RESULT case=%0d w=%0d h=%0d px=%0d py=%0d level=%0d blur=%0d body=%0d feed=%0d empty_y=%0d filled=%0d E=%0d P=%0d REVIEW=%0d OLD_E=%0d new_cycles=%0d old_cycles=%0d record=%0152h",scenario,ap_w,ap_h,phase_x,phase_y,level,blur,with_body,with_feed,empty_y,filled,empty_count,present_count,review_count,old_empty,ticks_new,ticks_old,records);
 if(empty_count!=want_empty || present_count!=want_present)$fatal(1,"fixed truth case%0d E%0d/%0d P%0d/%0d",scenario,empty_count,want_empty,present_count,want_present);
 if(empty_count>old_empty)wins++;checks++;scenario++;
end endtask
initial begin
 ticks(5);rst=1;ticks(5);
 for(integer size=0;size<3;size=size+1)begin ap_w=size==0 ? 12 : 14;ap_h=size==2 ? 10 : 12;
  for(integer p=0;p<4;p=p+1)begin phase_x=p%2;phase_y=p/2;frame(1,2);end
 end
 phase_x=0;phase_y=0;ap_w=14;ap_h=12;
 with_body=0;frame(1,0);with_body=1;
 for(integer b=1;b<=2;b=b+1)begin blur=b;frame(1,2);end blur=0;
 has_empty=0;frame(0,2);has_empty=1;
 empty_y=360;frame(0,2);empty_y=320;
 with_body=0;with_feed=0;frame(0,0);with_body=1;with_feed=1;
 filled=1;frame(0,2);filled=0;
 ap_w=20;ap_h=18;frame(0,2);
 ap_w=14;ap_h=12;level=220;frame(1,2);
 ap_w=14;ap_h=12;level=160;filled=1;
 for(integer ap=1;ap<4;ap=ap+1)begin phase_x=ap%2;phase_y=ap/2;frame(0,2);end
 filled=0;phase_x=0;phase_y=0;
 if(wins<6)$fatal(1,"no meaningful regression rescue coverage %0d",wins);
 $display("PASS LOCAL_EDGE_DETECTOR: %0d fixed native RGB scenes, %0d actual R21 misses rescued; feed/no-row-proof/solid/oversize negatives remain",checks,wins);$finish;
end
initial begin #2000000000;$fatal(1,"watchdog");end
endmodule
