# Read-only report on the existing routed DB. No SDC or implementation edits.
if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
set audit_root [pwd]
cd td_project/camera_to_dsi_display_Runs/phy_1
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_pr.db
cd $audit_root
file mkdir gray_packing_audit
set fd [open gray_packing_audit/bindings.txt w]
analyze_clock -detail
update_timing -mode final
set sources [get_regs {*continuous_processing*bridge/write_gray\[*\] *continuous_processing*bridge/read_gray\[*\]}]
set destinations [get_regs {*continuous_processing*bridge/write_gray_sync1\[*\] *continuous_processing*bridge/read_gray_sync1\[*\]}]
puts $fd "GRAY_COLLECTION SOURCES [llength $sources] DESTINATIONS [llength $destinations]"
report_timing_path -from $sources -to $destinations -ep_num 4096 -path_num 64 -file gray_packing_audit/all_selected.timing
foreach direction {write read} {
 for {set bit 0} {$bit<10} {incr bit} {
  set source [get_regs [format {*continuous_processing*bridge/%s_gray\[%d\]} $direction $bit]]
  set qnet [get_nets [format {*continuous_processing*bridge/%s_gray\[%d\]} $direction $bit]]
  set destination [get_regs [format {*continuous_processing*bridge/%s_gray_sync1\[%d\]} $direction $bit]]
  puts $fd "GRAY_Q $direction $bit SOURCE $source THROUGH $qnet DESTINATION $destination"
  if {[llength $source]!=1 || [llength $qnet]!=1 || [llength $destination]!=1} {error "Unbound exact Gray Q/net/destination"}
  report_timing_path -from $source -through $qnet -to $destination -ep_num 4096 -path_num 8 -file [format {gray_packing_audit/gray_q_%s_%d.timing} $direction $bit]
 }
}
close $fd
puts "PASS GRAY PACKING DIAGNOSTIC REPORTS ONLY: original constraints and routed DB unchanged"
} reason]} {puts stderr $reason; exit 1}
exit 0
