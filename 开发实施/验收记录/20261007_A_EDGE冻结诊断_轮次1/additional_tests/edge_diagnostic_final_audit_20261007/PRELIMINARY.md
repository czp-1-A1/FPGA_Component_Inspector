# Preliminary independent build audit, 2026-10-07

Stage: synthesis checked; route/bit generation still pending. This is not final approval.

All207 frozen manifest inputs match both actual build inputs and current engineering SHA-256. Source is immutable for thischeck; engineering has not been edited by auditor.

Expanded overflow mailbox is52bits. Gate hierarchy seq110 is52 payload+52 D_data+6tokens. Its payload timing budget matches208 dominated208, shadowed0 ignored0; req2/2/0/0 and ack2/2/0/0. Existing source wildcard budgets therefore cover the expanded payload rather than cutting it. Full constraint table and existing legacy shadows are retained; not claiming allconstraints shadow-free.

Gate utilization: slice15051/21216(70.94%), old14830(69.90%); LUT18188 old17931; reg17804 old17591; ERAM48/108 unchanged, DSP8/40 unchanged. Basic setup+1.019ns, hold+0.114ns, TNS0. These are synthesis estimates, not final physical metrics.

Warnings ID/severity comparison: {"HDL-5001 WARNING": 4, "HDL-5007 WARNING": 41, "HDL-5106 WARNING": 2, "HDL-5314 WARNING": 20, "HDL-5317 WARNING": 20, "HDL-5323 WARNING": 5, "HDL-5369 WARNING": 1, "SYN-5011 WARNING": 12, "SYN-5013 WARNING": 10, "SYN-5025 WARNING": 3, "SYN-5041 WARNING": 3, "SYN-5065 WARNING": 1, "USR-6135 CRITICAL-WARNING": 2}. Normalized added warning records: 0; removed: 0. See synthesis_warning_comparison.json for exact content. No ERROR/CRITICAL-ERROR records. Existing vendor undriven nets, auto-RAM setting, initial-value omission, and local PLL feedback critical warnings are not waived by this audit.

Final route timing/STA/constraint/warning/bit SHA audit will be appended after physical process completes.
