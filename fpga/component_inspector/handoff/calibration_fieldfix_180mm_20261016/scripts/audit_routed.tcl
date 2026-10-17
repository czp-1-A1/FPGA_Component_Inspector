if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd td_project/camera_to_dsi_display_Runs/phy_1
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_pr.db
file mkdir ../../../audit_v3
analyze_clock -detail
check_timing -file ../../../audit_v3/constraint_coverage.txt -verbose
report_clock_summary -file ../../../audit_v3/clocks.txt
report_timing_exception -ep_num 64 -path_num 1 -file ../../../audit_v3/exceptions.timing
report_timing_summary -ep_num 20 -path_num 1 -file ../../../audit_v3/routed_summary.timing
foreach direction {write read} {
 for {set bit 0} {$bit < 10} {incr bit} {
  set src [get_regs [format {*continuous_processing*bridge/%s_gray\[%d\]} $direction $bit]]
  set dst [get_regs [format {*continuous_processing*bridge/%s_gray_sync1\[%d\]} $direction $bit]]
  puts "GRAY_BIND $direction $bit SOURCE $src DESTINATION $dst"
  if {[llength $src] != 1 || [llength $dst] != 1 || [lindex $src 0] eq "" || [lindex $dst 0] eq ""} {error "Gray bit missing or ambiguous"}
  report_timing_path -from $src -to $dst -ep_num 1 -path_num 1 -file [format {../../../audit_v3/gray_%s_%d.timing} $direction $bit]
  report_timing_path -from $src -ep_num 64 -path_num 2 -file [format {../../../audit_v3/gray_fanout_%s_%d.timing} $direction $bit]
 }
}
puts "PASS GRAY_BINDING20 and complete source fanout reports"
} reason]} {puts stderr $reason; exit 1}
exit 0
