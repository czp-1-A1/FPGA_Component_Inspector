# Sampling UI build 2026-10-05

User-approved sampling interface only. 1024x600, finite Chinese/ASCII ROM fonts, Anlogic mark, 512x256 gray observation and 80x80 cyan statistics core; four controls unchanged. Recent coherent 28-bit sample + destination recovery gate; all video/sync/bypass delayed 3 pixel clocks. Production classification disabled (UNCAL), no T58 enabled.

ModelSim default 14 tests PASS. TD synthesis/place/route PASS: Slice 14240 (67.12%), ERAM 36, DSP 8; setup 1.062ns, hold 0.02ns, TNS zero. SDC unchanged; existing IO/PLL/DDR coverage gaps retained, STA 94.99%. Six dedicated receive/ROI mailbox budgets matched. Not hardware tested; user downloads the bit.

Bit SHA-256: ab23766b4b51c4df1d331fc14ad7f5bcc8a5ddeeeae3a2aedb8929cf04332ea1

Evidence: 开发实施/验收记录/20261005_A取样界面字体Logo状态_轮次1.md and same-name directory. All 203 inputs and project hash recorded in manifest.json. Working tree uncommitted and not pushed; prior releases preserved.
