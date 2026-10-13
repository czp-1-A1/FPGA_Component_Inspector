`timescale 1ns/1ps
// Actual native RAW10 -> bridge -> ISP + actual 20ms controls/mailbox.
// Default: native line period 738 cycles, 200 CSI tail clocks, then stop CSI
// while DDR keeps running. Require 153600 view beats and all 115200 DDR words.
// Prefixes check epoch reset only; they must never assert full frame_good.
module tb_isp_writer_stop;
reg clk=0,sys=0,run_clk=1,rst=0,fs=0,fe=0,hs=0,rv=0;
reg [39:0] raw={4{10'd400}};reg [1:0] switches=0;
reg cfg=1;reg [1:0] lane=0;reg credit=1;integer fault_kind=0;
always #5 if(run_clk)clk=~clk;
always #10 sys=~sys;
wire [17:0] request,receive;
observation_controls controls(sys,rst,switches,request);
status_cdc #(.WIDTH(18)) mailbox(sys,clk,rst,request,receive);
wire av,aso,al;wire [39:0] ad;
uial2axis #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.INPUT_DATA_WIDTH(40)) bridge(clk,rst,raw,rv,fs,fe,av,ad,aso,al);
wire [127:0] pd;wire pv,ps,pl,ir,good,bad,sv;wire [7:0] mean,mn,mx;wire [1:0] state;
wire [82:0] record;wire [27:0] display_record;
wire [35:0] diagnostics;wire row_credit;reg active=0;
isp_top dut(.axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(al),.I_tuser(aso),
 .I_tdata(ad),.I_tvalid(av),.I_tdest(10'd0),.O_tready(1'b1),.I_tready(ir),
 .O_tdata(pd),.O_tvalid(pv),.O_tuser(ps),.O_tlast(pl),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.lane_error(lane),.config_ok(cfg),
 .view_ready(row_credit),.video_frame_good(good),.video_frame_bad(bad),.video_diagnostics(diagnostics),.observation_request(receive),
 .observation_record(record),.calibration_ok(1'b0),.present_high(1'b1),.threshold(8'd80),
 .class_state(state),.sample_valid(sv),.sample_mean(mean),.sample_min(mn),.sample_max(mx),.display_record(display_record));
reg ddr=0; always #7.5 ddr=~ddr;
wire completed,capture_ok,wren; wire [1:0] completed_rp; wire [15:0] lost,overflow;
wire [24:0] wraddr;wire [127:0] wrdata;
video_in vi(.I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(ps),.I_camera_valid(pv),
 .I_camera_data(pd),.I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(row_credit),
 .I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_video_in_wr_busy(),.O_video_out_rp(),.O_completed_valid(completed),.O_completed_rp(completed_rp),
 .O_capture_ok(capture_ok),.O_lost_frames(lost),.O_overflow_frames(overflow),
 .O_ddr_user_wr_en(wren),.O_ddr_user_addr(wraddr),.O_ddr_user_wr_data(wrdata),.I_ddr_user_ready(1'b1));
integer selected_mode=2;initial if($value$plusargs("MODE=%d",selected_mode))begin end
integer native_tail=200,between_clocks=900,between_stop=1;integer packed_count=0,written_count=0;
initial begin
 if($value$plusargs("TAIL=%d",native_tail))begin end
 if($value$plusargs("BETWEEN=%d",between_clocks))begin end
 if($value$plusargs("STOP=%d",between_stop))begin end
end
always @(posedge clk) if(active && pv)packed_count=packed_count+1;
always @(posedge ddr) if(active && wren)written_count=written_count+1;
integer line_gap=98; initial if($value$plusargs("GAP=%d",line_gap))begin end
integer cycle=0,frame_no=0,early_cycle=-1,pixel_cycle=-1,invalid_after_early=0,bad_after_early=0;
integer awb_beats=0,view_beats=0,pixels_sofs=0,request_updates=0,csv;
reg resume_immediate=0;reg [17:0] receive_d=0;reg bad_d=0,guard_bad_d=0;reg [17:0] captured_tag=0;
reg sampled_early;reg [35:0] old_diagnostic;integer diagnostic_latches=0;
reg previous_av=0;integer reference_start=-1,reference_period_min=65535;
integer fe_cycle=-1,awb_cycle=-1,view_cycle=-1,pack_cycle=-1,good_cycle=-1;reg good_d=0;
always @(posedge clk)begin
 if(fe)fe_cycle=cycle;
 if(active && dut.awb_O_tvalid && awb_beats>=153599)awb_cycle=cycle;
 if(active && dut.view_valid && view_beats>=153599)view_cycle=cycle;
 if(active && pv && packed_count>=115199)pack_cycle=cycle;
 if(good && !good_d)good_cycle=cycle;good_d=good;
end
task ticks;input integer n;begin repeat(n)@(negedge clk);#1;end endtask
always @(posedge clk) begin
 cycle=cycle+1;
 sampled_early=dut.awb_O_tuser;
 old_diagnostic={dut.video_reject_reason,dut.view_timing};
 if(receive!=receive_d) begin request_updates=request_updates+1;
  $fdisplay(csv,"request_delivery,%0d,%0d,%0d,%0d,%b,%b,%b,%b",frame_no,cycle,request,receive,fs,dut.observation_match,dut.u_roi_guard.bad,bad);
 end
 receive_d=receive;
 if(active) begin
  if(dut.awb_O_tvalid && !previous_av) begin
   if(reference_start>=0 && cycle-reference_start<reference_period_min)reference_period_min=cycle-reference_start;
   reference_start=cycle;
  end
  previous_av=dut.awb_O_tvalid;
  if(dut.awb_O_tuser)early_cycle=cycle;
  if(dut.awb_pixel_sof)begin pixel_cycle=cycle;pixels_sofs=pixels_sofs+1;end
  if(dut.awb_O_tvalid)awb_beats=awb_beats+1;
  if(dut.view_valid)view_beats=view_beats+1;
  if(early_cycle>=0 && cycle>early_cycle+2) begin
   if(dut.roi_invalidate)invalid_after_early=invalid_after_early+1;
   if(bad)bad_after_early=bad_after_early+1;
  end
  if(fs || dut.awb_O_tuser || dut.awb_pixel_sof || bad!=bad_d || dut.u_roi_guard.bad!=guard_bad_d)
   $fdisplay(csv,"FS_or_bad_change,%0d,%0d,%0d,%0d,%b,%b,%b,%b",frame_no,cycle,request,receive,fs,dut.observation_match,dut.u_roi_guard.bad,bad);
 end
 bad_d=bad;guard_bad_d=dut.u_roi_guard.bad;
 #1;
 if(rst && sampled_early) begin
  diagnostic_latches=diagnostic_latches+1;
  if(diagnostics!==old_diagnostic || dut.video_reject_reason!==0 || dut.view_timing!==0 || bad || good)
   $fatal(1,"diagnostics failed to latch old / clear new at actual AWB early frame=%0d",frame_no);
  $display("PASS actual diagnostic latch prefix=%0d old_reason=%h old_LP=%0d old_WS=%0d new_reason=%h new_LPWS=%h",frame_no,diagnostics[35:32],diagnostics[31:16],diagnostics[15:0],dut.video_reject_reason,dut.view_timing);
 end
end
task prefix;input integer nrows,expect_mode,expect_bad;
 begin
  active=0;rv=0;hs=0;fs=0;fe=0;
  if(resume_immediate)resume_immediate=0;else begin ticks(between_clocks);if(between_stop)begin run_clk=0;#20000000;run_clk=1;end end
  frame_no=frame_no+1;early_cycle=-1;pixel_cycle=-1;invalid_after_early=0;bad_after_early=0;
  awb_beats=0;view_beats=0;pixels_sofs=0;packed_count=0;written_count=0;active=1;
  previous_av=0;reference_start=-1;reference_period_min=65535;
  fs=1;ticks(1);captured_tag=dut.observation_tag;fs=0;ticks(25);
  for(integer y=0;y<nrows;y=y+1) begin
   hs=1;
   for(integer b=0;b<256;b=b+1) begin
    if(y==4 && b==100 && fault_kind!=0) begin
     if(fault_kind==1)cfg=0;else if(fault_kind==2)lane=1;
     ticks(3);cfg=1;lane=0;
    end
    rv=1;ticks(1);rv=0;ticks(b%4==3 ? 3 : 1);
   end
   hs=0;ticks(line_gap);
  end
  if(nrows==600) begin fe=1;ticks(1);fe=0;end
  ticks(native_tail);if(nrows==600 && between_stop)begin run_clk=0;#1000000;run_clk=1;end active=0;
  $display("WRITER_RESULT frame=%0d tail=%0d LP=%0d reason=%h AWB=%0d VIEW=%0d PACK=%0d WR=%0d camera_count=%0d written=%0d good=%b bad=%b completed=%b capture=%b lost=%0d overflow=%0d core=%0d legacy=%h observation=%h",frame_no,native_tail,dut.view_timing[31:16],dut.video_reject_reason,awb_beats,view_beats,packed_count,written_count,vi.camera_count,vi.written,good,bad,completed,capture_ok,lost,overflow,dut.edge_pixels,display_record,record);
  $display("WRITER_TAIL mode=%0d stop=%0d raw_fe=%0d AWB_last=%0d view_last=%0d pack_last=%0d frame_good=%0d count=%0d words=%0d done=%b",selected_mode,between_stop,fe_cycle,awb_cycle,view_cycle,pack_cycle,good_cycle,vi.camera_count,vi.written,vi.done_sync);
  if(nrows==600 && (packed_count!=115200 || vi.camera_count!=115200 || vi.written!=115200 || !capture_ok))
   $fatal(1,"full actual frame not published by real writer");
  $display("OBS ISP prefix=%0d rows=%0d request=%0d receive=%0d tag=%0d frame_mode=%0d early_cycle=%0d pixel_cycle=%0d AWB=%0d view=%0d guard_bad=%b video_bad=%b invalid_after_early=%0d bad_after_early=%0d good=%b",frame_no,nrows,request,receive,captured_tag,dut.u_roi_sobel_view.frame_mode,early_cycle,pixel_cycle,awb_beats,view_beats,dut.u_roi_guard.bad,bad,invalid_after_early,bad_after_early,good);
  if(dut.u_roi_sobel_view.frame_mode!=expect_mode || pixels_sofs!=1) $fatal(1,"prefix mode/marker mismatch frame=%0d",frame_no);
  if(expect_bad==0 && (dut.u_roi_guard.bad || bad || invalid_after_early || bad_after_early || dut.view_frame_bad))
   $fatal(1,"steady next-native-FS did not recover frame=%0d",frame_no);
  if(expect_bad==1 && (!dut.u_roi_guard.bad || !bad || !invalid_after_early)) $fatal(1,"post-FS request mismatch did not abort prefix=%0d",frame_no);
  if(nrows<600 && good) $fatal(1,"short prefix improperly claimed full frame_good frame=%0d",frame_no);
  if(fault_kind==1 && dut.video_reject_reason!==4'ha) $fatal(1,"config+guard reason mismatch frame=%0d reason=%h",frame_no,dut.video_reject_reason);
  if(fault_kind==2 && dut.video_reject_reason!==4'hc) $fatal(1,"lane+guard reason mismatch frame=%0d reason=%h",frame_no,dut.video_reject_reason);
  if(!credit && (dut.video_reject_reason!==4'h1 || !dut.view_frame_bad || dut.view_timing[15:0]==0)) $fatal(1,"cache/WS reason mismatch");
  if(nrows==600 && (!good || bad || awb_beats!=153600 || view_beats!=153600 || !dut.u_roi_guard.reported)) $fatal(1,"full actual frame did not prove good");
  if(nrows==600) begin
   if(dut.view_timing[31:16]!==reference_period_min) $fatal(1,"independent AWB line period disagrees with diagnostics ref=%0d actual=%0d",reference_period_min,dut.view_timing[31:16]);
   $display("PASS independent native/full AWB line period native=640+GAP measured_AWB=%0d measured_LP=%0d",reference_period_min,dut.view_timing[31:16]);
  end
 end
endtask
task switch_stopped;input integer v,settle_csi;
 begin
  rv=0;hs=0;fs=0;run_clk=0;switches=2'(v);
  #20000200;
  if(request[1:0]!=v) $fatal(1,"actual 20ms debounce did not settle");
  begin reg [17:0] stable_request;stable_request=request;#100000;
   if(request!=stable_request)$fatal(1,"held SW levels repeatedly increment epoch");
  end
  run_clk=1;
  if(settle_csi)ticks(40);else resume_immediate=1;
 end
endtask
initial begin
 csv=$fopen("measured_events.csv","w");
 $fdisplay(csv,"event,frame,cycle,source_request,received_request,raw_start,observation_match,guard_bad,video_bad");
 ticks(16);rst=1;ticks(40);
 prefix(4,0,-1);
 switch_stopped(selected_mode,1);
 prefix(600,selected_mode,0);
 prefix(4,selected_mode,0);
 if(diagnostics[35:32]!==0 || diagnostics[31:16]==0 || diagnostics[15:0]!==0 || diagnostic_latches!=3)
  $fatal(1,"complete good EDGE old diagnostics snapshot mismatch reason=%h LP=%0d WS=%0d",diagnostics[35:32],diagnostics[31:16],diagnostics[15:0]);
 $display("PASS actual ISP full epoch: native600 rows/614400 pixels, EDGE153600 RGB beats, actual frame_good/guard completion, next early snapshots clean reason0/LP/nonzero/WS0 then clears good/new epoch");
 $fclose(csv);$finish;
end
initial begin #100000000;$fatal(1,"ISP lifecycle watchdog");end
endmodule
