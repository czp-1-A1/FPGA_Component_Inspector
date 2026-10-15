# V11_FHD_to_720p60_r9_20261015

Read V11_FHD_to_720p60_r9_20261015_烧录与验收.md for programming and physical acceptance. No hardware was programmed by the assistant.
Software and routed STA pass; physical video and 220mm calibration remain pending.

The full project input is source_snapshot/ (342 hashed files, including the independent font reference).
The original Git provenance is lj4747-contest-work / da195838d8a1df052edeaa86f60312d32eeedf9a.
This imported source bundle is not a Git checkout. No commit or push was performed.

Windows replay (Python3.10+, NumPy, installed licensed ModelSim and TD):

    python scripts/replay.py --action verify
    python scripts/replay.py --action prepare --work D:/v11_replay --td-root D:/td6.2.1
    python scripts/replay.py --action sim --work D:/v11_replay --td-root D:/td6.2.1 --modelsim-bin D:/modeltech64_10.5/win64
    python scripts/check_hd_reference.py D:/v11_replay
    python scripts/replay.py --action build --work D:/v11_replay --td-root D:/td6.2.1

The runner resolves both TD doc/scripts and scripts flow locations. The image checker reads UTF8/UTF16 logs without changing its reference algorithm.
The tests and production inputs are checked before use. Use a new ASCII directory with no spaces.
Recheck timing/constraints after rebuilding with another tool version; a build exit alone is insufficient.

To independently recheck the bundled actual output images:

    python scripts/check_hd_reference.py evidence/r9

For routed Gray-bit audit run TD with scripts/audit_routed.tcl from built_project/.
The archived built project retains the actual machine's absolute project Path metadata; relocate via prepare before normal rebuilding.
Vendor tools/libraries/licenses are external dependencies and are not packaged.
