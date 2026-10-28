# R21 passive empty-gate diagnosis

This is R20 classification/counting/local recovery, with a passive observer.
No shape threshold, frame, object, identity or crossing event is invented.
The existing128-bit calibration metadata transports two same-source traces.
Only the former CAL measurement content and low-level footer change in this
diagnostic build. Disable ENABLE_EMPTY_TRACE to restore the original CAL/UI.
P03 surface proof, mask, processing FSM and video/metadata width are unchanged.

TR1/TR2 refer to ROI1/2. The small cyan cross marks the measured small contour
closest to count-line X and the current measured body row. It may mark a feed
hole if the row estimate itself is wrong; record coordinates and the video.
All printed numbers are hexadecimal. X/Y are source-pixel bbox-centre sums;
WH are half-resolution mask extents; A is foreground mask cells; BD is the
saturating >100 bright-cell count (0..6) and saturated row deviation (0..3F).
F bits14..0: anchor,size,circle,robust,row,feed,body,insert,retained,ref-seen,
ref-pass,published-E,border,complete,queue-overflow. SRC binds displayed frame.

C priority: F queue overflow; D incomplete; 0 no small component measured;
1 border/too-small;5 feed exclusion;6 body overlap;2 size;4 bright off-row;
A publishedE;9 failed dark context;3 shape;8 inserted but not retained;
7 other intermediate rejection (including failed high-box rescue).
These are observational codes, not new acceptance rules. Trace selection is
one component per ROI per source frame, so absence is not a full-frame scan.

No physical accuracy acceptance is claimed. Old128test answers stay intact.
Additional trace192scene old/new public-signal/FSM-cycle equivalence,
independent captured-RGB/CCL trace fields, same-source RAW/DDR binding and
literal two-page720p pixel reference must pass before full-route/constraints.
