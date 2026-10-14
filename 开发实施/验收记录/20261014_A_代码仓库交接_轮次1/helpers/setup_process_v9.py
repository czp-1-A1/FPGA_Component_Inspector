from pathlib import Path
r=Path.cwd();p=r/'fpga/component_inspector'
t=(r/'tmp/freeze_frame_v8.py').read_text()
t=t.replace("inputs.append(dict(path='user_source/hdl_source/frame_shape_search.v'))","inputs.append(dict(path='user_source/hdl_source/frame_shape_search.v'))\ninputs.append(dict(path='user_source/hdl_source/frame_process_bridge.v'))")
t=t.replace("t=t.replace(line,line.replace('roi_shape_search','frame_shape_search').replace('Val=\"122\"','Val=\"123\"')+'\\n'+line)","t=t.replace(line,line.replace('roi_shape_search','frame_process_bridge').replace('Val=\"122\"','Val=\"124\"')+'\\n'+line.replace('roi_shape_search','frame_shape_search').replace('Val=\"122\"','Val=\"123\"')+'\\n'+line)")
(r/'tmp/freeze_process_v9.py').write_text(t)
# Integration expectation stays complete video + independent matching results
# while CSI is stopped; enable the newly provided continuous processing port.
f=p/'sim/tb_frame_stop.v';t=f.read_text()
t=t.replace('wire sv,mready,good,bad;', 'reg procclk=0;always #5 procclk=~procclk;\nwire sv,mready,good,bad;')
t=t.replace('.I_camera_clk(clk)', '.I_camera_clk(procclk)')
t=t.replace('isp_top #(.DIRECT_DETECTION(1)', 'isp_top #(.ASYNC_PROCESSING(1),.DIRECT_DETECTION(1)')
t=t.replace('.axi4s_video_aclk(clk)', '.processing_clk(procclk),.axi4s_video_aclk(clk)')
t=t.replace('dut.local_shape_detection.detector.state)', 'dut.local_shape_detection.detector.phase)')
t=t.replace('PASS frame stop: 8 real correction/RAW10/vendor RAM frames, all four views, 2P and P+E outside old ROI, foreground background, late metadata bounded within 27-FPS source period, both records bound to DDR slot, WB zero-result fallback, mode cancellation and recovery;', 'PASS frame stop: real native LP738, CSI stopped 33ms after 200 tail clocks, RAW and GRAY+EDGE complete 115200 words and dual metadata, continuous 100MHz post-AWB, full DDR display;')
f.write_text(t)
print('Prepared frozen 215-input continuous processing build and stop regression')
