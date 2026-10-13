from pathlib import Path
import hashlib,json,shutil,re,sys
root=Path(__file__).resolve().parent.parent
p=root/'fpga/component_inspector'
prior=root/'tmp/manual_wb_v1_td_20261009'
build=root/('tmp/dynamic_tracking_v1_'+(sys.argv[1] if len(sys.argv)>1 else 'r1')+'_td_20261010')
assert not build.exists()
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
old=json.loads((prior/'inputs.json').read_text(encoding='utf-8-sig'))
paths=[e['path'] for e in old]+['user_source/hdl_source/tape_hole_tracker.v']
inputs=[]
for rel in paths:
 src=p/rel;dst=build/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 inputs.append(dict(path=rel,bytes=dst.stat().st_size,sha256=sha(dst)))
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
  shutil.copy2(prior/rel/name,dst/name)
 f=dst/'camera_to_dsi_display.prj';s=f.read_text(encoding='utf-8-sig')
 entry=re.search(r'            <File Path="../user_source/hdl_source/tape_hole_tracker.v">.*?</File>',(p/'td_project/camera_to_dsi_display.al').read_text(encoding='utf-8-sig'),re.S).group()
 s=s.replace('        <Verilog>','        <Verilog>\n'+entry.replace('../user_source','../../../user_source'),1)
 f.write_text(s,encoding='utf-8')
 for relsrc in re.findall(r'<File Path="([^"]+)"',s):assert (dst/relsrc).is_file(),relsrc
sim=build/'sim';sim.mkdir()
for f in (p/'sim').iterdir():
 if f.is_file() and f.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(f,sim/f.name)
shutil.copytree(p/'sim/osd_assets',sim/'osd_assets')
(build/'inputs.json').write_text(json.dumps(inputs,indent=2),encoding='utf-8')
(build/'simulation_inputs.json').write_text(json.dumps([dict(path=f.relative_to(build).as_posix(),sha256=sha(f)) for f in sim.rglob('*') if f.is_file()],indent=2),encoding='utf-8')
print('Frozen tracking candidate:',build,'inputs',len(inputs),'sources',len(re.findall(r'<File Path=',s)))
