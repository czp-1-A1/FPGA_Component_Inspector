import_device ph1_35p.db -package PH1P35MDG324 -speed 3
import_db camera_to_dsi_display_gate.db
read_sdc probe.sdc
update_timing
check_timing -file coverage_check.txt -verbose
report_timing_summary -file coverage_summary.txt
exit


