if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd E:/2026FPGA/.codex_tmp/r22_v3_camfix_build_r2_20261028/runs/syn_1
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_gate.db
write_verilog E:/2026FPGA/.codex_tmp/v3_camera_black_20261028/fix_r2_camera_gate.v




} reason]} {puts stderr $reason; exit 1}
exit 0
