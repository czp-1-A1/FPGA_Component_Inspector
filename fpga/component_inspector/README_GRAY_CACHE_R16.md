# R16 exact grayscale cache resource candidate

From verified R15 with general user board-pass feedback confirmed2026-10-24.
Only production RTL roi_sobel_view changes: store the same floor((R+2G+B)/4)
alongside RGB in each row cache, preserve read latency/scheduling/cache XOR,
remove duplicate gray arithmetic and wide RGB selection for adjacent rows.
Classification, counting, local recovery, metadata/CDC/ROI/controls/pages/Logo
and Chinese categories keep the exact R15 bytes. Original tests are unchanged.

New gray_cache_equivalence compares immutable R15 and this candidate at full
1280x720, both cache XOR modes, four display modes, RGB/coordinates/gradients,
statistics/timing, bubbles, credit loss, invalidation and reset warmup.
Original three independent pixel-oracle Sobel benches remain required.
Controlled simulations are not human-board image/counting acceptance.

Release requires all original72 and R15additional9 tests plus these4,
native RAW/metadata/pixel references, final Routed Slice<=19094 of21216,
setup/hold nonnegative and TNS0, full46max-delay/Ignored0/20Gray8ns/6mailbox/SW3
fanout audit. Old images remain unchanged. No push or board operation.

The first routed trial passed85 tests/timing/all constraints but used19106 Slice=90.0547%,12 above target; retained without release. The r2 experiment exposed constant BCD digits:86 tests passed and200 FF removed, but whole SYN increased18157 to18366 and DSP28 to29, so r2 PHY was canceled with evidence. This revision restores original full-width numeric caches and replaces only the eight decimal-formatter source selections (fmt6..13) with constant nine-bit slices. All binary fields, values, formatter schedule and pixels remain unchanged. It removes an arithmetic field address/variable-wide record selection, without changing detector, recorder or metadata. Original85 tests plus all32-field numeric/full720p old/new comparison are mandatory (86 total).

r3 final Routed reached18986/89.49% but setup -0.018ns/TNS-0.042 on counter oi->ob/cx->dx/prediction/abs/margin->matches. Retained and refused. This revision captures exact observation centres in the existing OBS and READ_APPLY cycles, before SCAN/ASSIGN and APPLY respectively. No extra FSM cycle, class/identity/decision/threshold changes. Full affected regression must actually rerun, plus new eight-profile160-frame cycle-equivalence against immutable original counter (87 contracts total). Original SDC/seed2/strict target and every test answer remain unchanged.

r4 new cycle-equivalence stimulus changed class before legacy first crossing, so immutable original and new both emittedzero and the nonzero-event coverage assertion correctly failed. r5 changes only that new stimulus to hold kinds untilframe45, keeping the existing nonzero-event assertion, all public-cycle/centre comparisons, all old86benches and production RTL unchanged. No expected production outcome was lowered.

r5 retained the original/new public-cycle equivalence but nonzero legacy event coverage still failed: duplicate source21 skipped a real 7px observation before the first crossing, so the next14px step correctly exceeded legacy12px bounds in both implementations. r6 moves only that deliberate duplicate stimulus toframe48 after the healthy event coverage window; the same duplicate fault, assertions, all old86bench bytes and production RTL remain. This is test-stimulus sequencing repair, not a production-result waiver.

r6 actual87/native tests and complete routed timing/constraints PASS (+.005/.020/TNS0) but19197 Slice=90.4836%,103 above strict resource threshold. Retained, no release. r7 changes only the UI text-plane read to synchronous prefetch of exactly next x/y state, targeting block RAM instead of112 distributed RAM LUTs. No text/Logo/test fields, public video clocks or counter decisions removed. Counter and all other production inputs retain r6 exact bytes; all existing87 benches remain unchanged plus new full720p DE-gap/VS/restart/reset old-new UI differential contract (88 total). Actual resource savings and final timing must be measured, not inferred.
