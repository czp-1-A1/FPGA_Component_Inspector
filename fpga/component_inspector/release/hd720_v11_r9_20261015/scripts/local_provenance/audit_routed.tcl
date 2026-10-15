if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.prj -noanalyze
import_db td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_pr.db
file mkdir audit
analyze_clock -detail
check_timing -file audit/constraint_coverage.txt -verbose
report_clock_summary -file audit/clocks.txt
report_timing_exception -ep_num 64 -path_num 1 -file audit/exceptions.timing
report_timing_summary -ep_num 20 -path_num 1 -file audit/routed_summary.timing
foreach direction {write read} {
    for {set bit 0} {$bit < 10} {incr bit} {
        set src [get_regs [format {*continuous_processing*bridge/%s_gray\[%d\]} $direction $bit]]
        set dst [get_regs [format {*continuous_processing*bridge/%s_gray_sync1\[%d\]} $direction $bit]]
        puts "GRAY_BIND $direction $bit SOURCE $src DESTINATION $dst"
        if {[llength $src] != 1 || [llength $dst] != 1} {
            error "Gray pointer bit missing or ambiguous"
        }
        report_timing_path -from $src -to $dst -ep_num 1 -path_num 1 -file [format {audit/gray_%s_%d.timing} $direction $bit]
    }
}
puts "PASS GRAY_BINDING 20 individually resolved bit pairs; inspect budgets and slacks in reports"
} reason]} {puts stderr $reason; exit 1}
exit 0
