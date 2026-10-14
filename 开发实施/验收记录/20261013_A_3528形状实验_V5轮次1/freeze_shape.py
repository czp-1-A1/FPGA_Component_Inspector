from pathlib import Path
import json,hashlib,shutil,sys
root=Path.cwd();project=root/'fpga/component_inspector';prior=root/'tmp/direct_detection_v4_r3_20261013';build=root/'tmp'/sys.argv[1]
assert not build.exists();build.mkdir()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=json.loads((prior/'inputs.json').read_text(encoding='utf-8-sig'));inputs.append({'path':'user_source/hdl_source/roi_shape_model.v'})
for e in inputs:
 src=project/e['path'];dst=build/e['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst);e.update(sha256=sha(dst),bytes=dst.stat().st_size)
sim=build/'sim';sim.mkdir()
for p in (project/'sim').iterdir():
 if p.is_file() and p.suffix in {'.v','.ps1','.py','.md','.do'}:shutil.copy2(p,sim/p.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:shutil.copy2(prior/rel/name,dst/name)
 p=dst/'camera_to_dsi_display.prj';s=p.read_text(encoding='utf-8-sig');s=s.replace('        <Verilog>', '''        <Verilog>
            <File Path="../../../user_source/hdl_source/roi_shape_model.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="121"/></FileInfo>
            </File>''');p.write_text(s,encoding='utf-8')
(build/'inputs.json').write_text(json.dumps(inputs,indent=2),encoding='utf-8')
(build/'simulation_inputs.json').write_text(json.dumps([{'path':p.relative_to(build).as_posix(),'sha256':sha(p)} for p in sim.rglob('*') if p.is_file()],indent=2),encoding='utf-8')
print('Frozen',len(inputs),build)
