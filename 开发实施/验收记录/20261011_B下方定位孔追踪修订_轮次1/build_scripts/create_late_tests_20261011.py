from pathlib import Path
root=Path(__file__).resolve().parent.parent
sim=root/'fpga/component_inspector/sim'
s=(sim/'tb_isp_tracking.v').read_text(encoding='utf-8')
s=s.replace('tb_isp_tracking','tb_isp_tracking_late').replace('isp_top #(.TRACKING(1))','isp_top #(.TRACKING(1),.HOLE_Y(380),.LATE_HOLE(1))')
s=s.replace('row>=204 && row<237','row>=364 && row<397')
s=s.replace('frame(12,1,1,1,1);frame(24,0,1,1,2);','frame(4,1,1,1,1);frame(8,0,1,1,2);')
s=s.replace('frame(12,0,1,1,3);','frame(4,0,1,1,3);')
s=s.replace(' $display("PASS actual ISP tracking:', ' frame(12,1,1,0,1);frame(0,1,1,0,1);frame(0,1,1,1,1);\n $display("PASS actual ISP tracking late:')
s=s.replace('same-frame moving ROI','frame-held moving ROI with current-frame lower-hole verification')
(sim/'tb_isp_tracking_late.v').write_text(s,encoding='utf-8')
s=(sim/'run_modelsim.ps1').read_text(encoding='utf-8')
s=s.replace('    $tests = @(\n','    $tests = @(\n        @{Name="tracking_late"; Pass="PASS tracking late:"; Sources=@("$hdl/tape_hole_tracker.v", "$hdl/roi_statistics.v", "tb_tracking_late.v")},\n        @{Name="tracking_status"; Pass="PASS tracking status:"; Sources=@("$hdl/tape_hole_tracker.v", "tb_tracking_status.v")},\n        @{Name="isp_tracking_late"; Pass="PASS actual ISP tracking late:"; Sources=($ispSources + @("tb_isp_tracking_late.v"))},\n',1)
s=s.replace('"isp_writer_stop", "isp_tracking"','"isp_writer_stop", "isp_tracking", "isp_tracking_late"')
(sim/'run_modelsim.ps1').write_text(s,encoding='utf-8')
