# R18 P03 standing review and lossless RGB cache

R17 is the frozen receiving base. P03 functional9d459688 adds exactly the
unrounded bright-edge guard: old P02 proof AND 2*max(edge32 sums)<=center64 sum+16.
Production ENABLE_STANDING_REVIEW=1. Standalone default0 retains explicitly
tested P02 compatibility; the original97 benches remain byte-identical and
seven new contracts explicitly enable new decision, RAW probe-on/probe-off,
all8 indexed slots, unchanged recorder and production R18 literal pixels.

RGB row storage has only one requested read row, whereas gray requires three
parallel rows. Share the RGB RAM and preserve four gray banks, PPC4, full RGB888,
read latency, original XOR encoding, four modes, ROI and source cadence.
All counter/pipeline/local recovery/controls/metadata/SDC bytes remain R17.
Source freezes, actual inputs/logs, full original SDC/seed2 route and independent
archive restore are required before delivery. Human board accuracy pending.
