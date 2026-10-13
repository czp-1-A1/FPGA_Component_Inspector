import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_pr.db
clear_sdc -user
read_sdc {D:/BaiduNetdiskDownload/HX1P35A_Contest_202606/FPGA_Component_Inspector/fpga/component_inspector/td_project/camera_to_dsi_display.sdc}
update_timing -mode final
report_timing_summary -file probe_constraints.timing
report_timing_exception -file probe_exceptions.timing
check_timing -file probe_coverage.txt -verbose
exit

