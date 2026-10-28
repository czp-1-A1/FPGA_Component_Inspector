# R5 fixed-ROI shared-result recorder

Physical SW3 (E11): raise for20ms then lower to start a new run, one start
per edge, held down never repeats. Power-up already down does not auto-start.
Raise only rearms the next start; does not erase a running segment.
SW4 (D11): unchanged original/count page. SW1/2 unchanged view controls.
K1+K4 no longer starts. K3+K4 hold1s stops and clears displayed RUN, all
totals, last result, empty IDs/pages and object IDs without reprogramming.
Internal generation and source IDs remain monotonic to reject stale DDR data.

RESULT_RECORDER opt-in is enabled in the production wrapper's shared ISP and
count renderer. The original classifier RTL, font and original UI stay byte
identical to R4. Only its already-published kind/reason/position results enter
the recorder. No second pixel detector, inference of missing holes, or new
classification threshold. Temporary measurement probes are disabled only in
the production recorder mode to recover resource headroom; classification is
unchanged. Legacy parameter defaults retain the original32 regression targets.

Source-frame tracking deduplicates observed identities, locks real direction,
counts observed centre crossings with4px hysteresis, records the latest shared
class, and keeps all empty numbers through300 automatic end. A stationary
tape retains identity. Three matched source frames and real movement establish
direction; startup holes already downstream are not counted retrospectively.
One observed target is sufficient; candidate rank is never an identity.
Observed spacing bounds association below half spacing; it never fills a gap.
An armed target may survive at most two proved source-frame observation gaps,
only while the measured speed bounds its return uniquely; no event can be
generated during the gap. An unresolved gap, reverse, ambiguity, bad/source
frame/config failure stops numbering. No silent restart after LOST.

R4 field video had P1/E1 while counter LOST4. Frozen counter also reproduces
immediate LOST4 from a single observation dropout at spacing44/step6. This is
an offline sensitivity proof, not exact native coordinates or all field causes.
All original32 and five additional production-mode targets, independent native
reference, final Routed nonnegative setup/hold/TNS0 and complete constraints
must pass before a bit is delivered. Human same-bit count acceptance required.
