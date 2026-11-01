# RL7 selected verification

Production enables FIVE_EMPTY_V7=1, ADJACENT_V6=1, target152/tolerance80/advance32. Leaves default to the old feature-off mode for explicit compatibility.

- Position/control and true two-counter transport: window72..232, 1/2/3/4 consecutive EMPTYs; 5/8-hole scenes must stop upon the fifth confirmed EMPTY, preserve five queued IDs, never complete a parking cycle. Variable/fast scenes and continuous7-frame return, permanent absence/wrong-kind negatives remain.
- Alarm control: four EMPTYs + PRESENT + four EMPTYs do not alarm despite queue8; fifth of the next segment locks. K2/resume/manual cannot bypass, K3/newRUN reset, invalid ordinal/epoch not counted as five, pause-time arrival still alarms; exact same-clock HOLD completion cannot pop a head when fifth alarm arrives.
- `extracted_production_motor.sv` is the exact motor register body from the production top, checked byte-for-byte by the publisher; not a separately implemented motor equation. Run alarm control with `--support extracted_production_motor`.
- OSD: exact RL7 status characters, shifted amber border, frozen frame data, red alarm text and real glyph pixels, 3-cycle RGB/control stream.
- Actual 1280x720 RGB detector/classifier: three-hole parking and P+five EMPTY alarm; full100MHz/100000000-cycle1-second check; full native RAW/ISP V7 enabled. Native RAW does not reach the parking line.

Use scripts/relay_left_checks.py --bench-dir tests/shift_alarm_v7 --osd --only tb_v7_transport and the wrappers --out NEW_ASCII_PATH. Wrappers include the sealed transport fixture, so include tb_v7_transport in the same batch. For native use scripts/relay_left_native_check.py --v3 --bench-dir tests/shift_alarm_v7 --bench tb_v7_native --out NEW_ASCII_PATH.

Legacy compatibility is separately labeled feature-off; old five/eight successful holds are not a claim about the enabled five-hole alarm mode. Old weak RAW280/high-speed/upstream-gap failures remain boundary evidence, excluded from selected PASS checks. Software proofs are not hardware parking/refill acceptance.
