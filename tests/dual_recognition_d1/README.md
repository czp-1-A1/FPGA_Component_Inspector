# Dual recognition D1 checks

Recognition-only production configuration; no new dual-count algorithm. Each selected run seals exact production and fixture bytes before compilation.

- `tb_dual_manual_keys`: 28 control assertions; K1 manual run, K2 toggle, K3/K4 stop, six SW3 cycles, bounce/held/boot-held handling, CDC and literal extracted top motor register. No AUTO mode allowed.
- `tb_dual_pixels`: six real 1280x720 RGB rasters and 32 physical P/E checks across both original ROIs, 4 candidates per region, independent absent region, feed/outside rejection, cancellation/restart, display pair mapping.
- `tb_dual_osd`: two full 720p output rasters, 792 literal UI characters, upper/lower region and result outlines, three-clock pixel/control latency, motor status held for the frame, no count page/ID or refill guides.
- `tb_dual_recognition_native`: seven RAW10 frames at native recovered CSI cadence through actual ISP/vendor ERAM/DDR metadata and display readback. All accepted source frames, including first, must have complete words/commit proof and selected-slot pixels. Tests all four views and an invalidated midframe WB change. Count/auto outputs must remain zero. Native P geometry test does not establish optical E recall; RGB test separately covers E.
- `tb_dual_baseline_probe`: diagnostic comparison only, not selected PASS. Original warm-up test assumed first frame invalid; original RL7 and D1 both produce a complete valid first frame. The final native test checks every accepted frame identically rather than discarding the first. Original failures are archived separately.

Example independent output directories (never overwrite a sealed run):

```powershell
D:/Python3.10.11/python.exe -X utf8 scripts/relay_left_checks.py --source BUILD/project --bench-dir tests/dual_recognition_d1 --support extracted_dual_motor --osd --only tb_dual_manual_keys tb_dual_pixels --out E:/2026FPGA/d1_units_new
D:/Python3.10.11/python.exe -X utf8 scripts/relay_left_checks.py --source BUILD/project --bench-dir tests/dual_recognition_d1 --osd --only tb_dual_osd --out E:/2026FPGA/d1_osd_new
D:/Python3.10.11/python.exe -X utf8 scripts/relay_left_native_check.py --source BUILD/project --bench-dir tests/dual_recognition_d1 --bench tb_dual_recognition_native --pass-token "PASS DUAL RECOGNITION NATIVE:" --out E:/2026FPGA/d1_native_new
```

Also selected: feature-off original V3 keys and RL7 OSD compatibility, fresh legacy `regions/text_plane_prefetch/empty_trace_abort`, and full synthesized camera-cone I2C with modeled ACK slave. Ten selected simulation checks total, plus strict routed audit. Not hardware programming, optical readback, dual counting or automatic parking acceptance.
