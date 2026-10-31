if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd {E:/2026FPGA/.codex_tmp/rl7_demo_build_r3b_20261101/runs/syn_1}
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_gate.db
write_verilog {E:/2026FPGA/.codex_tmp/rl7_demo_build_r3b_20261101/rl7_demo_camera_gate.v}
} reason]} {puts stderr $reason; exit 1}
exit 0
