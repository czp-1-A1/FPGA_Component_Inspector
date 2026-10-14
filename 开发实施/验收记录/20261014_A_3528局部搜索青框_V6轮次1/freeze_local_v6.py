from pathlib import Path
import json,hashlib,shutil,sys
r=Path.cwd();p=r/'fpga/component_inspector';prior=r/'tmp/shape_v5_r4_20261013';dst=r/'tmp'/sys.argv[1];assert not dst.exists();dst.mkdir()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();inputs=json.loads((prior/'inputs.json').read_text(encoding='utf-8'));inputs.append(dict(path='user_source/hdl_source/roi_shape_search.v'))
for e in inputs:
 out=dst/e['path'];out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p/e['path'],out);e.update(sha256=sha(out),bytes=out.stat().st_size)
sim=dst/'sim';sim.mkdir()
for f in (p/'sim').iterdir():
 if f.is_file() and f.suffix in {'.v','.ps1','.py','.do','.md'}:shutil.copy2(f,sim/f.name)
shutil.copytree(p/'sim/osd_assets',sim/'osd_assets')
for stage in ['syn_1','phy_1']:
 base=Path('td_project/camera_to_dsi_display_Runs')/stage;out=dst/base;out.mkdir(parents=True)
 for name in ['build.tcl','settings.cfg','camera_to_dsi_display.prj']:shutil.copy2(prior/base/name,out/name)
 f=out/'camera_to_dsi_display.prj';s=f.read_text(encoding='utf-8-sig');s=s.replace('        <Verilog>', '''        <Verilog>
            <File Path="../../../user_source/hdl_source/roi_shape_search.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="122"/></FileInfo></File>''');f.write_text(s,encoding='utf-8')
(dst/'inputs.json').write_text(json.dumps(inputs,indent=2),encoding='utf-8');(dst/'simulation_inputs.json').write_text(json.dumps([dict(path=f.relative_to(dst).as_posix(),sha256=sha(f)) for f in sim.rglob('*') if f.is_file()],indent=2),encoding='utf-8');print('Frozen',len(inputs),dst)
