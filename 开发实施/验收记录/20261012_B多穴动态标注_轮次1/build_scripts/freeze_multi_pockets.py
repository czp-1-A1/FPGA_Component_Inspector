from pathlib import Path
import json,hashlib,shutil,sys
r=Path(__file__).resolve().parent.parent;p=r/'fpga/component_inspector';prior=r/'tmp/hole_transition_r1_td_20261012'
name=sys.argv[1] if len(sys.argv)>1 else 'multi_pocket_r1_td_20261012'
build=r/'tmp'/name;assert not build.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,data):p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inputs=json.loads((prior/'inputs.json').read_text(encoding='utf-8-sig'))
inputs.append({'path':'user_source/hdl_source/multi_pocket_detector.v'})
changed=[]
for e in inputs:
 src=p/e['path'];dst=build/e['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 if e.get('sha256')!=sha(src):changed.append(e['path'])
 e.update(sha256=sha(dst),bytes=dst.stat().st_size)
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for n in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
  shutil.copy2(prior/rel/n,dst/n)
 q=dst/'camera_to_dsi_display.prj';s=q.read_text(encoding='utf-8-sig')
 marker='            <File Path="../../../user_source/hdl_source/tape_hole_tracker.v">'
 block='''            <File Path="../../../user_source/hdl_source/multi_pocket_detector.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="120"/>
                </FileInfo>
            </File>
'''
 assert marker in s;q.write_text(s.replace(marker,block+marker),encoding='utf-8')
sim=build/'sim';sim.mkdir()
for q in (p/'sim').iterdir():
 if q.is_file() and q.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(q,sim/q.name)
shutil.copytree(p/'sim/osd_assets',sim/'osd_assets')
dump(build/'inputs.json',inputs);dump(build/'changed_inputs.json',changed)
dump(build/'simulation_inputs.json',[dict(path=q.relative_to(build).as_posix(),sha256=sha(q)) for q in sim.rglob('*') if q.is_file()])
dump(build/'stage_inputs.json',[dict(path=q.relative_to(build).as_posix(),sha256=sha(q)) for stage in ['syn_1','phy_1'] for q in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir() if q.is_file()])
text=(r/'tmp/run_hole_transition_build_20261012.ps1').read_text(encoding='utf-8-sig')
(r/'tmp'/('run_'+name+'.ps1')).write_text(text.replace('hole_transition_r1_td_20261012',name),encoding='utf-8-sig')
print(name, len(inputs),changed)
