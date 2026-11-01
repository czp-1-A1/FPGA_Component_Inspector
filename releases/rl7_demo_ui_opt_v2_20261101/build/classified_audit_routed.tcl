# Run from the frozen build's component_inspector directory after PHY completion.
# Generates complete inherited coverage plus all twenty Gray-bit fanouts and
# both new held-mailbox payload/token path groups. No constraints are changed.
if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
set audit_root [pwd]
cd {E:/2026FPGA/.codex_tmp/rl7_uiopt_build_r2_20261101/runs/phy_1}
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_pr.db
cd $audit_root
file mkdir classified_audit
set bind_fd [open classified_audit/bindings.txt w]
analyze_clock -detail
update_timing -mode final
check_timing -file classified_audit/constraint_coverage.txt -verbose
report_clock_summary -file classified_audit/clocks.txt
report_timing_exception -ep_num 64 -path_num 1 -file classified_audit/exceptions.timing
report_timing_summary -ep_num 20 -path_num 1 -file classified_audit/routed_summary.timing
foreach direction {write read} {
 for {set bit 0} {$bit < 10} {incr bit} {
  set src [get_regs [format {*continuous_processing*bridge/%s_gray\[%d\]} $direction $bit]]
  set dst [get_regs [format {*continuous_processing*bridge/%s_gray_sync1\[%d\]} $direction $bit]]
  puts "GRAY_BIND $direction $bit SOURCE $src DESTINATION $dst"
  puts $bind_fd "GRAY_BIND $direction $bit SOURCE $src DESTINATION $dst"
  if {[llength $src] != 1 || [llength $dst] != 1 || [lindex $src 0] eq "" || [lindex $dst 0] eq ""} {error "Gray bit missing or ambiguous"}
  report_timing_path -from $src -to $dst -ep_num 1 -path_num 1 -file [format {classified_audit/gray_%s_%d.timing} $direction $bit]
  report_timing_path -from $src -ep_num 4096 -path_num 2 -file [format {classified_audit/gray_fanout_%s_%d.timing} $direction $bit]
 }
}
foreach box {u_count_command u_count_live_display u_relay_display} {
 foreach {from to suffix} {payload* D_data* payload req {req_sync[0]} request ack {ack_sync[0]} acknowledge} {
  set src [get_regs [format {%s/%s} $box $from]]
  set dst [get_regs [format {%s/%s} $box $to]]
  puts "COUNT_CDC_BIND $box $suffix SOURCE_COUNT [llength $src] DESTINATION_COUNT [llength $dst]"
  puts $bind_fd "COUNT_CDC_BIND $box $suffix SOURCE_COUNT [llength $src] DESTINATION_COUNT [llength $dst]"
  if {[llength $src] == 0 || [llength $dst] == 0 || [lindex $src 0] eq "" || [lindex $dst 0] eq ""} {error "Count mailbox endpoint missing"}
  report_timing_path -from $src -to $dst -ep_num 4096 -path_num 1 -file [format {classified_audit/%s_%s.timing} $box $suffix]
 }
}
# Generated hierarchy uses a vendor '$' separator; packing can duplicate
# both synchronizer stages. Cover EVERY matching register, not one spelling.
set sw_all [get_regs {*count_controls*controls/sw_sync*}]
# Keep the tool's typed collections. Rebuilding their printed names with
# lappend loses physical object bindings in TD6.2. Packed FFs can also share
# the same launch cell/clock; THROUGH the actual Q net excludes its other FF.
set sw_first [get_regs {*count_controls*controls/sw_sync\[0\]*}]
set sw_second [get_regs {*count_controls*controls/sw_sync\[1\]*}]
set sw_first_net [get_nets {*count_controls*controls/sw_sync\[0\]*}]
foreach r $sw_all {
 if {![regexp {sw_sync\[[01]\](_syn_[0-9]+)?$} $r]} {error "Unexpected SW3 synchronizer alias $r"}
}
puts $bind_fd "SW3_SYNC FIRST_COUNT [llength $sw_first] SECOND_COUNT [llength $sw_second] ALL_COUNT [llength $sw_all]"
puts $bind_fd "SW3_SYNC FIRST $sw_first SECOND $sw_second THROUGH $sw_first_net"
if {[llength $sw_first] < 1 || [llength $sw_second] < 1 || [llength $sw_first_net] < 1 || [llength $sw_all] != [expr {[llength $sw_first]+[llength $sw_second]}]} {error "SW3 synchronizer missing"}
report_timing_path -from $sw_first -through $sw_first_net -to $sw_second -ep_num 4096 -path_num 2 -file classified_audit/sw3_sync.timing
report_timing_path -from $sw_first -through $sw_first_net -ep_num 4096 -path_num 2 -file classified_audit/sw3_sync_fanout.timing

