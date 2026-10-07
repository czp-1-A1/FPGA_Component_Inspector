param([int]$Gap=98,[int]$Tail=900,[int]$Between=900,[int]$Stop=0,[int]$Mode=2)
$ErrorActionPreference='Stop'
$modelBin='D:/modeltech64_10.5/win64'
$tdSimRoot='D:/td6.2.1/sim_release'
$hdl="$PSScriptRoot/fpga/component_inspector/user_source/hdl_source"
$ip="$PSScriptRoot/fpga/component_inspector/user_source/ip_source"
$demosaic="$hdl/isp/demosaic_4x_2_0"
foreach($taskLicenseName in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if(![Environment]::GetEnvironmentVariable($taskLicenseName,'Process')) {
  $taskLicenseValue=[Environment]::GetEnvironmentVariable($taskLicenseName,'User')
  if(!$taskLicenseValue){$taskLicenseValue=[Environment]::GetEnvironmentVariable($taskLicenseName,'Machine')}
  if($taskLicenseValue){[Environment]::SetEnvironmentVariable($taskLicenseName,$taskLicenseValue,'Process')}
 }
}
$ispSources = @(
    "$hdl/observation_controls.v", "$hdl/status_cdc.v", "$hdl/isp/uial2axis.v", "$hdl/isp/isp_top.v", "$hdl/roi_frame_guard.v", "$hdl/roi_statistics.v", "$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_sobel_view.v", "$hdl/roi_observation_snapshot.v",
    "$hdl/awb.v", "$hdl/signal_delay.v", "$hdl/isp/data128_96/data128_96.v", "$hdl/isp/data96_128/data96_128.v",
    "$demosaic/demosaic.v", "$demosaic/raw_matrix_3x3_buffer.v", "$demosaic/zhenghe.v",
    "$demosaic/line_buffer_demosaic.v", "$demosaic/mipi_to_raw_converter.v", "$demosaic/bilinear_interpolation.v",
    "$demosaic/blk_mem_gen_demosaic/blk_mem_gen_demosaic.v", "$demosaic/blk_mem_gen_demosaic/RTL/ram_c36c2ca3b3a7.v",
    "$demosaic/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.v", "$demosaic/blk_mem_gen_zhenghe/RTL/ram_d32970204f32.v",
    "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v",
    "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v")
Push-Location $PSScriptRoot
try {
 & "$modelBin/vmap.exe" -c *> stop_setup.log
 & "$modelBin/vlib.exe" stop_work >> stop_setup.log 2>&1
 & "$modelBin/vmap.exe" stop_work stop_work >> stop_setup.log 2>&1
 & "$modelBin/vmap.exe" anlogic_sim fpga/component_inspector/sim/modelsim_work/anlogic_sim >> stop_setup.log 2>&1
 & "$modelBin/vlog.exe" -work stop_work @ispSources *> stop_compile.log
 if($LASTEXITCODE -ne 0){throw 'ISP compile failed'}
 & "$modelBin/vlog.exe" -work stop_work "$hdl/video_in.v" "$ip/w128_d512_fifo/w128_d512_fifo.v" "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v" *> stop_fifo_compile.log
 if($LASTEXITCODE -ne 0){throw 'FIFO compile failed'}
 & "$modelBin/vlog.exe" -sv -work stop_work tb_isp_writer_stop.v >> stop_compile.log 2>&1
 if($LASTEXITCODE -ne 0){throw 'TB compile failed'}
 & "$modelBin/vsim.exe" -c -L anlogic_sim '-voptargs=+acc=rn+/tb_isp_writer_stop' -onfinish exit -l "stop_m${Mode}_g${Gap}_t${Tail}_s${Stop}_transcript.log" -wlf "stop_m${Mode}_g${Gap}_t${Tail}_s${Stop}.wlf" -do 'run -all; quit -code 1 -force' stop_work.tb_isp_writer_stop anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR "+GAP=$Gap" "+TAIL=$Tail" "+BETWEEN=$Between" "+STOP=$Stop" "+MODE=$Mode" *> "stop_m${Mode}_g${Gap}_t${Tail}_s${Stop}_console.log"
 $taskExit=$LASTEXITCODE
 Get-Content -LiteralPath "stop_m${Mode}_g${Gap}_t${Tail}_s${Stop}_console.log" | Where-Object {$_ -match 'PASS|OBS|WRITER_RESULT|WRITER_TAIL|Fatal|Error|License'}
 exit $taskExit
} finally {Pop-Location}
