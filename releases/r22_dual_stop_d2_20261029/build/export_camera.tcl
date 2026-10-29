if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd E:/2026FPGA/.codex_tmp/d2_single_stop_second_lane_build_r4_20261029/runs/syn_1
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_gate.db
write_verilog E:/2026FPGA/.codex_tmp/d2_single_stop_second_lane_build_r4_20261029/d2_camera_gate.v
} reason]} {puts stderr $reason; exit 1}
exit 0
