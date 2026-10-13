from pathlib import Path
root=Path(__file__).resolve().parent
text=(root/'tb_full_transport.v').read_text()
text=text.replace('module tb_full_transport;','module tb_transport_faults;').replace('W=1024,H=600,','W=1024,H=8,')
text=text.replace('integer test_mode=0,capture_id=0', 'integer test_mode=2,expected_lost=0,expected_underflow=0,capture_id=0')
text=text.replace('reg previous_en=0,check_pixels=0,previous_check=0;', 'reg previous_en=0,check_pixels=0,previous_check=0,fault_display=0;\ninteger black_pixels=0;')
text=text.replace('always @(posedge dsi) begin', 'reg display_bad_before=0;'+chr(10)+'always @(posedge dsi) begin'+chr(10)+' display_bad_before=vo.display_bad;')
text=text.replace('if(display_pixel!==reference_pixels[(previous_display_id-1)*PIXELS+previous_display_index]) begin', 'if(fault_display && display_bad_before) begin\n   if(display_pixel!==0) $fatal(1,"Shifted/corrupt pixel displayed after underflow");\n   black_pixels=black_pixels+1;\n  end else if(display_pixel!==reference_pixels[(previous_display_id-1)*PIXELS+previous_display_index]) begin')
text=text.replace('capture_id=fid;capture_words=0;write_words=0;view_pixels=0;slot_base=-1;frame_good=0;stall_arm=(fid==2);\n  @(negedge cam);early=1;cam_ticks(1);early=0;cam_ticks(55);', 'frame_good=0;stall_arm=0;\n  @(negedge cam);early=1;cam_ticks(1);early=0;cam_ticks(55);\n  capture_id=fid;capture_words=0;write_words=0;view_pixels=0;slot_base=-1;')
text=text.replace('lost!=0)', 'lost!=expected_lost)')
text=text.replace('underflow!=0 || pixel_errors!=0', 'underflow!=expected_underflow || pixel_errors!=0')
start=text.index('initial begin\n if(!$value$plusargs')
text=text[:start]+r'''
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
'''
(root/'tb_transport_faults.v').write_text(text,encoding='ascii')
