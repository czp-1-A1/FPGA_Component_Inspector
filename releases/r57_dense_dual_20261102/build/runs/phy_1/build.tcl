if {[catch {
source {D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl}
check_timing -file constraint_coverage.txt -verbose
report_timing_summary -file final_timing.rpt
report_area -io_info -file final.area
} reason]} {puts stderr $reason; exit 1}
exit 0
