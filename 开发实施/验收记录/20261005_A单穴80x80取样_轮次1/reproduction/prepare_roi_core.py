from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];project=root/'fpga/component_inspector'
build=root/'tmp/roi_core_td_build_20261005'
old_build=root/'tmp/roi_classifier_final_td_build_20261004'
previous=json.loads((project/'release/roi_classifier_20261004/manifest.json').read_text(encoding='utf-8'))
assert not build.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
changes=[]
for entry in previous['verified_build_inputs']:
    relative=entry['path'];source=project/relative
    if sha(source)!=entry['sha256']:changes.append(relative)
    target=build/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
assert set(changes)=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/experiment_osd.v'},changes
relative='td_project/camera_to_dsi_display.al'
assert sha(project/relative)==previous['project_sha256']
shutil.copy2(project/relative,build/relative)
for stage in ['syn_1','phy_1']:
    dst=build/'td_project/camera_to_dsi_display_Runs'/stage;dst.mkdir(parents=True)
    src=old_build/'td_project/camera_to_dsi_display_Runs'/stage
    for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:shutil.copy2(src/name,dst/name)
print('Isolated full 198-input project prepared. Exactly three RTL inputs changed; constraints and project unchanged.')
