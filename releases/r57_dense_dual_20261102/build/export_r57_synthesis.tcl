if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd {D:/FpgaWork/r57_build_20261102/runs/syn_1}
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_gate.db
write_verilog {D:/FpgaWork/r57_build_20261102/d3_camera_gate.v}
} reason]} {puts stderr $reason; exit 1}
exit 0
