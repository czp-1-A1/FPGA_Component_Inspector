if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.prj -noanalyze
import_db td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_pr.db
foreach direction {write read} {
 for {set bit 0} {$bit < 10} {incr bit} {
  set src [get_regs [format {*continuous_processing*bridge/%s_gray\[%d\]} $direction $bit]]
  if {[llength $src] != 1} {error "Gray source missing or ambiguous"}
  report_timing_path -from $src -ep_num 64 -path_num 2 -file [format {audit/gray_fanout_%s_%d.timing} $direction $bit]
 }
}
} reason]} {puts stderr $reason; exit 1}
exit 0
