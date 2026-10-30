# R26 candidate B: SW3 epoch boundary and equivalent surface comparisons

This is an isolated timing candidate, not a verified delivery. Candidate A
and its complete executions remain unchanged in dual_roi_r26_20261028.

The record-only pipeline closes the previous epoch on a new run, accepts only
the same-edge or next source FS, excludes old results and retains true proof,
missing-result, configuration and source-stop faults. IDs stay monotonic across
run boundaries. SW3 debounce, counters, detector thresholds, clocks, SDC and
the R25 sparse-search optimization are unchanged. The screen says R26.

A passed all24 actual functional tests but failed routed setup by0.522ns.
The critical path was cache RAM through the final surface sum/extrema and
comparison. B distributes the min/max threshold comparisons using exact
integer equivalences: min(a,b)*5>=center*4 iff both a,b are at least
center-floor(center/5); 2*max(a,b)<=limit iff both a,b<=floor(limit/2).
The means, extrema, Sobel signs, thresholds, decisions and all FSM phases
stay identical; no register, cache, image RAM or processing cycle is added.
Trace and decision logic share the same equivalent predicates.

An exhaustive32768 contrast and2097152 shift comparisons passed. Preliminary
34-input/40-kernel unit and14-image detector/sparse comparisons passed with
identical public decisions and FSM cycles. They are preliminary evidence;
the final B frozen profile must run all24 tests again with zero old PASS reuse.
The native dispatcher also includes both required vendor global tops.

Formal targets:22 short regressions; the unchanged12-source moving P/E/E/P
RAW sequence; and10-source actual SW3+CDC dense RAW. In the latter, sources
1/3/9 are interrupted by SW3 and excluded, sources2/4/5/6/7/10 bind to runs
1/2/2/2/2/3, source8 WB cancellation produces genuine C6 at source9 before
SW3 starts run3, and four uninterrupted dense frames4..7 retain the original
27FPS deadline. Exact RGB transport and zero fabricated static events remain.

Only a fully accepted routed build and independent archive restoration may
be promoted to D:/fpga_download. Human board acceptance and Ethernet work
remain separate. Do not claim all possible field C6 causes are fixed.