for {set bit 0} {$bit<4} {incr bit} {
 set rf [get_regs [format {*count_controls*controls/button_meta\[%d\]*} $bit]]
 set rs [get_regs [format {*count_controls*controls/button_sync\[%d\]*} $bit]]
 set rq [get_nets [format {*count_controls*controls/button_meta\[%d\]*} $bit]]
 puts $bind_fd "KEY_SYNC $bit FIRST_COUNT [llength $rf] SECOND_COUNT [llength $rs] Q_COUNT [llength $rq]"
 if {[llength $rf]<1 || [llength $rs]<1 || [llength $rq]<1} {error "Key synchronizer binding missing"}
 report_timing_path -from $rf -through $rq -to $rs -ep_num 4096 -path_num 2 -file classified_audit/key_${bit}_sync.timing
 report_timing_path -from $rf -through $rq -ep_num 4096 -path_num 2 -file classified_audit/key_${bit}_fanout.timing
}
report_timing_path -to [get_ports {O_relay_control}] -ep_num 16 -path_num 2 -file classified_audit/relay_output.timing

set alarm_regs [get_regs {*left_station*controller/alarm_latched*}]
set motor_regs [get_regs {motor_output*}]
puts $bind_fd "V7_ALARM_MOTOR SOURCE_COUNT [llength $alarm_regs] DESTINATION_COUNT [llength $motor_regs]"
if {[llength $alarm_regs]<1 || [llength $motor_regs]<1} {error "V7 alarm/motor FF missing"}
report_timing_path -from $alarm_regs -to $motor_regs -ep_num 4096 -path_num 2 -file classified_audit/alarm_motor_interlock.timing

# New registered1us Gray time: bind each actual Q wire and BOTH first stages.
foreach bank {u_latency_capture u_latency_display} {
 for {set bit 0} {$bit<32} {incr bit} {
  set src [get_regs [format {u_latency_clock/us_gray\[%d\]} $bit]]
  set qnet [get_nets [format {u_latency_clock/us_gray\[%d\]} $bit]]
  set dst [get_regs [format {%s/gray_meta\[%d\]} $bank $bit]]
  puts $bind_fd "LATENCY_GRAY $bank $bit SOURCE $src THROUGH $qnet DESTINATION $dst"
  if {[llength $src]!=1 || [llength $qnet]!=1 || [llength $dst]!=1} {error "Latency Gray actual Q/first-stage binding missing"}
  report_timing_path -from $src -through $qnet -to $dst -ep_num 4096 -path_num 2 -file [format {classified_audit/latency_%s_%d.timing} $bank $bit]
 }
}
report_timing_path -to [get_ports {O_buzzer_n}] -ep_num 16 -path_num 2 -file classified_audit/buzzer_output.timing
set alarm_regs [get_regs {*left_station*controller/alarm_latched*}]
set buzzer_regs [get_regs {u_contest_buzzer/*}]
if {[llength $alarm_regs]<1 || [llength $buzzer_regs]<1} {error "Buzzer alarm binding missing"}
report_timing_path -from $alarm_regs -to $buzzer_regs -ep_num 4096 -path_num 2 -file classified_audit/alarm_buzzer.timing
close $bind_fd
puts "PASS CLASSIFIED AUDIT REPORTS: complete constraints, 20 Gray bits/fanouts, 6 new mailbox groups; numeric verification still required"
} reason]} {puts stderr $reason; exit 1}
exit 0
