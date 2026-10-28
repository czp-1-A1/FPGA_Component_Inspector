# RL6 verification fixtures

Run `scripts/relay_left_checks.py --bench-dir tests/adjacent_v6 --osd --only ... --out NEW_ASCII_PATH`.

- `tb_adjacent_v6_control`: no-pulse handover, full fresh hold after reacquisition, wrong RUN/ID/source rejection, one retry per head, bounded absence, hard-fault priority.
- `tb_adjacent_v6_transport` and wrappers: two real ordered counters, shared key/CDC control, physical-coordinate reference; 1/2/3/5/8 adjacent EMPTYs, step3/4/6/10 and finite coast, 7-frame return, permanent absence/wrong-kind negative cases. Includes K2 preservation, 6 SW3 abandoned-run restarts and K3 clear.
- `tb_adjacent_v6_rgb`: actual 1280x720 detector/classifier pixels, two counters and controller, three consecutive EMPTYs. Full hold is 10,000,000 cycles at the fixture's 10MHz timing scale.
- `tb_adjacent_v6_osd`: two complete rasters, literal RL6 header and all 106 diagnostic characters, frame-held records, three-cycle output stream, unchanged clean guides.
- `tb_v6_display_mailbox`: asynchronous 163-bit mode/diagnostic/status coherence.
- `tb_adjacent_v6_real_second`: actual production 100MHz/1000ms, exact 100,000,000-cycle hold.
- `tb_adjacent_v6_native`: full native RAW10/ISP/vendor ERAM compatibility with V6 enabled and tolerance80; RAW fixture does not reach the parking line. Run `scripts/relay_left_native_check.py --v3 --bench-dir tests/adjacent_v6 --bench tb_adjacent_v6_native --out NEW_ASCII_PATH`.

Software proofs do not replace hardware parking, optical-image or refill validation. An eight-adjacent synthetic scene is not a claim that the actual detector resolves every eight-hole scene. Legacy weak RAW280 and upstream-gap negatives remain explicit boundaries.
