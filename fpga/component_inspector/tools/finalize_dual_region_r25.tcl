# Run from component_inspector after the normal seed2 full routed build.
# Keep the input routed DB/reports separately before applying this finalizer.
# Vendor post-route relocation/rerouting retains the source and full SDC.
if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd td_project/camera_to_dsi_display_Runs/phy_1
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_pr.db
analyze_clock -detail
update_timing -mode final
report_timing_summary -file r25_before_finalize.timing
set fd [open r25_before_finalize.timing r]
set before [read $fd]
close $fd
if {![regexp {SWNS:\s*([-0-9.]+)ns} $before -> setup]} {error "Missing routed setup result"}
if {$setup<0} {phys_opt -post_route -mode relocation -effort high}
update_timing -mode final
report_timing_summary -file r25_after_finalize.timing
set fd [open r25_after_finalize.timing r]
set after [read $fd]
close $fd
if {[string first {Confidence          : Routed} $after]<0 || [string first {Check Corner        : Both (Slow and Fast)} $after]<0} {error "Not routed in both corners"}
foreach metric {SWNS HWNS STNS HTNS} {
 if {![regexp [format {%s:\s*([-0-9.]+)ns} $metric] $after -> value] || $value<0} {error "Physical acceptance failed: $metric; no delivery bit"}
}
report_route_status -drc -file r25_route_drc.txt
drc_check -route -all -verbose
report_area -io_info -file camera_to_dsi_display_phy.area
report_timing_summary -file camera_to_dsi_display_pr.timing
report_timing_exception -file camera_to_dsi_display_exception.timing
export_db camera_to_dsi_display_pr.db
bitgen -bit camera_to_dsi_display.bit
puts "PASS R25 ROUTED FINALIZATION: original source/clocks/SDC, both corners nonnegative; CDC audit still required"
} reason]} {puts stderr $reason; exit 1}
exit 0
