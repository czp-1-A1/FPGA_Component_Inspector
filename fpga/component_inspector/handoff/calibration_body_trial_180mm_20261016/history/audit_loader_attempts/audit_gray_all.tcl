if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.prj -noanalyze
import_db td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_pr.db
set src [get_regs {*continuous_processing*bridge/write_gray\[*\] *continuous_processing*bridge/read_gray\[*\]}]
set dst [get_regs {*continuous_processing*bridge/write_gray_sync1\[*\] *continuous_processing*bridge/read_gray_sync1\[*\]}]
puts "GRAY_ALL_SOURCES $src"
puts "GRAY_ALL_DESTINATIONS $dst"
report_timing_path -from $src -to $dst -ep_num 64 -path_num 2 -file audit/gray_all.timing
} reason]} {puts stderr $reason; exit 1}
exit 0
