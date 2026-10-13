from pathlib import Path
import hashlib,json,re,shutil
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
prior=root/'tmp/led_presence_demo_v2_r2_td_20261008'
before=root/'tmp/presence_modes_v3_before_20261008'
build=root/'tmp/presence_modes_v3_td_20261008'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert not build.exists()
baseline=json.loads((prior/'inputs.json').read_text(encoding='utf-8-sig'))
al=project/'td_project/camera_to_dsi_display.al'
old_al=(before/'td_project/camera_to_dsi_display.al').read_text(encoding='utf-8')
order=max(map(int,re.findall(r'Name="CompileOrder" Val="(\d+)"',old_al)))+1
text=al.read_text(encoding='utf-8')
for offset,name in enumerate(['roi_mode_classifier.v','roi_tape_guard.v']):
    pattern=r'(<File Path="../user_source/hdl_source/'+re.escape(name)+r'">.*?Name="CompileOrder" Val=")\d+("/>)'
    text,n=re.subn(pattern,lambda m:m[1]+str(order+offset)+m[2],text,flags=re.S)
    assert n==1
al.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
# Preserve existing line-ending conventions; no unchanged RTL is rewritten.
for entry in baseline:
    path=project/entry['path'];old=before/entry['path']
    if path.suffix=='.v' and sha(path)!=entry['sha256']:
        raw=path.read_bytes();newline=b'\r\n' if b'\r\n' in old.read_bytes() else b'\n'
        path.write_bytes(raw.replace(b'\r\n',b'\n').replace(b'\n',newline))
build.mkdir()
relative_inputs=[entry['path'] for entry in baseline]+['user_source/hdl_source/roi_mode_classifier.v','user_source/hdl_source/roi_tape_guard.v']
inputs=[]
for relative in relative_inputs:
    source=project/relative;destination=build/relative
    destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,destination)
    inputs.append({'path':relative,'bytes':destination.stat().st_size,'sha256':sha(destination)})
changes=[entry['path'] for entry in inputs if entry['path'] not in {b['path'] for b in baseline} or entry['sha256']!=next(b['sha256'] for b in baseline if b['path']==entry['path'])]
stages=[]
for stage in ['syn_1','phy_1']:
    relative=Path('td_project/camera_to_dsi_display_Runs')/stage
    destination=build/relative;destination.mkdir(parents=True)
    for name in ['settings.cfg','build.tcl']:
        shutil.copy2(prior/relative/name,destination/name)
    prj=(prior/relative/'camera_to_dsi_display.prj').read_text(encoding='utf-8-sig')
    entry=re.search(r'\s*<File Path="../../../user_source/hdl_source/roi_classifier.v">.*?</File>',prj,re.S)[0]
    prj_order=max(map(int,re.findall(r'Name="CompileOrder" Val="(\d+)"',prj)))+1
    added=''
    for offset,name in enumerate(['roi_mode_classifier.v','roi_tape_guard.v']):
        added+=re.sub(r'Name="CompileOrder" Val="\d+"',f'Name="CompileOrder" Val="{prj_order+offset}"',entry.replace('roi_classifier.v',name))
    prj=prj.replace(entry,added+entry,1)
    (destination/'camera_to_dsi_display.prj').write_text(prj,encoding='utf-8')
    paths=re.findall(r'<File Path="([^"]+)"',prj)
    assert len(paths)==69 and all((destination/path).exists() for path in paths)
    for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
        stages.append({'path':(relative/name).as_posix(),'sha256':sha(destination/name)})
sim=build/'sim';sim.mkdir()
for path in (project/'sim').iterdir():
    if path.is_file() and path.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(path,sim/path.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
dump(build/'inputs.json',inputs);dump(build/'stage_inputs.json',stages)
dump(build/'preparation.json',{'baseline':'led_presence_demo_v2_r2_20261008','input_count':len(inputs),'changed_production_inputs':changes,'project_sources':69,'new_algorithm_thresholds_are_unvalidated':True})
print(json.dumps({'build':str(build),'inputs':len(inputs),'changes':changes}))
