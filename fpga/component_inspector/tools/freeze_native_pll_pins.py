"""Freeze independent true-PLL serial phase probe; do not build/change a bit."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess
engine=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('destination',type=Path);args=ap.parse_args()
dest=args.destination.resolve()
if dest.exists():raise SystemExit('Refusing existing destination')
sources=['diagnostics/hdmi_positive/avi_fhd30_top.v','diagnostics/hdmi_positive/hdmi_avi_insert.v',
 'diagnostics/hdmi_positive/dvi_encoder.v','user_source/hdl_source/native_hdmi_pll.v',
 'user_source/ip_source/PLL/RTL/ph1p_phy_pll_wrapper_25a56e5ce2f9.v',
 'user_source/hdl_source/hdmi_phy_warpper.v','user_source/hdl_source/lane_lvds_10_1.v']
inputs=sources+['sim/tb_native_pll_pins.v','sim/hdmi_decode.vh','sim/run_native_pll_pins.ps1',
 'tools/freeze_native_pll_pins.py']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((engine/'release/native_1080p30/hdmi_avi_diagnostic_20261009/input_snapshot.json').read_text())
for rel in sources:
 assert sha(engine/rel)==next(e['sha256'] for e in old['inputs'] if e['path']==rel),rel
manifest=[]
for rel in inputs:
 p=dest/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(engine/rel,p)
 manifest.append(dict(path=rel,sha256=sha(p),bytes=p.stat().st_size))
models=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v','ph1p/ph1p_logic_hrio.v','ph1p/ph1p_phy_hr_pad.v']
(dest/'freeze.json').write_text(json.dumps(dict(
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=engine.parents[1],text=True).strip(),
 bound_d_bit_sha256='2a22cc98b9538c80cda6ae1e80b4d8272984ab1277710eb269f3d8953c6e6172',
 purpose='Unmodified D, native vendor PLL/ODDR startup and16 serial active rows; no new bit or physical acceptance',
 inputs=manifest,vendor_models=[dict(path='D:/td6.2.1/sim_release/'+m,
 sha256=sha(Path('D:/td6.2.1/sim_release')/m)) for m in models]),indent=2)+'\n')
print(dest)
