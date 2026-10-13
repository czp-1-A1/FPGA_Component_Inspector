from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
read=lambda p:p.read_text(encoding='utf-8-sig')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
s=read(root/'tmp/multi_black_check_r2_20261013/sim/tb_multi_video.v')
s=s.replace('.METADATA(1),.META_WIDTH(518)', '.METADATA(1),.META_WIDTH(518),.METADATA_REQUIRED(0)')
s=s.replace('integer display_rows=0,display_pixels=0,nonzero_pixels=0;',
 '''integer display_rows=0,display_pixels=0,nonzero_pixels=0;
reg display_done=0;integer accepted_frames=0,rejected_frames=0;''')
s=s.replace('PASS multi video raster: 600 rows/614400 requests, nonzero=%0d, competing DDR read/write, no underflow",nonzero_pixels);',
 'PASS multi video raster: 600 rows/614400 requests, nonzero=%0d, competing DDR read/write, no underflow",nonzero_pixels);display_done=1;')
s=s.replace('  frame_no=frame_no+1;', '  saved_meta=completed_meta;frame_no=frame_no+1;')
marker='  end else begin\n  if(!cap'
replacement='''  end else if(bad) begin
   // At ~315 input FPS against 61 Hz HDMI this fixture deliberately exceeds
   // field duty (27 FPS). Backpressure marks incomplete views as bad; the
   // last good slot must keep displaying instead of publishing partial pixels.
   if(good || cap || writer.published || completed_meta!==saved_meta)
    $fatal(1,"competing DDR stress published a bad frame");
   if(!dut.video_reject_reason[0]) $fatal(1,"unexpected fixture integrity failure %h",dut.video_reject_reason);
   rejected_frames++;
   $display("OBS competing DDR stress rejects incomplete view frame=%0d reason=%h",frame_no,dut.video_reject_reason);
  end else begin
  accepted_frames++;
  if(!cap'''
assert marker in s;s=s.replace(marker,replacement)
s=s.replace(' wait(display_rows==600);', ' wait(display_done);\n if(accepted_frames<3) $fatal(1,"insufficient complete frames under competing reader");')
start=s.index(' $display("PASS multi video:',s.index('initial begin\n ticks(8)'))
end=s.index('$finish;',start)
s=s[:start]+''' $display("PASS multi video: actual correction/RAW10/vendor RAM/518-bit metadata/DDR reader arbitration; accepted=%0d rejected=%0d; complete 614400-pixel raster, no underflow, bad view preserves previous slot",accepted_frames,rejected_frames);'''+s[end:]
(project/'sim/tb_multi_video.v').write_text(s,encoding='utf-8')
runner=read(project/'sim/run_modelsim.ps1')
marker='    $tests = @('
entry='''
        @{Name="multi_video"; Pass="PASS multi video:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_multi_video.v"))},'''
assert 'Name="multi_video"' not in runner
runner=runner.replace(marker,marker+entry,1).replace('"isp_multi", "multi_writer"','"isp_multi", "multi_writer", "multi_video"')
(project/'sim/run_modelsim.ps1').write_text(runner,encoding='utf-8-sig')
print('Prepared actual correction/writer/reader integration fixture; original r2 failure retained')
