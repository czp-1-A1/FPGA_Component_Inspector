`timescale 1ns/1ps
// Independent transport regression: actual four-mode view, packer and both
// generated asynchronous FIFOs. MC/DDR below models ordered commands and
// programmable return latency, not DDR PHY/electrical behavior.
module tb_transport_faults;
localparam W=1024,H=8,PIXELS=W*H,WORDS=PIXELS*3/16;
reg cam=0,ddr=0,dsi=0,cam_run=1,rst_n=0;
always begin #4.444;if(cam_run) cam=~cam; else cam=0;end
always #7.5 ddr=~ddr;
always #9.615 dsi=~dsi;
reg pv=0,sof=0,last=0,early=0,frame_good=0;
reg [95:0] rgb=0;
integer test_mode=2,expected_lost=0,expected_underflow=0,capture_id=0,capture_words=0,write_words=0,view_pixels=0;
reg [1:0] mode=0;
wire ov,ol,oe,frame_bad,credit,ps,pvalid;
wire [95:0] view_rgb;
wire [127:0] pdata;
wire [10:0] view_x;
wire [9:0] view_y;
wire [12:0] core_pixels,edge_count;
wire [23:0] edge_sum;
roi_sobel_view #(.WIDTH(W),.HEIGHT(H)) view(
 .clk(cam),.rst_n(rst_n),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),
 .early_sof(early),.rgb(rgb),.mode(mode),.invalidate(1'b0),.view_ready(credit),
 .frame_bad(frame_bad),.out_valid(ov),.out_last(ol),.out_early_sof(oe),
 .out_rgb(view_rgb),.out_x(view_x),.out_y(view_y),.core_pixels(core_pixels),
 .edge_count(edge_count),.edge_sum(edge_sum));
data_96bit_to_128bit pack(cam,rst_n,oe,ov,view_rgb,ps,pvalid,pdata);
wire wrbusy,rdbusy,wren,rden,completed_valid,active_valid,capture_ok,display_ok;
wire [1:0] completed_rp,active_rp;
wire [24:0] wraddr,rdaddr;
wire [127:0] wrdata;
wire [15:0] lost,overflow,underflow;
reg ready=1,rdvalid=0,vsync=0,rd_en=0;
reg [127:0] rddata=0;
wire [23:0] display_pixel;
video_in #(.WIDTH(W),.HEIGHT(H)) vi(
 .I_rst_n(rst_n),.I_camera_clk(cam),.I_camera_frame_start(ps),
 .I_camera_valid(pvalid),.I_camera_data(pdata),.I_mipi_rx_error(1'b0),
 .I_frame_good(frame_good),.I_frame_bad(frame_bad),.O_camera_ready(credit),
 .I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(rdbusy),
 .I_active_valid(active_valid),.I_active_rp(active_rp),.O_video_in_wr_busy(wrbusy),
 .O_video_out_rp(),.O_completed_valid(completed_valid),.O_completed_rp(completed_rp),
 .O_capture_ok(capture_ok),.O_lost_frames(lost),.O_overflow_frames(overflow),
 .O_ddr_user_wr_en(wren),.O_ddr_user_addr(wraddr),.O_ddr_user_wr_data(wrdata),
 .I_ddr_user_ready(ready));
video_out #(.WIDTH(W),.HEIGHT(H)) vo(
 .I_rst_n(rst_n),.I_ddr_clk(ddr),.O_video_out_rd_busy(rdbusy),
 .I_video_in_wr_busy(wrbusy),.I_video_out_rp(completed_rp),
 .I_completed_valid(completed_valid),.I_completed_rp(completed_rp),
 .O_active_valid(active_valid),.O_active_rp(active_rp),
 .O_ddr_user_rd_en(rden),.O_ddr_user_addr(rdaddr),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(rdvalid),.I_ddr_user_rd_data(rddata),
 .I_dsi_clk(dsi),.I_video_vsync(vsync),.I_video_rd_en(rd_en),
 .O_vdieo_data(display_pixel),.O_display_ok(display_ok),.O_underflow_frames(underflow));
reg [23:0] reference_pixels[0:PIXELS*2-1];
reg [127:0] reference_words[0:WORDS*2-1];
reg [127:0] memory[0:WORDS*4-1];
reg [127:0] response_data[0:2047];
integer response_due[0:2047];
integer qhead=0,qtail=0,ddr_cycle=0,total_writes=0,total_reads=0;
integer return_latency=40,return_pause=0,stall_left=0,stall_started=0;
reg stall_arm=0;
integer slot_base=-1,cam_peak=0,display_peak=0,read_reserved_peak=0;
integer view_errors=0,pack_errors=0,write_errors=0,address_errors=0,pixel_errors=0;
integer display_id=0,display_index=-1,checked_pixels=0;
integer previous_display_index=-1,previous_display_id=0;
reg previous_en=0,check_pixels=0,previous_check=0,fault_display=0;
integer black_pixels=0;
integer lane,j,index,decoded_slot,decoded_word;
function integer address_slot;
 input [24:0] addr;
 begin if(addr>=21000000) address_slot=3;
 else if(addr>=14000000) address_slot=2;
 else if(addr>=7000000) address_slot=1;
 else address_slot=0;end
endfunction
function integer slot_address;
 input integer slot;
 begin case(slot) 0:slot_address=0;1:slot_address=7000000;2:slot_address=14000000;default:slot_address=21000000;endcase end
endfunction
function [23:0] raw_color;
 input integer x,y,fid;
 reg [7:0] r,g,b;
 begin r=x*3+y*5+fid*17;g=x*7+y*11+fid*31;b=x*13+y*17+fid*47;
 raw_color={r,g,b};end
endfunction
always @(posedge cam) if(rst_n) begin
 if(ov) begin
  if(view_x!==view_pixels%W || view_y!==view_pixels/W) begin
   if(view_errors<3) $display("VIEW_COORD_ERROR id=%0d px=%0d xy=%0d,%0d",capture_id,view_pixels,view_x,view_y);
   view_errors=view_errors+1;
  end
  for(lane=0;lane<4;lane=lane+1) begin
   index=(capture_id-1)*PIXELS+view_pixels+lane;
   if(view_rgb[95-lane*24-:24]!==reference_pixels[index]) begin
    if(view_errors<3) $display("VIEW_DATA_ERROR id=%0d px=%0d got=%h expected=%h",capture_id,view_pixels+lane,view_rgb[95-lane*24-:24],reference_pixels[index]);
    view_errors=view_errors+1;
   end
  end
  view_pixels=view_pixels+4;
 end
 if(pvalid) begin
  if(capture_words>=WORDS || pdata!==reference_words[(capture_id-1)*WORDS+capture_words]) begin
   if(pack_errors<3) $display("PACK_ERROR id=%0d word=%0d got=%h expected=%h",capture_id,capture_words,pdata,reference_words[(capture_id-1)*WORDS+capture_words]);
   pack_errors=pack_errors+1;
  end
  capture_words=capture_words+1;
 end
 if(vi.camera_used>cam_peak) cam_peak=vi.camera_used;
end
always @(posedge ddr) if(rst_n) begin
 ddr_cycle=ddr_cycle+1;
 if(wren && rden) $fatal(1,"SHARED MC read and write overlap at %0t",$time);
 if(wren) begin
  decoded_slot=address_slot(wraddr);decoded_word=(wraddr-slot_address(decoded_slot))/8;
  if(slot_base<0) slot_base=decoded_slot;
  if(decoded_slot!=slot_base || decoded_word!=write_words || wraddr%8!=0 || decoded_word>=WORDS) begin
   if(address_errors<3) $display("WRITE_ADDRESS_ERROR id=%0d word=%0d slot=%0d addr=%0d",capture_id,write_words,decoded_slot,wraddr);
   address_errors=address_errors+1;
  end
  if(wrdata!==reference_words[(capture_id-1)*WORDS+write_words]) begin
   if(write_errors<3) $display("WRITE_DATA_ERROR id=%0d word=%0d got=%h expected=%h",capture_id,write_words,wrdata,reference_words[(capture_id-1)*WORDS+write_words]);
   write_errors=write_errors+1;
  end
  if(active_valid && decoded_slot==active_rp) $fatal(1,"Writer overwrites active reader slot %0d",decoded_slot);
  if(completed_valid && decoded_slot==completed_rp) $fatal(1,"Writer overwrites latest complete slot %0d",decoded_slot);
  memory[decoded_slot*WORDS+decoded_word]=wrdata;
  write_words=write_words+1;total_writes=total_writes+1;
 end
 if(rden) begin
  decoded_slot=address_slot(rdaddr);decoded_word=(rdaddr-slot_address(decoded_slot))/8;
  if(!active_valid || decoded_slot!=active_rp || decoded_word>=WORDS || rdaddr%8!=0) $fatal(1,"Invalid read address %0d",rdaddr);
  if(qtail-qhead>=2047) $fatal(1,"MC response model queue exceeded");
  response_data[qtail%2048]=memory[decoded_slot*WORDS+decoded_word];
  response_due[qtail%2048]=ddr_cycle+return_latency;
  qtail=qtail+1;total_reads=total_reads+1;
 end
 if(vo.S_fifo_wr_num>display_peak) display_peak=vo.S_fifo_wr_num;
 if(vo.reserved>read_reserved_peak) read_reserved_peak=vo.reserved;
 if(vo.reserved>511) $fatal(1,"FIFO outstanding reservation exceeds capacity %0d",vo.reserved);
end
// Return and ready signals are stable before the accepting MC clock edge.
always @(negedge ddr) if(rst_n) begin
 rdvalid=0;
 if(return_pause>0) return_pause=return_pause-1;
 else if(qhead<qtail && response_due[qhead%2048]<=ddr_cycle) begin
  rddata=response_data[qhead%2048];rdvalid=1;qhead=qhead+1;
 end
 if(stall_arm && !stall_started && capture_words>=WORDS-576 && vo.S_ddr_rd_valid) begin
  stall_left=300;stall_started=1;
  $display("READY_STALL_START mode=%0d produced=%0d used=%0d read_left=%0d at %0t",test_mode,capture_words,vi.camera_used,vo.burst_left,$time);
 end
 if(stall_left>0) begin ready=0;stall_left=stall_left-1;end
 else ready=1;
end
reg display_bad_before=0;
always @(posedge dsi) begin
 display_bad_before=vo.display_bad;
 #1;
 if(previous_en && previous_check) begin
  if(fault_display && display_bad_before) begin
   if(display_pixel!==0) $fatal(1,"Shifted/corrupt pixel displayed after underflow");
   black_pixels=black_pixels+1;
  end else if(display_pixel!==reference_pixels[(previous_display_id-1)*PIXELS+previous_display_index]) begin
   if(pixel_errors<8) $display("DISPLAY_PIXEL_ERROR mode=%0d id=%0d xy=%0d,%0d got=%h expected=%h at %0t",test_mode,previous_display_id,previous_display_index%W,previous_display_index/W,display_pixel,reference_pixels[(previous_display_id-1)*PIXELS+previous_display_index],$time);
   pixel_errors=pixel_errors+1;
  end
  checked_pixels=checked_pixels+1;
 end
 previous_en=rd_en;previous_display_index=display_index;
 previous_display_id=display_id;previous_check=check_pixels;
end
task cam_ticks;input integer n;begin repeat(n) @(negedge cam);end endtask
task dsi_ticks;input integer n;begin repeat(n) @(negedge dsi);end endtask
task capture_frame;input integer fid;
 integer x,y,n,watch;
 begin
  frame_good=0;stall_arm=0;
  @(negedge cam);early=1;cam_ticks(1);early=0;cam_ticks(55);
  capture_id=fid;capture_words=0;write_words=0;view_pixels=0;slot_base=-1;
  for(y=0;y<H;y=y+1) begin
   for(x=0;x<W;x=x+4) begin
    for(n=0;n<4;n=n+1) rgb[95-n*24-:24]=raw_color(x+n,y,fid);
    pv=1;sof=(y==0 && x==0);last=(x==W-4);cam_ticks(1);
   end
   pv=0;sof=0;last=0;
   if(y==H-1) frame_good=1;
   cam_ticks(512);
  end
  watch=0;
  while((write_words<WORDS || !vi.published || completed_rp!=slot_base) && watch<20000) begin cam_ticks(1);watch=watch+1;end
  cam_ticks(10);
  $display("CAPTURE mode=%0d id=%0d pixels=%0d packed=%0d writes=%0d slot=%0d published=%0d capture_ok=%0d peak=%0d bad=%0d overflow=%0d lost=%0d",test_mode,fid,view_pixels,capture_words,write_words,slot_base,completed_rp,capture_ok,cam_peak,frame_bad,overflow,lost);
  if(!capture_ok || !completed_valid || completed_rp!=slot_base || capture_words!=WORDS || write_words!=WORDS || view_pixels!=PIXELS || frame_bad || overflow!=0 || lost!=expected_lost)
   $fatal(1,"Complete frame capture/publication failed mode=%0d id=%0d",test_mode,fid);
 end
endtask
task display_frame;input integer fid;
 integer x,y,start_checks,watch;
 begin
  start_checks=checked_pixels;display_id=fid;display_index=-1;check_pixels=0;
  @(negedge dsi);vsync=1;dsi_ticks(8);vsync=0;
  dsi_ticks(4096);
  check_pixels=1;
  for(y=0;y<H;y=y+1) begin
   for(x=0;x<W;x=x+1) begin
    rd_en=1;display_index=y*W+x;dsi_ticks(1);
   end
   rd_en=0;dsi_ticks(256);
  end
  dsi_ticks(4);check_pixels=0;
  $display("DISPLAY mode=%0d id=%0d checked=%0d display_ok=%0d underflow=%0d pixel_errors=%0d issued=%0d reserved_peak=%0d",test_mode,fid,checked_pixels-start_checks,display_ok,underflow,pixel_errors,vo.issued,read_reserved_peak);
  if(checked_pixels-start_checks!=PIXELS || !display_ok || underflow!=expected_underflow || pixel_errors!=0 || vo.issued!=WORDS)
   $fatal(1,"Full display frame failed mode=%0d id=%0d",test_mode,fid);
 end
endtask

task capture_abort;input integer fid;
 integer x,y,n,keep_slot;
 begin
  keep_slot=completed_rp;frame_good=0;stall_arm=0;
  @(negedge cam);early=1;cam_ticks(1);early=0;cam_ticks(55);
  capture_id=fid;capture_words=0;write_words=0;view_pixels=0;slot_base=-1;
  for(y=0;y<H;y=y+1) begin
   for(x=0;x<W;x=x+4) begin
    for(n=0;n<4;n=n+1) rgb[95-n*24-:24]=raw_color(x+n,y,fid);
    pv=1;sof=(y==0 && x==0);last=(x==W-4);cam_ticks(1);
   end
   pv=0;sof=0;last=0;
   if(y==H-1) begin frame_good=1;cam_ticks(40);end
   else cam_ticks(512);
  end
  cam_run=0;#50000;
  $display("STOP_CSI pixels=%0d words=%0d written=%0d retained_slot=%0d candidate_slot=%0d published=%0d",view_pixels,capture_words,write_words,completed_rp,slot_base,vi.published);
  if(capture_words>=WORDS || write_words>=WORDS || completed_rp!=keep_slot || vi.published)
   $fatal(1,"Stopped CSI published an incomplete tail");
 end
endtask
task capture_overrun;input integer fid;
 integer x,y,n,keep_slot;
 begin
  keep_slot=completed_rp;frame_good=0;stall_arm=0;stall_left=10000;
  @(negedge cam);early=1;cam_ticks(1);early=0;cam_ticks(55);
  capture_id=fid;capture_words=0;write_words=0;view_pixels=0;slot_base=-1;
  for(y=0;y<H;y=y+1) begin
   for(x=0;x<W;x=x+4) begin
    for(n=0;n<4;n=n+1) rgb[95-n*24-:24]=raw_color(x+n,y,fid);
    pv=1;sof=(y==0 && x==0);last=(x==W-4);cam_ticks(1);
   end
   pv=0;sof=0;last=0;
   if(y==H-1) frame_good=1;
   cam_ticks(512);
  end
  wait(stall_left==0);cam_ticks(1000);
  $display("CACHE_OVERRUN produced=%0d written=%0d bad=%0d camera_bad=%0d ok=%0d retained_slot=%0d peak=%0d",capture_words,write_words,frame_bad,vi.camera_bad,capture_ok,completed_rp,cam_peak);
  if(!frame_bad || !vi.camera_bad || capture_ok || vi.published || completed_rp!=keep_slot || overflow)
   $fatal(1,"Unbounded DDR pause was not safely rejected");
 end
endtask
task starve_and_cross_vs;
 integer x,y,keep_slot,old_queue_tail;
 begin
  keep_slot=active_rp;display_id=2;display_index=-1;fault_display=1;check_pixels=0;
  @(negedge dsi);vsync=1;dsi_ticks(8);vsync=0;dsi_ticks(4096);
  check_pixels=1;
  for(y=0;y<4;y=y+1) begin
   for(x=0;x<W;x=x+1) begin
    rd_en=1;display_index=y*W+x;
    if(display_index==1500) return_pause=8000;
    dsi_ticks(1);
   end
   rd_en=0;dsi_ticks(256);
  end
  dsi_ticks(4);check_pixels=0;fault_display=0;
  $display("UNDERFLOW remainder_black=%0d underflow=%0d ok=%0d outstanding=%0d pending_model=%0d pause_remaining=%0d",black_pixels,underflow,display_ok,vo.outstanding,qtail-qhead,return_pause);
  if(underflow!=1 || display_ok || black_pixels==0 || vo.outstanding==0 || return_pause==0)
   $fatal(1,"Long return pause did not produce controlled frame cancellation");
  expected_underflow=1;old_queue_tail=qtail;
  @(negedge dsi);vsync=1;dsi_ticks(8);vsync=0;
  repeat(40) @(negedge ddr);
  if(vo.state!=0 || vo.outstanding==0 || vo.S_fifo_rst || active_rp!=keep_slot)
   $fatal(1,"Reader reset/switched before old responses drained");
  $display("CROSS_VS_DRAIN preserved_slot=%0d outstanding=%0d fifo_reset=%0d",active_rp,vo.outstanding,vo.S_fifo_rst);
  wait(qhead>=old_queue_tail);wait(vo.state!=0);
  if(vo.outstanding!=0 || vo.state!=1) $fatal(1,"Old responses not fully drained before CLEAR");
  $display("CROSS_VS_CLEAR old_queue_tail=%0d returned=%0d outstanding=%0d",old_queue_tail,qhead,vo.outstanding);
 end
endtask
integer refid,refx,refy,word,b,bi,pi,byte_lane;
reg [23:0] c;
initial begin
 mode=2;
 for(refid=1;refid<=2;refid=refid+1) begin
  for(refy=0;refy<H;refy=refy+1)
   for(refx=0;refx<W;refx=refx+1)
    reference_pixels[(refid-1)*PIXELS+refy*W+refx]=raw_color(refx,refy,refid);
  for(word=0;word<WORDS;word=word+1) begin
   reference_words[(refid-1)*WORDS+word]=0;
   for(b=0;b<16;b=b+1) begin
    bi=word*16+b;pi=bi/3;byte_lane=bi%3;
    c=reference_pixels[(refid-1)*PIXELS+pi];
    reference_words[(refid-1)*WORDS+word][127-b*8-:8]=c[23-byte_lane*8-:8];
   end
  end
 end
 cam_ticks(8);rst_n=1;cam_ticks(20);
 capture_frame(1);display_frame(1);
 capture_abort(2);
 early=1;cam_run=1;expected_lost=1;capture_frame(2);
 display_frame(2);
 starve_and_cross_vs();
 display_frame(2);
 capture_overrun(1);expected_lost=2;capture_frame(1);display_frame(1);
 if(view_errors || pack_errors || write_errors || address_errors || pixel_errors || overflow)
  $fatal(1,"Fault recovery reference mismatch");
 $display("PASS: TRANSPORT_FAULTS stopped_CSI_tail_not_published=1 new_FS_recovered=1 lost_frames=%0d underflow_frames=%0d remainder_black=%0d across_VS_drain=1 cache_overrun_rejected=1 new_good_recovered=1 word_pixel_errors=0",lost,underflow,black_pixels);
 $finish;
end
initial begin #10000000;$fatal(1,"Fault regression timeout");end
endmodule
