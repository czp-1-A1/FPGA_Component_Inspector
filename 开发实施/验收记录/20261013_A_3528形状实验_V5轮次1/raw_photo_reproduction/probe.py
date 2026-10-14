"""Offline shape teaching trial. Screen-photo matches are not board detections."""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

FEATURES = ("extent", "corner_fill", "relative_size", "aspect")
# Exploration tolerances, not camera calibration or production thresholds.
SCALES = np.array([0.15, 0.40, 0.20, 0.25])
MAX_DISTANCE = 0.80
MIN_MARGIN = 0.15


def extract(rgb):
    """Measure the largest silhouette in one manually supplied candidate crop."""
    rgb = np.asarray(rgb, dtype=np.uint16)
    gray = ((rgb[:, :, 0] + 2 * rgb[:, :, 1] + rgb[:, :, 2]) // 4).astype(np.uint8)
    if int(gray.max()) - int(gray.min()) < 12:
        return {"quality": "LOW_CONTRAST"}
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    threshold, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return {"quality": "NO_CONTOUR"}
    contour = max(contours, key=cv2.contourArea)
    area = float(cv2.contourArea(contour))
    x, y, w, h = cv2.boundingRect(contour)
    rows, cols = gray.shape
    if x <= 1 or y <= 1 or x + w >= cols - 1 or y + h >= rows - 1:
        return {"quality": "TOUCHES_CROP_BORDER"}
    if area < 8:
        return {"quality": "TOO_SMALL"}
    rect = cv2.minAreaRect(contour)
    short, long = sorted(rect[1])
    if short <= 0:
        return {"quality": "DEGENERATE"}
    # Fill the outer contour: the LED's internal round area is not a missing body.
    silhouette = np.zeros_like(gray)
    cv2.drawContours(silhouette, [contour], -1, 255, cv2.FILLED)
    destination = np.float32([[0, 0], [31, 0], [31, 31], [0, 31]])
    transform = cv2.getPerspectiveTransform(cv2.boxPoints(rect), destination)
    normalized = cv2.warpPerspective(silhouette, transform, (32, 32), flags=cv2.INTER_NEAREST)
    corners = [normalized[2:10, 2:10], normalized[2:10, 22:30],
               normalized[22:30, 2:10], normalized[22:30, 22:30]]
    return {
        "quality": "MEASURED",
        "extent": area / (short * long),
        "corner_fill": float(np.mean([np.count_nonzero(c) / c.size for c in corners])),
        "aspect": long / short,
        "long_px": long,
        "threshold_otsu": threshold,
        "bbox": [x, y, x + w, y + h],
        "outline": contour[:, 0, :].tolist(),
    }


def vector(features):
    return np.array([features[key] for key in FEATURES], dtype=float)


def compare(features, prototypes):
    if features["quality"] != "MEASURED":
        return {"match": "REJECT_CROP", "reason": features["quality"]}
    distances = sorted(
        (float(np.mean(np.abs(vector(features) - np.array(p)) / SCALES)), name)
        for name, p in prototypes.items()
    )
    best, name = distances[0]
    margin = distances[1][0] - best
    matched = best <= MAX_DISTANCE and margin >= MIN_MARGIN
    return {"match": name if matched else "UNCERTAIN", "distance": best,
            "margin": margin, "distances": {name: distance for distance, name in distances}}


def run(manifest_path, root, output):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    images, scales, hashes = {}, {}, {}
    for name, item in manifest["photos"].items():
        path = root / item["path"]
        images[name] = Image.open(path).convert("RGB")
        reference = extract(images[name].crop(item["scale_reference_roi"]))
        if reference["quality"] != "MEASURED":
            raise ValueError(f"Scale reference {name}: {reference['quality']}")
        scales[name] = reference["long_px"]
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    records = []
    for sample in manifest["samples"]:
        features = extract(images[sample["photo"]].crop(sample["roi"]))
        if features["quality"] == "MEASURED":
            features["relative_size"] = features["long_px"] / scales[sample["photo"]]
        records.append({**sample, "features": features})
    prototypes = {}
    for name in ("present", "empty", "sprocket"):
        taught = [vector(r["features"]) for r in records
                  if r["split"] == "teach" and r["truth"] == name
                  and r["features"]["quality"] == "MEASURED"]
        if not taught:
            raise ValueError(f"No measured teaching sample for {name}")
        prototypes[name] = np.mean(taught, axis=0).tolist()
    for record in records:
        # Truth is used to teach/report only; comparison never receives it.
        record["comparison"] = compare(record["features"], prototypes)
    model = {
        "status": "SCREEN_PHOTO_TRIAL_NOT_BOARD_CALIBRATION",
        "part_number": "3528W",
        "datasheet_reference_mm": {"long": 3.5, "short": 2.7, "tolerance": 0.2},
        "features": list(FEATURES), "feature_scales": SCALES.tolist(),
        "max_distance": MAX_DISTANCE, "min_margin": MIN_MARGIN,
        "prototypes": prototypes, "photo_sha256": hashes,
        "scale_reference_long_px": scales,
        "limitations": ["Manual candidate crops and per-photo scale references",
                        "Camera geometry and true pocket location not verified",
                        "Orange/cyan overlays can alter contour measurements",
                        "No native-frame or FPGA accuracy claim",
                        "Empty reference match alone is not a valid empty-pocket decision"],
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / "model_draft.json").write_text(json.dumps(model, ensure_ascii=False, indent=2), encoding="utf-8")
    (output / "measurements.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    summary = [{"id": r["id"], "split": r["split"], "truth": r["truth"],
                "processing": r["processing"], **r["comparison"]} for r in records]
    (output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=Path, required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    run(args.samples, args.root, args.output)
