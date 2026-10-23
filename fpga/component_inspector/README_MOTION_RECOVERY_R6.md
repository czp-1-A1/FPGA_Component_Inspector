# R6 result recorder motion recovery

R5 classifier, original page, fonts, ROI, controls and source/DDR publication are preserved. New motion policy is enabled only for production RESULT_RECORDER through MOTION_RECOVERY=1; default0 retains the frozen R5 policy for compatibility tests.

Association is strictly below half measured spacing, capped32 processing pixels per source frame. Missing observations retain identity at most2 proved frames. Same-row matched anchor motion during absence is stored as a signed9-bit sum per track. It only associates an actual returning classification, and never generates a position, hole, class or count. Returning residual is checked against8px and prior measured step; ambiguous associations still stop. Counted near-line identities are kept until measured forward travel puts them beyond the allowed backslip, preventing duplicate recrosses.

Backslip is allowed below the same unique half-spacing bound (44px spacing gives21px cumulative reversal threshold, versus R5's4px single/8px cumulative). Sustained reverse, source/config discontinuities, ambiguity and unresolved gaps still stop. No encoder means arbitrary speed/backward movement is not promised.

39 required software tests keep all original37 benches unchanged. Additional tests cover finite15 holes/3 empties both directions,20px per source frame,2-frame temporary absence, bounded backslip,300 holes/empty ID ledger, and independent native RAW10 with12 actual source frames at20px/frame and44px spacing. These synthetic checks do not establish real-board counting accuracy. Routed full constraints/setup/hold/TNS acceptance is mandatory before delivery.

SW3 up then down starts once; SW4 original/count page; K3+K4 hold1s clears visibleRUN/totals/emptyIDs. Count-page header adds C:reason so a cropped phone video can retain loss evidence; original UI is byte unchanged.
