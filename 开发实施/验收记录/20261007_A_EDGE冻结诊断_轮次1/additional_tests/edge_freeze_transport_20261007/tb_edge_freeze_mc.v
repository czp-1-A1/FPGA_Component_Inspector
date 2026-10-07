`timescale 1ns/1ps
// Independent transport regression: actual four-mode view, packer and both
// generated asynchronous FIFOs. MC/DDR below models ordered commands and
// programmable return latency, not DDR PHY/electrical behavior.
module tb_edge_freeze_mc;
localparam W=1024,H=600,PIXELS=W*H,WORDS=PIXELS*3/16;
reg cam=0,ddr=0,dsi=0,cam_run=1,rst_n=0;
always begin #4.444;if(cam_run) cam=~cam; else cam=0;end
always #7.5 ddr=~ddr;
always #9.615 dsi=~dsi;
reg pv=0,sof=0,last=0,early=0,frame_good=0;
reg [95:0] rgb=0;
integer first_mode=0,second_mode=2,line_gap=0,compete=0,camera_gap=512;
integer case_failed=0,capture_pass=0,second_pass=0,recovery_pass=0,first_overrun=0;
integer test_mode=0,capture_id=0,capture_words=0,write_words=0,view_pixels=0;
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
wire user_rdvalid;wire [127:0] user_rddata;
wire wrbusy,rdbusy,wren,rden,completed_valid,active_valid,capture_ok,display_ok;
wire [1:0] completed_rp,active_rp;
wire [24:0] wraddr,rdaddr;
wire [127:0] wrdata;
wire [15:0] lost,overflow,underflow;
wire ready;reg rdvalid=0,vsync=0,rd_en=0;
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
 .I_ddr_user_rd_valid(user_rdvalid),.I_ddr_user_rd_data(user_rddata),
 .I_dsi_clk(dsi),.I_video_vsync(vsync),.I_video_rd_en(rd_en),
 .O_vdieo_data(display_pixel),.O_display_ok(display_ok),.O_underflow_frames(underflow));

wire mc_en,mc_we;
wire [24:0] mc_addr;
wire [2:0] mc_cmd;
wire [127:0] mc_data;
reg mc_app_ready=1,mc_wdf_ready=1;
integer mc_pause_cycles=0,mc_at_words=2400,mc_remaining=0,mc_stall_started=0;
integer mc_period=0,mc_off=0,mc_peak=0,mc_writes=0,mc_reads=0;
reg [154:0] accepted_commands[0:4095];
integer command_head=0,command_tail=0,mc_slot,mc_word;
mc_to_user_interface mcif(
 .I_clk(ddr),.I_rst_n(rst_n),.I_ddr_user_wr_en(wren),.I_ddr_user_rd_en(rden),
 .I_ddr_user_addr(wren ? wraddr : rdaddr),.I_ddr_user_wr_data(wrdata),
 .O_ddr_user_ready(ready),.O_ddr_user_rd_valid(user_rdvalid),.O_ddr_user_rd_data(user_rddata),
 .O_mc_app_en(mc_en),.O_mc_app_addr(mc_addr),.O_mc_app_cmd(mc_cmd),
 .I_mc_app_rdy(mc_app_ready),.O_mc_app_wdf_wren(mc_we),.O_mc_app_wdf_data(mc_data),
 .O_mc_app_wdf_end(),.O_mc_app_wdf_mask(),.I_mc_app_wdf_rdy(mc_wdf_ready),
 .I_mc_app_rd_data(rddata),.I_mc_app_rd_data_end(rdvalid),.I_mc_app_rd_data_valid(rdvalid));
reg [23:0] reference_pixels[0:PIXELS*2-1];
reg [23:0] second_pixels[0:PIXELS*2-1];
reg [127:0] reference_words[0:WORDS*2-1];
reg [127:0] second_words[0:WORDS*2-1];
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
reg previous_en=0,check_pixels=0,previous_check=0;
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

  write_words=write_words+1;total_writes=total_writes+1;
 end
 if(rden) begin
  decoded_slot=address_slot(rdaddr);decoded_word=(rdaddr-slot_address(decoded_slot))/8;
  if(!active_valid || decoded_slot!=active_rp || decoded_word>=WORDS || rdaddr%8!=0) $fatal(1,"Invalid read address %0d",rdaddr);
  if(qtail-qhead>=2047) $fatal(1,"MC response model queue exceeded");
  total_reads=total_reads+1;
 end

 if(wren || rden) begin
  if(command_tail-command_head>=4095) $fatal(1,"Accepted command checker exceeded");
  accepted_commands[command_tail%4096]={wren,rden,wren ? wraddr : rdaddr,wrdata};
  command_tail=command_tail+1;
 end
 if(mc_en) begin
  if(command_head==command_tail) $fatal(1,"MC emitted a command never accepted at user port");
  if(mc_addr!==accepted_commands[command_head%4096][152:128] || mc_we!==accepted_commands[command_head%4096][154] || mc_cmd!==(accepted_commands[command_head%4096][153] ? 3'd1 : 3'd0))
   $fatal(1,"Real command FIFO changed command order/address/type head=%0d",command_head);
  if(mc_we && mc_data!==accepted_commands[command_head%4096][127:0]) $fatal(1,"Real command FIFO changed write data head=%0d",command_head);
  command_head=command_head+1;
  mc_slot=address_slot(mc_addr);mc_word=(mc_addr-slot_address(mc_slot))/8;
  if(mc_we) begin memory[mc_slot*WORDS+mc_word]=mc_data;mc_writes=mc_writes+1;end
  else begin
   if(qtail-qhead>=2047) $fatal(1,"MC response queue exceeded");
   response_data[qtail%2048]=memory[mc_slot*WORDS+mc_word];
   response_due[qtail%2048]=ddr_cycle+return_latency;
   qtail=qtail+1;mc_reads=mc_reads+1;
  end
 end
 if(mcif.U_w155_d512_fifo.full_flag) $fatal(1,"Real command FIFO overflowed");
 if(mcif.U_w155_d512_fifo.wrusedw>mc_peak) mc_peak=mcif.U_w155_d512_fifo.wrusedw;
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

 if(capture_id==2 && !mc_stall_started && mc_pause_cycles>0 && capture_words>=mc_at_words) begin
  mc_stall_started=1;mc_remaining=mc_pause_cycles;
  $display("MC_PAUSE_START cycles=%0d packed=%0d queue_used=%0d",mc_pause_cycles,capture_words,mcif.U_w155_d512_fifo.wrusedw);
 end
 if(mc_remaining>0) begin mc_app_ready=0;mc_wdf_ready=0;mc_remaining=mc_remaining-1;end
 else if(mc_period>0 && ddr_cycle%mc_period<mc_off) begin mc_app_ready=0;mc_wdf_ready=0;end
 else begin mc_app_ready=1;mc_wdf_ready=1;end
end
always @(posedge dsi) begin
 #1;
 if(previous_en && previous_check) begin
  if(display_pixel!==reference_pixels[(previous_display_id-1)*PIXELS+previous_display_index]) begin
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
 integer x,y,n,watch,start_overflow;
 begin
  mode=fid==1 ? first_mode : second_mode;test_mode=mode;camera_gap=fid==1 ? 512 : line_gap;
  first_overrun=0;start_overflow=overflow;
  capture_id=fid;capture_words=0;write_words=0;view_pixels=0;slot_base=-1;frame_good=0;stall_arm=0;
  @(negedge cam);early=1;cam_ticks(1);early=0;cam_ticks(55);
  for(y=0;y<H;y=y+1) begin
   for(x=0;x<W;x=x+4) begin
    for(n=0;n<4;n=n+1) rgb[95-n*24-:24]=raw_color(x+n,y,fid);
    pv=1;sof=(y==0 && x==0);last=(x==W-4);cam_ticks(1);
   end
   pv=0;sof=0;last=0;
   if(y==H-1) frame_good=1;
   cam_ticks(camera_gap);
  end
  watch=0;
  while(!frame_bad && !vi.camera_bad && (write_words<WORDS || !vi.published || completed_rp!=slot_base) && watch<2000) begin cam_ticks(1);watch=watch+1;end
  cam_ticks(10);
  $display("CAPTURE mode=%0d id=%0d pixels=%0d packed=%0d writes=%0d slot=%0d published=%0d capture_ok=%0d peak=%0d bad=%0d overflow=%0d lost=%0d",test_mode,fid,view_pixels,capture_words,write_words,slot_base,completed_rp,capture_ok,cam_peak,frame_bad,overflow,lost);

  capture_pass=capture_ok && completed_valid && completed_rp==slot_base && capture_words==WORDS && write_words==WORDS && view_pixels==PIXELS && !frame_bad && !vi.camera_bad && overflow==start_overflow;
  if(!capture_pass) case_failed=1;
  $display("CAPTURE_RESULT %s mode=%0d id=%0d gap=%0d completed_slot=%0d candidate_slot=%0d pixels=%0d words=%0d written=%0d bad=%0d camera_bad=%0d fifo_used=%0d read_y=%0d write_y=%0d credit=%0d lost=%0d overflow=%0d",capture_pass ? "PASS" : "FAIL",test_mode,fid,camera_gap,completed_rp,slot_base,view_pixels,capture_words,write_words,frame_bad,vi.camera_bad,vi.camera_used,view.read_y,view.write_y,credit,lost,overflow);

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
  if(checked_pixels-start_checks!=PIXELS || !display_ok || underflow!=0 || pixel_errors!=0 || vo.issued!=WORDS)
   begin case_failed=1;$display("DISPLAY_RESULT FAIL id=%0d underflow=%0d pixel_errors=%0d",fid,underflow,pixel_errors);end
 end
endtask

integer trace_file,trace_cycle=0,refi,keep_slot;
reg old_credit=0;
reg [2047:0] trace_name;
always @(posedge cam) if(rst_n) begin
 trace_cycle=trace_cycle+1;
 if(view.cache_overrun && !first_overrun) begin
  first_overrun=1;
  $display("FIRST_CACHE_OVERRUN cycle=%0d id=%0d mode=%0d gap=%0d write_row=%0d write_group=%0d read_row=%0d reading=%0d ready_rows=%0d view_ready=%0d camera_used=%0d rd_count=%0d wr_busy=%0d rd_busy=%0d wr_burst=%0d rd_burst=%0d packed=%0d written=%0d",trace_cycle,capture_id,mode,camera_gap,view.write_row,view.write_group,view.read_y,view.reading,view.ready_rows,credit,vi.camera_used,vi.S_fifo_rd_num,wrbusy,rdbusy,vi.burst_left,vo.burst_left,capture_words,write_words);
 end
 if(pv && last || old_credit!=credit || view.cache_overrun && !frame_bad)
  $fdisplay(trace_file,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",trace_cycle,capture_id,mode,view.write_y,view.write_group,view.read_y,view.reading,view.ready_rows,credit,vi.camera_used,vi.S_fifo_rd_num,wrbusy,rdbusy,view_pixels,capture_words,write_words,frame_bad,view.cache_overrun);
 old_credit=credit;
end
initial begin
 if(!$value$plusargs("FIRST=%d",first_mode)) first_mode=0;
 if(!$value$plusargs("SECOND=%d",second_mode)) second_mode=2;
 if(!$value$plusargs("GAP=%d",line_gap)) line_gap=0;
 if(!$value$plusargs("COMPETE=%d",compete)) compete=0;
 if(!$value$plusargs("MC_PAUSE=%d",mc_pause_cycles)) mc_pause_cycles=0;
 if(!$value$plusargs("MC_AT=%d",mc_at_words)) mc_at_words=2400;
 if(!$value$plusargs("MC_PERIOD=%d",mc_period)) mc_period=0;
 if(!$value$plusargs("MC_OFF=%d",mc_off)) mc_off=0;
 if(!$value$plusargs("TRACE=%s",trace_name)) trace_name="trace.csv";
 trace_file=$fopen(trace_name,"w");
 $fdisplay(trace_file,"cycle,frame_id,mode,input_y,input_group,read_y,reading,ready_rows,credit,camera_used,fifo_rd_used,write_busy,read_busy,view_pixels,packed_words,mc_words,frame_bad,cache_overrun");
 $readmemh($sformatf("mode_%0d_pixels.hex",first_mode),reference_pixels);
 $readmemh($sformatf("mode_%0d_words.hex",first_mode),reference_words);
 $readmemh($sformatf("mode_%0d_pixels.hex",second_mode),second_pixels);
 $readmemh($sformatf("mode_%0d_words.hex",second_mode),second_words);
 for(refi=PIXELS;refi<2*PIXELS;refi=refi+1) reference_pixels[refi]=second_pixels[refi];
 for(refi=WORDS;refi<2*WORDS;refi=refi+1) reference_words[refi]=second_words[refi];
 cam_ticks(8);rst_n=1;cam_ticks(20);
 $display("CASE first_mode=%0d second_mode=%0d active_line_beats=256 second_line_gap=%0d compete=%0d",first_mode,second_mode,line_gap,compete);
 capture_frame(1);
 if(!capture_pass) $fatal(1,"Warm complete frame did not publish");
 keep_slot=completed_rp;
 if(compete) begin
  fork
   begin dsi_ticks(4500);capture_frame(2);end
   begin display_frame(1);end
  join
 end else capture_frame(2);
 second_pass=capture_pass;
 if(!second_pass) begin
  if(completed_rp!=keep_slot) $fatal(1,"Rejected frame replaced latest good slot");
  $display("FREEZE_REPRO latest_slot_retained=%0d rejected_mode=%0d input_frames_continue=1 frame_bad=%0d camera_bad=%0d lost_before_next_fs=%0d",keep_slot,second_mode,frame_bad,vi.camera_bad,lost);
  display_frame(1);
 end else display_frame(2);
 // Toggle back on the next frame with continuous clocks and no reset. The
 // control frame uses the original 512-cycle gap to distinguish recovery
 // from a reset; each task consumes one complete next camera frame.
 capture_frame(1);recovery_pass=capture_pass;
 if(recovery_pass) display_frame(1);
 if(view_errors || pack_errors || write_errors || address_errors || pixel_errors) case_failed=1;
 if(case_failed) $display("FAIL: SWITCH_TRANSPORT first=%0d second=%0d gap=%0d compete=%0d second_capture=%0d recovery_capture=%0d view_errors=%0d pack_errors=%0d write_errors=%0d address_errors=%0d pixel_errors=%0d overflow=%0d underflow=%0d lost=%0d",first_mode,second_mode,line_gap,compete,second_pass,recovery_pass,view_errors,pack_errors,write_errors,address_errors,pixel_errors,overflow,underflow,lost);
 else $display("PASS: SWITCH_TRANSPORT first=%0d second=%0d gap=%0d compete=%0d captures=3 recovered=1 total_writes=%0d checked_pixels=%0d errors=0 overflow=%0d underflow=%0d lost=%0d",first_mode,second_mode,line_gap,compete,total_writes,checked_pixels,overflow,underflow,lost);
 $display("MC_DIAGNOSTIC real_command_fifo=1 peak=%0d accepted=%0d retired=%0d mc_writes=%0d mc_reads=%0d pause=%0d period=%0d off=%0d",mc_peak,command_tail,command_head,mc_writes,mc_reads,mc_pause_cycles,mc_period,mc_off);
 $fclose(trace_file);$finish;
end
initial begin #100000000;$fatal(1,"Switch transport watchdog");end
endmodule
