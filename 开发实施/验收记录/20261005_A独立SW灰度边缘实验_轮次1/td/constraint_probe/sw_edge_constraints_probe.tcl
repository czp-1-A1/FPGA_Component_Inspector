# Read-only audit of the final routed database; never exports a changed DB/bit.
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
import_db ../sw_edge_td_build_20261005/td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_pr.db
set sw_ports [get_ports -verbose {I_switch[*]}]
set first_regs [get_regs -verbose {u_observation_controls/sync1*}]
puts "SW_PORTS=$sw_ports COUNT=[llength $sw_ports]"
puts "FIRST_SYNCS=$first_regs COUNT=[llength $first_regs]"
export_sdc -file sw_edge_exported.sdc
report_nets [get_nets {I_switch*}] -connection
report_timing_path -from $sw_ports -to $first_regs -file sw_edge_sw_paths.timing
report_timing_ignored -file sw_edge_ignored.timing -ep_num 200 -path_num 1
exit
