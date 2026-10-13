import_device ph1_35p.db -package PH1P35MDG324 -speed 3
import_db camera_to_dsi_display_gate.db
help report_timing
help report_timing_summary
help check_timing
help get_pins
help create_generated_clock
puts "SCL_PINS [get_pins {*scl_clk*}]"
puts "BUTTON_PINS [get_pins {*btn_meta*}]"
exit
