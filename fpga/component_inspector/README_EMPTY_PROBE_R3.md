# R3 passive empty-candidate rejection diagnostic (WIP)

No detection threshold, object-selection rule, counter rule or original page
is changed. One passive observation near the selected regions' centres follows
the existing source-frame publication. The original887-bit metadata width and
count-record low224 bits stay unchanged. Reserved count-record[255:224] carries:

| Bits | Meaning |
|---|---|
|31|Measured small contour available (not an accepted empty-hole verdict)|
|30|Region index,0 upper/1 lower|
|29:25,24:20|Width,height in half-resolution mask cells|
|19:17|Cells brighter than100,saturates at6; original limit5 unchanged|
|16,15,14|Empty geometry pass,circular shape pass,within16px taught row|
|13,12|Feed-hole geometry match,covered by a recognized body|
|11|Raw empty conditions including feed/body exclusion|
|10|Same contour remains in one of the published candidate slots|
|9,8|Its empty-specific dark reference was measured,then passed|
|7|Final published EMPTY|
|6|At least6 foreground cells|
|5:0|Signed horizontal offset/2 from centre,saturates at-32..31|

The probe considers3..12-cell small contours whose centres are within96px
horizontal and48px vertical from a taught ROI centre. It selects the smallest
Manhattan distance. Place the physical empty hole near the counting line for
interpretation; a selected locating hole is explicitly flagged by bit13.
Other small contours can be unobserved. No observation is not a brightness
measurement and cannot distinguish a too-dark hole from absence/merging.

Bit9=0 means dark reference was not measured for this empty candidate; bit8=0
alone must not be read as a failed dark reference. Bit10=0 can mean candidate
ranking,gate rejection or later replacement; combine it with the raw gate flags.
Only the normal proved frame sample may publish the word. Cancellation/source
start clears it. Render from frame_record, never the asynchronous live record.

R2 incorrectly retained a fixed LOCKING footer in RUN/LOST. R3 replaces it with
EMPTY PROBE and keeps the actual STATE at the top. Diagnostic bits must never
feed classification,generate holes or change cumulative counts.

R3 is not yet a routed or board-validated release. See current_status.json in
the task root for the final frozen candidate and evidence; keep prior R2 intact.
