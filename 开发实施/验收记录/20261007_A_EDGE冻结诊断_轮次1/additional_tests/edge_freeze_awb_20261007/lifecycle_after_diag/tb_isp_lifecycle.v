`timescale 1ns/1ps
// Actual native RAW10 -> bridge -> ISP + actual 20ms controls/mailbox.
// Short prefixes prove lifecycle only, never full 1024x600 good/publication.
module tb_isp_lifecycle;
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
wire [35:0] diagnostics;
isp_top dut(.axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(al),.I_tuser(aso),
 .I_tdata(ad),.I_tvalid(av),.I_tdest(10'd0),.O_tready(1'b1),.I_tready(ir),
 .O_tdata(pd),.O_tvalid(pv),.O_tuser(ps),.O_tlast(pl),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.lane_error(lane),.config_ok(cfg),
 .view_ready(credit),.video_frame_good(good),.video_frame_bad(bad),.video_diagnostics(diagnostics),.observation_request(receive),
 .observation_record(record),.calibration_ok(1'b0),.present_high(1'b1),.threshold(8'd80),
 .class_state(state),.sample_valid(sv),.sample_mean(mean),.sample_min(mn),.sample_max(mx),.display_record(display_record));
integer cycle=0,frame_no=0,early_cycle=-1,pixel_cycle=-1,invalid_after_early=0,bad_after_early=0;
integer awb_beats=0,view_beats=0,pixels_sofs=0,request_updates=0,csv;
reg active=0,resume_immediate=0;reg [17:0] receive_d=0;reg bad_d=0,guard_bad_d=0;reg [17:0] captured_tag=0;
reg sampled_early;reg [35:0] old_diagnostic;integer diagnostic_latches=0;
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
  if(resume_immediate)resume_immediate=0;else ticks(900);
  frame_no=frame_no+1;early_cycle=-1;pixel_cycle=-1;invalid_after_early=0;bad_after_early=0;
  awb_beats=0;view_beats=0;pixels_sofs=0;active=1;
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
   hs=0;ticks(32);
  end
  if(nrows==600) begin fe=1;ticks(1);fe=0;end
  ticks(900);active=0;
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
 csv=$fopen("isp_lifecycle_events.csv","w");
 $fdisplay(csv,"event,frame,cycle,source_request,received_request,raw_start,observation_match,guard_bad,video_bad");
 ticks(16);rst=1;ticks(40);
 prefix(4,0,-1); // Real first-line span-learning warmup; no acceptance claim.
 prefix(16,0,0);
 switch_stopped(2,0);
 // Resume reaches raw FS before request mailbox has delivered the new epoch.
 prefix(16,0,1);
 prefix(16,2,0);
 prefix(16,2,0);
 switch_stopped(1,1);prefix(16,1,0);
 switch_stopped(3,1);prefix(16,3,0);
 fault_kind=1;prefix(16,3,1);fault_kind=0;prefix(16,3,0);
 fault_kind=2;prefix(16,3,1);fault_kind=0;prefix(16,3,0);
 credit=0;prefix(16,3,-1);credit=1;prefix(16,3,0);
 if(request_updates!=3) $fatal(1,"held mode changes produced unexpected mailbox epochs count=%0d",request_updates);
 if(diagnostic_latches!=13) $fatal(1,"diagnostic epoch count mismatch count=%0d",diagnostic_latches);
 $display("PASS actual ISP lifecycle: real20ms debounce/CDC, next-nativeFS recovery, GRAY/EDGE modes, config/lane/cache faults and reason bits, every actual early locks old reason+LP+WS and clears new; prefixes do not claim frame_good");
 $fclose(csv);$finish;
end
initial begin #100000000;$fatal(1,"ISP lifecycle watchdog");end
endmodule
