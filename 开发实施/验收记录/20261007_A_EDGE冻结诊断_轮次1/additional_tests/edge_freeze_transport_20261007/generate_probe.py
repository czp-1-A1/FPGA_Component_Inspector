from pathlib import Path

root=Path(__file__).resolve().parent
text=(root/'base_tb_full_transport.v').read_text()
text=text.replace('module tb_full_transport;', 'module tb_edge_freeze_transport;')
text=text.replace('integer test_mode=0,capture_id=0', 'integer first_mode=0,second_mode=2,line_gap=0,compete=0,camera_gap=512;\ninteger case_failed=0,capture_pass=0,second_pass=0,recovery_pass=0,first_overrun=0;\ninteger test_mode=0,capture_id=0')
text=text.replace('reg [23:0] reference_pixels[0:PIXELS*2-1];', 'reg [23:0] reference_pixels[0:PIXELS*2-1];\nreg [23:0] second_pixels[0:PIXELS*2-1];')
text=text.replace('reg [127:0] reference_words[0:WORDS*2-1];', 'reg [127:0] reference_words[0:WORDS*2-1];\nreg [127:0] second_words[0:WORDS*2-1];')
text=text.replace('integer x,y,n,watch;\n begin\n  capture_id=fid;', 'integer x,y,n,watch,start_overflow;\n begin\n  mode=fid==1 ? first_mode : second_mode;test_mode=mode;camera_gap=fid==1 ? 512 : line_gap;\n  first_overrun=0;start_overflow=overflow;\n  capture_id=fid;')
text=text.replace('stall_arm=(fid==2);', 'stall_arm=0;')
text=text.replace('  cam_ticks(512);', '  cam_ticks(camera_gap);')
text=text.replace('while((write_words<WORDS || !vi.published || completed_rp!=slot_base) && watch<20000)', 'while(!frame_bad && !vi.camera_bad && (write_words<WORDS || !vi.published || completed_rp!=slot_base) && watch<2000)')
text=text.replace('  if(!capture_ok || !completed_valid || completed_rp!=slot_base || capture_words!=WORDS || write_words!=WORDS || view_pixels!=PIXELS || frame_bad || overflow!=0 || lost!=0)\n   $fatal(1,"Complete frame capture/publication failed mode=%0d id=%0d",test_mode,fid);', r'''
  capture_pass=capture_ok && completed_valid && completed_rp==slot_base && capture_words==WORDS && write_words==WORDS && view_pixels==PIXELS && !frame_bad && !vi.camera_bad && overflow==start_overflow;
  if(!capture_pass) case_failed=1;
  $display("CAPTURE_RESULT %s mode=%0d id=%0d gap=%0d completed_slot=%0d candidate_slot=%0d pixels=%0d words=%0d written=%0d bad=%0d camera_bad=%0d fifo_used=%0d read_y=%0d write_y=%0d credit=%0d lost=%0d overflow=%0d",capture_pass ? "PASS" : "FAIL",test_mode,fid,camera_gap,completed_rp,slot_base,view_pixels,capture_words,write_words,frame_bad,vi.camera_bad,vi.camera_used,view.read_y,view.write_y,credit,lost,overflow);
''')
text=text.replace('   $fatal(1,"Full display frame failed mode=%0d id=%0d",test_mode,fid);', '   begin case_failed=1;$display("DISPLAY_RESULT FAIL id=%0d underflow=%0d pixel_errors=%0d",fid,underflow,pixel_errors);end')
start=text.index('initial begin\n if(!$value$plusargs')
text=text[:start]+r'''
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
 $fclose(trace_file);$finish;
end
initial begin #100000000;$fatal(1,"Switch transport watchdog");end
endmodule
'''
(root/'tb_edge_freeze_transport.v').write_text(text,encoding='ascii')
print('Prepared real Sobel/packer/VI/VO/FIFO switch and gap probe')
