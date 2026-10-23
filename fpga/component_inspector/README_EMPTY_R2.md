# Empty-pocket r2 diagnostic candidate (not yet delivered)

The reported r1 field video shows PRESENT3/EMPTY0, then LOST. Phone footage
cannot establish the native T80 mask size, bright-cell count, or dark strips.
The earlier guess that both empty pockets crossed before RUN is not proved;
near the RUN transition they approach the line without a classified EMPTY box.

Frozen r1 actual-pixel E,E,P,P,P experiments establish two independent failure
modes: a five-cell T80 hole wholly above T100 is deliberately rejected by the
original bright-fragment guard; a six-cell dim hole is outside its old3..5
recipe. Neither is an event-ledger omission. These are synthetic sensitivity
experiments, not measurements of this camera recording.

Upstream5a71d9a (2026-10-19) expands the taught empty extent to6. Applying that
recipe blindly to the original wide ROI was independently rejected: a locating
hole can erode to6 cells at a2x2 sampling phase, becomes a second EMPTY in the
other row, and the counter safely reports association ambiguity. Preserve that
failed experiment in geometry_diagnostic_r1; do not deliver it.

This trial adds COUNT_EMPTY_MARGIN, default0. In the shared counting ISP only,
it admits the existing circular/brightness/dark-proved contour up to6 cells
within16 processing pixels of the taught pocket-row centre (320 or516). Old
3..5 cases retain their recipe everywhere in the fixed ROI. The extra case is
refused outside this row band. Thresholds T100/T80, bright-cell cap5, local
dark proof, event ledger, tracking and all original UI sources remain fixed.
Keep the physical pocket row at the fixed ROI centre; feed holes may be above
or below it. This restricted extension does not establish field calibration.

The count page shows measured candidate boxes during ACQUIRE and FRAME OBS
P/E/U for that displayed frame. These are the shared classifier's published
records, not cumulative counts or a second detector. They help distinguish
classification failures from tracking/numbering failures. SW4 up still selects
the original UI. Real RAW regression, final routing and full constraints are
required before issuing a new bit. Human truth is still required for the empty
pockets in the supplied video; a bright or weak native mask may need a different
calibration and must not be guessed from phone-display brightness.
