from pathlib import Path

root = Path(__file__).resolve().parent
text = (root / 'original_tb_pre_sof_tail.v').read_text()
text = text.replace('module tb_pre_sof_tail;', 'module tb_pre_sof_four_modes;')
start = text.index('integer old_seen,old_words;')
text = text[:start] + r'''
// Preserve all four bank memories, including bytes outside the upcoming write.
reg [95:0] before0[0:W/4-1],before1[0:W/4-1];
reg [95:0] before2[0:W/4-1],before3[0:W/4-1];
integer saved_group,saved_row,boundary_early,boundary_fs;
task send_old_prefix;integer x,y;
 begin
  for(y=0;y<H/2;y=y+1) begin
   for(x=0;x<W;x=x+4) begin
    rgb={original[y*W+x],original[y*W+x+1],original[y*W+x+2],original[y*W+x+3]};
    pv=1;sof=y==0 && x==0;last=x==W-4;ticks(1);
   end
   pv=0;sof=0;last=0;
   if(y<H/2-1) ticks(512);
  end
 end
endtask
task test_stale_preamble;input integer next_mode;
 integer a,s;
 begin
  // In each actual old mode, cancel a partial frame at write_y=H/2. EDGE
  // still has a replay tail; RAW/GRAY must suppress their direct bypass.
  ready=1;start_frame(next_mode,30+next_mode);send_old_prefix;ticks(40);
  if(seen>=N || fb || dut.write_y!=H/2) $fatal(1,"preamble setup did not leave a healthy partial frame mode=%0d seen=%0d row=%0d",next_mode,seen,dut.write_y);
  checking=0;mode=2'(next_mode);pv=0;sof=0;last=0;early=1;ticks(1);
  if(ov || !oe || fb) $fatal(1,"early SOF did not cancel old output mode=%0d",next_mode);
  boundary_early=oe;boundary_fs=0;
  saved_group=dut.write_group;saved_row=dut.write_y;
  for(a=0;a<W/4;a=a+1) begin
   before0[a]=dut.line_bank[0].memory[a];before1[a]=dut.line_bank[1].memory[a];
   before2[a]=dut.line_bank[2].memory[a];before3[a]=dut.line_bank[3].memory[a];
  end
  early=0;
  // Four residual AWB valids precede the first pixel of the new frame. The
  // last marker also exercises the old row-count update path.
  for(s=0;s<4;s=s+1) begin
   pv=1;sof=0;last=(s==3);rgb=96'hdeadbe_c0ffee_123456_abcdef;ticks(1);
   boundary_early=boundary_early+oe;boundary_fs=boundary_fs+packed_sof;
   if(ov || packed_valid || fb || dut.cache_overrun || dut.input_valid || dut.input_armed)
    $fatal(1,"stale valid emitted/packed/armed/poisoned mode=%0d beat=%0d ov=%b packed=%b bad=%b",next_mode,s,ov,packed_valid,fb);
   if(dut.write_group!=saved_group || dut.write_y!=saved_row || dut.ready_rows!=0 || dut.read_y!=0 || dut.reading || pack.S_cnt!=0)
    $fatal(1,"stale valid advanced counters or replay/packer state mode=%0d beat=%0d",next_mode,s);
   if(cp!=0 || ec!=0 || es!=0) $fatal(1,"stale valid retained statistics mode=%0d beat=%0d",next_mode,s);
   for(a=0;a<W/4;a=a+1) begin
    if(dut.line_bank[0].memory[a]!==before0[a] || dut.line_bank[1].memory[a]!==before1[a] ||
       dut.line_bank[2].memory[a]!==before2[a] || dut.line_bank[3].memory[a]!==before3[a])
     $fatal(1,"stale valid wrote bank RAM mode=%0d beat=%0d address=%0d",next_mode,s,a);
   end
  end
  pv=0;last=0;
  repeat(20) begin
   ticks(1);
   boundary_early=boundary_early+oe;boundary_fs=boundary_fs+packed_sof;
   if(ov || packed_valid || fb) $fatal(1,"old tail leaked after stale preamble mode=%0d",next_mode);
  end
  if(boundary_early!=1 || boundary_fs!=1) $fatal(1,"early boundary duplicated/lost mode=%0d early=%0d packed_fs=%0d",next_mode,boundary_early,boundary_fs);
  $display("PASS: PRE_SOF_STALE mode=%0d old_valid_beats=4 ram_unchanged=1 counters_unchanged=1 rgb_words=0 packed_words=0 frame_bad=0 early=1 packed_fs=1",next_mode);
  // The next complete frame must accept its first SOF beat and match every
  // pixel, packed 128-bit word, coordinate and Sobel statistic.
  number=number+1;frame_view=next_mode;reference(50+next_mode);
  seen=0;words=0;early_count=boundary_early;in_line=0;strict=1;accept_bad=0;checking=1;
  send_rows(1,0,1);finish_good;
  $display("PASS: PRE_SOF_RECOVERY mode=%0d exact_pixels=%0d exact_words=%0d frame_bad=0",next_mode,N,BITS/128);
 end
endtask
initial begin
 ticks(4);rst=1;ticks(4);
 for(integer v=0;v<4;v=v+1) test_stale_preamble(v);
 $display("PASS: PRE_SOF_FOUR_MODES modes=4 stale_beats=16 ram_writes=0 old_rgb=0 old_packed=0 recovered_pixels=%0d recovered_words=%0d",4*N,4*BITS/128);
 $finish;
end
initial begin #10000000;$fatal(1,"Pre-SOF four modes watchdog");end
endmodule
'''
(root / 'tb_pre_sof_four_modes.v').write_text(text, encoding='ascii')
print('Prepared tb_pre_sof_four_modes.v from original test harness')
