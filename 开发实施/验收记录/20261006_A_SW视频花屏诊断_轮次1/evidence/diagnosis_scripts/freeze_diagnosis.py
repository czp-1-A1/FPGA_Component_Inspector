"""Archive diagnosis evidence without changing RTL or released artifacts."""
import hashlib
import json
import shutil
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
project = repo / "fpga/component_inspector"
record = repo / "开发实施/验收记录/20261006_A_SW视频花屏诊断_轮次1"
frozen = json.loads((project / "release/sw_edge_20261005/manifest.json").read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


source_results = []
for item in frozen["verified_build_inputs"]:
    path = project / item["path"]
    actual = sha(path)
    source_results.append({"path": path.relative_to(repo).as_posix(),
                           "expected_sha256": item["sha256"], "sha256": actual,
                           "matches": actual == item["sha256"]})
al = project / "td_project/camera_to_dsi_display.al"
source_results.append({"path": al.relative_to(repo).as_posix(),
                       "expected_sha256": frozen["project_sha256"], "sha256": sha(al),
                       "matches": sha(al) == frozen["project_sha256"]})
bits = []
for relative, expected in (
    ("release/sw_edge_20261005/camera_to_dsi_display.bit", "a43156b8fc076d7940e12b8f7ba46d026a3053466b759724bef79235570bcd8c"),
    ("release/sample_ui_20261005/camera_to_dsi_display.bit", "ab23766b4b51c4df1d331fc14ad7f5bcc8a5ddeeeae3a2aedb8929cf04332ea1"),
):
    path = project / relative
    bits.append({"path": path.relative_to(repo).as_posix(), "bytes": path.stat().st_size,
                 "sha256": sha(path), "expected_sha256": expected, "matches": sha(path) == expected})

groups = {
    "ddr20": (repo / "tmp/sw_edge_flicker_diagnosis_20261005/ddr_review", [
        "tb_ddr_capacity.v", "tb_ddr_tailgap.v", "roi_sobel_view_tailgap.v",
        "diff0s300.console.log", "diff1s300.console.log", "tailgap.console.log", "tailgap.compile.log"]),
    "ddr600": (repo / "tmp/sw_edge_flicker_diagnosis_20261005/full_frame_20261006", [
        "tb_ddr_full.v", "tb_ddr_full_tailgap.v", "compile.log", "compile_failed_sv.log",
        "old_control.console.log", "new_no_stall.console.log", "new_stall.console.log", "tailgap_probe.console.log"]),
    "frame_tail": (repo / "tmp/frame_review_20261005", [
        "tb_tail_clock.v", "tail_console.log", "tail_transcript.log", "tail_wave.wlf"]),
    "physical_ram": (repo / "tmp/sw_edge_ram_diagnosis_20261005", [
        "run.ps1", "extract_ram.py", "extraction_manifest.json", "original_instances.v", "mapped_rgb_ram.v",
        "tb_ram_map.v", "console.log", "compile.log", "make_mapped_sobel.py", "roi_sobel_view_mapped.v",
        "tb_sobel_view.v", "run_mapped_sobel.ps1", "mapped_sobel_manifest.json", "mapped_sobel_console.log"]),
    "display_read": (repo / "tmp/display_underflow_20261006", [
        "诊断记录.md", "tb_video_out_underflow.v", "run.ps1", "run.do", "console.log",
        "video_out_underflow.log", "single_line_firstpass.log"]),
    "diagnosis_scripts": (Path(__file__).resolve().parent, ["run_full_frame_probe.ps1", "freeze_diagnosis.py"]),
}
evidence = []
for name, (original_dir, files) in groups.items():
    destination = record / "evidence" / name
    destination.mkdir(parents=True, exist_ok=True)
    for filename in files:
        source = original_dir / filename
        target = destination / filename
        shutil.copy2(source, target)
        evidence.append({"original_path": source.relative_to(repo).as_posix(),
                         "path": target.relative_to(record).as_posix(), "bytes": target.stat().st_size,
                         "sha256": sha(target), "copy_verified": sha(source) == sha(target)})

for name, original in (
    ("gray_camera_corruption.jpg", "C:/Users/yiziw/AppData/Local/Temp/codex-clipboard-e2239adf-ce6a-4c32-bf3c-315bde2f5ad3.jpg"),
    ("gray_edge_displacement.jpg", "C:/Users/yiziw/AppData/Local/Temp/codex-clipboard-4028d24f-c007-4484-a322-1443b8aab63b.jpg"),
):
    source = Path(original)
    destination = record / "evidence/photos" / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    evidence.append({"original_path": original, "path": destination.relative_to(record).as_posix(),
                     "bytes": destination.stat().st_size, "sha256": sha(destination),
                     "copy_verified": sha(source) == sha(destination)})

document = record / "诊断与修复范围.md"
all_match = all(item["matches"] for item in source_results + bits)
manifest = {
    "date": "2026-10-06", "timezone": "Asia/Shanghai", "scope": "Read-only investigation; temporary diagnostic simulations only",
    "board_acceptance": "failed_video_corruption", "hardware_root_cause_confirmed": False,
    "rtl_modified": False, "new_bitstream_generated": False, "jtag_used": False,
    "repair_scope_awaiting_user_confirmation": True,
    "source_verification": source_results, "bitstreams": bits,
    "evidence": evidence,
    "documents": [{"path": document.name, "sha256": sha(document)}],
    "baseline_and_copies_verified": all_match and all(item["copy_verified"] for item in evidence),
    "limitations": ["DDR capacity test uses a behavioral arbiter, not the actual controller/PHY",
                    "Display underflow is explicitly injected; end-to-end causation not proven",
                    "CSI clock stopping is conditional, not measured on the board",
                    "Standalone physical RAM passed; mapped full-Sobel vopt load failed"],
}
(record / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"source_inputs_checked": len(source_results), "source_matches": all_match,
                  "evidence_files": len(evidence), "copies_verified": all(item["copy_verified"] for item in evidence),
                  "bitstream_matches": all(item["matches"] for item in bits)}, ensure_ascii=False))
if not manifest["baseline_and_copies_verified"]:
    raise SystemExit("Baseline or copy verification mismatch; see manifest.json")
