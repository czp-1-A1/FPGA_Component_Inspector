import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.prj -noanalyze
import_db td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_pr.db
puts "GRAY_WRITE_PRIMARY [get_regs {*continuous_processing*bridge/write_gray\[*\]}]"
puts "GRAY_READ_PRIMARY [get_regs {*continuous_processing*bridge/read_gray\[*\]}]"
puts "GRAY_WRITE_FIRST [get_regs {*continuous_processing*bridge/write_gray_sync1\[*\]}]"
puts "GRAY_READ_FIRST [get_regs {*continuous_processing*bridge/read_gray_sync1\[*\]}]"
puts "GRAY_SOURCE_BUDGET [get_regs {*continuous_processing*bridge/write_gray* *continuous_processing*bridge/read_gray*}]"
puts "GRAY_DEST_BUDGET [get_regs {*continuous_processing*bridge/write_gray_sync1* *continuous_processing*bridge/read_gray_sync1*}]"
exit
