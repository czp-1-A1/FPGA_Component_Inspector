"""Freeze the exact pre-factor display resampler as a test oracle."""
from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1];t=r/'tests/dual_stop_d3'
p=Path('E:/2026FPGA/.codex_tmp/d3_dual_stop_build_r11_resource_opt_20261030/project/user_source/hdl_source/rgb_resize_2_3.v')
raw=p.read_bytes();target=t/'r11_reference_rgb_resize_2_3.sv';assert not target.exists()
target.write_bytes(raw.replace(b'module rgb_resize_2_3 #',b'module r11_reference_rgb_resize_2_3 #',1))
(r/'docs/D3_RESIZE_REFERENCE.json').write_text(json.dumps({'source':str(p),'raw_sha256':hashlib.sha256(raw).hexdigest(),'reference':str(target),'reference_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'changes':'Only module name.'},indent=2)+'\n')
