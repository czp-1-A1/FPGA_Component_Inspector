from pathlib import Path
import hashlib,json,shutil,re
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
prior=root/'tmp/fixed_wb_tuning_r2_td_20261009'
build=root/'tmp/manual_wb_v1_td_20261009'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not build.exists()
baseline=json.loads((prior/'inputs.json').read_text(encoding='utf-8-sig'))
inputs=[]
for e in baseline:
 src=project/e['path'];dst=build/e['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 inputs.append(dict(path=e['path'],bytes=dst.stat().st_size,sha256=sha(dst)))
changed=[e['path'] for e,b in zip(inputs,baseline) if e['sha256']!=b['sha256']]
expected=['awb.v','design_top_wrapper.v','experiment_osd.v','isp/isp_top.v','osd_ascii_rom.v','roi_display_state.v','roi_observation_snapshot.v','uiisp_beta/ae_set.v']
assert set(changed)=={'user_source/hdl_source/'+p for p in expected},changed
stages=[]
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
  shutil.copy2(prior/rel/name,dst/name);stages.append(dict(path=(rel/name).as_posix(),sha256=sha(dst/name)))
 paths=re.findall(r'<File Path="([^"]+)"',(dst/'camera_to_dsi_display.prj').read_text(encoding='utf-8-sig'))
 assert len(paths)==69 and all((dst/p).is_file() for p in paths)
sim=build/'sim';sim.mkdir()
for p in (project/'sim').iterdir():
 if p.is_file() and p.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(p,sim/p.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
dump(build/'inputs.json',inputs);dump(build/'stage_inputs.json',stages)
dump(build/'simulation_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for p in sorted(sim.rglob('*')) if p.is_file()])
dump(build/'preparation.json',dict(baseline=prior.name,changed_production_inputs=changed,source_files=69,
 red_blue_gain_code=dict(default=64,minimum=32,maximum=192,denominator=64),
 frame_boundary='native request snapshot then AWB early SOF hold / first multiplication apply',
 sample_tag='WB 16-bit epoch plus 8-bit red and blue codes; coherent snapshot',
 constraints_unchanged=True,hardware_accuracy_unvalidated=True))
print('PASS isolated manual WB build: 209 inputs, 69 sources, 8 necessary RTL files, unchanged constraints')
