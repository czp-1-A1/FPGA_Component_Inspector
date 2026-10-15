from pathlib import Path
p = Path('fpga/component_inspector/sim')
text = (p / 'tb_video_fallback_display.v').read_text(encoding='utf-8')
text = text.replace('tb_video_fallback_display', 'tb_video_late_display')
text = text.replace('.METADATA_REQUIRED(0)', '.METADATA_REQUIRED(0),.VIDEO_FIRST(1)')
text = text.replace('.I_active_rp(2\'d0)', '.I_active_rp(active_slot)')
begin = text.index('initial begin\n repeat(10)')
text = text[:begin] + '''initial begin
 repeat(10) @(negedge cclk);rst=1;
 capture(101,0);display(0);
 // A completed slot may gain its own result, but an active raster stays immutable.
 meta=101;mready=1;repeat(80)@(negedge dclk);
 if(completed_meta!==518'd101 || active_meta!=0 || active_slot!=completed_slot)
  $fatal(1,"late same-slot metadata was lost or changed an active display tuple");
 display(101);
 capture(202,0);
 if(completed_slot==active_slot || active_meta!==518'd101)
  $fatal(1,"new complete video overwrote an active pixel/result slot");
 meta=202;mready=1;repeat(80)@(negedge dclk);
 if(completed_meta!==518'd202 || active_meta!==518'd101)
  $fatal(1,"next source result changed the previous active raster");
 meta=999;repeat(80)@(negedge dclk);
 if(completed_meta!==518'd202)$fatal(1,"same epoch tuple was replaced after attachment");
 display(202);
 if(checked!=384)$fatal(1,"incomplete exact pixel verification %0d",checked);
 $display("PASS video late display: 384 exact RGB pixels, video before results, same-slot late tuples visible only at display boundary, active slot protected, one attachment per epoch");$finish;
end
initial begin #1000000;$fatal(1,"late-result display watchdog");end
endmodule
'''
(p / 'tb_video_late_display.v').write_text(text, encoding='utf-8', newline='\n')
runner = p / 'run_modelsim.ps1'
text = runner.read_text(encoding='utf-8')
entry = next(line for line in text.splitlines() if 'Name="video_fallback_display"' in line)
new = entry.replace('video_fallback_display', 'video_late_display').replace('PASS video fallback display:', 'PASS video late display:')
runner.write_text(text.replace(entry, new + '\n' + entry), encoding='utf-8', newline='\n')
print('Created independent exact-pixel late-result display fixture')
