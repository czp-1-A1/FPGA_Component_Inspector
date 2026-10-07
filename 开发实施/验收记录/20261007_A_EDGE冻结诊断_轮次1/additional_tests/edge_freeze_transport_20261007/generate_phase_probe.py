from pathlib import Path

root=Path(__file__).resolve().parent
text=(root/'tb_edge_freeze_mc.v').read_text()
text=text.replace('module tb_edge_freeze_mc;', 'module tb_edge_freeze_phase;')
text=text.replace('integer first_mode=0,', 'integer source_phase=4500;\ninteger first_mode=0,')
text=text.replace('dsi_ticks(4500);capture_frame(2);', 'dsi_ticks(source_phase);capture_frame(2);')
text=text.replace(' if(!$value$plusargs("TRACE=%s",trace_name))', ' if(!$value$plusargs("PHASE=%d",source_phase)) source_phase=4500;\n if(!$value$plusargs("TRACE=%s",trace_name))')
text=text.replace(' capture_frame(1);\n if(!capture_pass)', ' $display("SOURCE_PHASE camera start offset=%0d DSI clocks from display VS task",source_phase);\n capture_frame(1);\n if(!capture_pass)')
(root/'tb_edge_freeze_phase.v').write_text(text,encoding='ascii')
runner=(root/'run_mc.ps1').read_text()
runner=runner.replace('[int[]]$Pauses=@(0,1000,2000)', '[int[]]$Pauses=@(1400)')
runner=runner.replace('[switch]$SkipCompile)', '[int[]]$Phases=@(4517,4553,4611),[switch]$SkipCompile)')
start=runner.index(' if(!$SkipCompile) {')
stop=runner.index(' foreach($first in $FirstModes)',start)
runner=runner[:start]+''' if(!$SkipCompile) {
  & "$model/vlib.exe" phase_work *> phase_setup.log
  & "$model/vmap.exe" phase_work phase_work >> phase_setup.log 2>&1
  & "$model/vlog.exe" -work phase_work tested_rtl/roi_sobel_view.v tested_rtl/data96_128.v tested_rtl/video_in.v tested_rtl/video_out.v tested_rtl/soft_fifo_al_4057d6b76aa6.v tested_rtl/w128_d512_fifo.v tested_rtl/mc_to_user_interface.v tested_rtl/soft_fifo_al_f58e8b3e1f3d.v tested_rtl/w155_d512_fifo.v *> phase_compile.log
  if($LASTEXITCODE -ne 0){throw 'Phase RTL compile failed'}
  & "$model/vlog.exe" -sv -work phase_work tb_edge_freeze_phase.v >> phase_compile.log 2>&1
  if($LASTEXITCODE -ne 0){throw 'Phase probe compile failed'}
 }
'''+runner[stop:]
runner=runner.replace('foreach($pause in $Pauses) {', 'foreach($pause in $Pauses) {foreach($phase in $Phases) {')
runner=runner.replace('_pause_${pause}"', '_pause_${pause}_phase_${phase}"')
runner=runner.replace('mc_work.tb_edge_freeze_mc', 'phase_work.tb_edge_freeze_phase')
runner=runner.replace('"+MC_PAUSE=$pause"', '"+MC_PAUSE=$pause" "+PHASE=$phase"')
runner=runner.replace('MC_PAUSE|Fatal|', 'MC_PAUSE|SOURCE_PHASE|Fatal|')
runner=runner.replace(' }}}}', ' }}}}}')
(root/'run_phase.ps1').write_text(runner,encoding='utf-8')
print('Prepared explicit source/display phase probe')
