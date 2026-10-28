# Fixed-region classified pocket counting (WIP)

Baseline: `lj4747-contest-work`, commit `550900636025de23c15e5ad48a746dae9749c4d3`.
This working candidate has no delivered or board-accepted bitstream yet.

## Operation

The original `frame_shape_search`, `inspection_region_config`, and
`experiment_osd` are retained byte for byte. The same T100 body/T80 empty-hole
algorithm supplies all observations. There is no second global pocket detector
or additional image buffer. Only one tape in one existing fixed region is used.
If both regions contain credible targets the counter waits (or stops an active
run). The original page and all its calibration/statistics remain available.

* SW4 upper: original inspection page; lower: counting page. The switch only
  changes display selection, in vertical blank. Counting continues on either page.
* KEY1+KEY4 held1s: new run, logical total zero; KEY3+KEY4 held1s: finish.
  Chords suppress AE/gain/WB side effects. Single camera controls remain usable.
* ACQUIRE: at least two classified observations, three matched frame transitions
  and a coherent displacement of at least4px establish direction. Stationary
  samples can be detected, but direction is established by motion.
* RUN: a target must have been observed completely upstream. Its trailing box
  edge must pass the center line with3px hysteresis before one ID is committed.
  Targets already downstream when locking are not back-counted.
* Source displacement is limited to12px and strictly less than measured pitch/4.
  Measured pitch checks association/gaps only; it never invents a missing target.
  This limit applies to observed centers, including quantization. The synthetic
  native RAW12px-average case produced11/13px observations and did not lock; that
  case is retained as an unpassed speed boundary. First board tests must be slow
  (about1 hole/s); the native crossing regression uses8px/source. Do not treat the
  association limit as a calibrated conveyor speed.
* Pauses preserve identity. Reversal, ambiguous association, changed class,
  inconsistent spacing, frame/config loss, or CSI timeout freezes counting.
  A backward step over3px stops immediately. Smaller reverse evidence accumulates
  across frames:6px net backward displacement also stops the run, while motion
  back and forth within3px cancels without another count.
  Record the affected segment, then start a new run; there is no silent recovery.
* At300 the run ends. PRESENT includes present parts with placement-review
  reason bits. REVIEW is a subset of PRESENT, so TOTAL=PRESENT+EMPTY.
* LAST shows the most recent committed class/reason. EMPTY IDS rotates through
  eight empty pocket IDs per page every2s, including after finishing.
  Original reason bits are retained even for EMPTY; its SIZE/ASPECT bits refer
  to the present-part recipe and do not mean a defective empty hole. REVIEW
  counts only PRESENT holes with retained review evidence.

Relying on the original detector means unrecognized/uncertain objects cannot be
turned into confirmed holes. A visible class1 crossing the line stops the run;
unmatched near-line tracks and inconsistent gaps also stop it. No location-hole
or periodic extrapolation generates count events. The original two-best-results
per region is a selection interface, not a physical ID: the counter associates
positions across source frames and checks rank churn explicitly.

## Interfaces

Each unchanged classifier object is76 bits:
`valid1,kind2,reason4,foreground13,width7,height7,x0(11),x1(11),y0(10),y1(10)`.
Kind2 is PRESENT (reason bits retained); kind3 is EMPTY; kind0 is not a target;
kind1 is uncertain. Display slot1/2 is never used as a count ID.

`classified_pocket_counter` provides a one-cycle event:
`event_run16,event_id9,event_frame32,event_kind2,event_reason4`.
Its32 records share a60-bit packed track RAM; total and empty-ID storage are
bounded by300. RAM is not reset en masse; read bounds hide prior-run content.

The original631-bit metadata layout is unchanged. A256-bit extension is bound to
the same source epoch, DDR slot, late attachment and display snapshot:

| Bits | Field |
|---|---|
|31:0|source frame ID|
|47:32|run ID|
|50:48|state:0 READY,1 ACQUIRE,2 RUN,3 LOST,4 DONE|
|54:51|tracking reason|
|55 /56 /57|direction valid / rightward / selected region|
|66:58 /75:67 /84:76 /93:85|total / present / empty / review|
|129:94|four classifier-slot IDs,9 bits each (valid for that source frame only)|
|201:130|eight empty IDs for the indicated page|
|210:202 /212:211 /216:213|last ID / class / original reason|
|222:217 /223|zero-based empty-list page / valid marker|
|255:224|reserved zero|

The live header may update before a displayed video frame. Spatial labels use
only that displayed frame's metadata and same-run check; stopped/stale/lost frames
do not inherit prior IDs. Repeated HDMI rasters never drive the counter.

Tracking codes:1 waiting for observations/direction;2 multiple regions/region
change;3 ambiguous or incoherent association;4 missing/too-fast near-line target;
5 reverse;6 source/config/bad frame/CSI timeout;7 uncertain or changed class;
8 processing overlap/capacity;9 inconsistent measured spacing. These codes belong
to this new counter, not the earlier R8 diagnostic build.

## Build and acceptance

Use `tools/prepare_classified_project.py --td D:/td6.2.1` in an isolated frozen
copy. It derives run descriptors from the .al and verifies internal dependencies
without changing RTL/pins/SDC. Execute each run's `build.tcl` with
`td_commands_prompt.exe`. Synthesis estimates are not final routed resources.
Full software, original-page equality, native RAW10/video binding, final routed
setup/hold>=0 and both TNS=0, all active constraints/Gray buses/mailboxes, and
human known-sequence tests remain mandatory before acceptance. No board access,
commit, push or old-image overwrite is part of this candidate build.
