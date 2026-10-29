if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd E:/2026FPGA/.codex_tmp/dual_recognition_d1_build_r1_20261029/runs/syn_1
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_gate.db
write_verilog E:/2026FPGA/.codex_tmp/dual_recognition_d1_build_r1_20261029/d1_camera_gate.v
} reason]} {puts stderr $reason; exit 1}
exit 0
