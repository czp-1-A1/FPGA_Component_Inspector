# 3528 shape teaching trial

Current 180 mm sample intake (EXP1092 / GAIN40):
[`calibration_180mm/README.md`](calibration_180mm/README.md).
The six user-provided monitor photos are indexed with scene labels and SHA-256;
native grayscale calibration and independent validation remain pending.

This is an offline grayscale segmentation and shape-feature comparison tool.
It does not modify RTL, publish a bitstream, locate pockets automatically, or
turn a reference match into a production PRESENT/EMPTY decision.

`3528w_screen_trial.json` is a draft reference library taught from screen photos:
white component, actual small empty-pocket opening, and large sprocket hole.
The datasheet's 3.5 x 2.7 mm body dimensions are reference information, not
calibrated image thresholds. Runtime FPGA recipes have not been implemented.

Install the versions in `requirements.txt` into an isolated Python environment.
Run the checks and the experiment with the archived sample manifest:

```powershell
python test_probe.py
python probe.py --samples samples.json --root D:/path/FPGA_Component_Inspector --output results
```

Sample manifests specify a full photo, a manually selected known-LED scale
reference for each photo, and candidate crop rectangles. `teach` records alone
build the prototypes. `holdout`, `challenge`, and `overlay_probe` records do not
update them. Ground truth is excluded from comparison and retained in reports.

The largest bright contour is measured after local Otsu segmentation. Filled
outer-contour area and normalized corner occupancy describe shape; body size
and aspect describe geometry. The internal round phosphor area does not erase
the rectangular body. No-match and ambiguous-match results remain UNCERTAIN.
Low contrast, clipped silhouettes, and plain background are rejected.

Distances are feature differences, not confidence probabilities. Similarity to
the empty reference does not prove that the candidate lies in a genuine pocket;
pocket location still needs verification before an operational EMPTY output.

Round 1 uses three teaching regions from one phone photo and three unprocessed
display regions from another photo. Each photo has a manually known LED scale
reference. Orange edge overlays are tested separately because they alter image
features. These are limited phone-photo probes, not native sensor frames, field
accuracy statistics, streaming FPGA tests, or resource/timing validation.

Evidence and source hashes:
`开发实施/验收记录/20261013_A_3528形状配方离线试验_轮次1.md`.
