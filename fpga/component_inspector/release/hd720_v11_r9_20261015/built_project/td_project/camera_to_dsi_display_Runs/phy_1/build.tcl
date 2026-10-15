if {[catch {
source {D:/td6.2.1/doc/scripts/DefaultFlow.tcl}
analyze_clock -detail
check_timing -file constraint_coverage.txt -verbose
} reason]} {puts stderr $reason; exit 1}
exit 0
