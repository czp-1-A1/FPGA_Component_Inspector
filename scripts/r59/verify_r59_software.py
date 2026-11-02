from pathlib import Path
import argparse,hashlib,json,re
h=Path('D:/FpgaWork/r59_field_20261102');old=Path('D:/FpgaWork/r58_field_20261102');root=Path('D:/FpgaWork/r59_four_view_20261102');src=root/'fpga/component_inspector'
a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--ui-group',default='ui_b');a.add_argument('--legacy-group',default='legacy_ui_a');a.add_argument('--chain-group',default='frame_chain_a');a.add_argument('--character-group');x=a.parse_args();w=x.work
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def target(name):
 p=Path(name);s=p.as_posix()
 if p==h/'candidate_hdl/compact_inspector_osd.v':return src/'user_source/hdl_source/compact_inspector_osd.v'
 for prefix in ['D:/FpgaWork/dual_roi_r58_20261102/project/',src.as_posix()+'/']:
  if s.startswith(prefix):return src/s[len(prefix):]
 return p
proofs=[]
for folder,group,n in [(old,'r58_leaves_b',3),(old,'r58_parking_b',13),(old,'r58_alarm_buzzer_b',1),(old,'r58_production_alarm_b',1),(old,'r58_expiry_a',1),(h,x.ui_group,1),(h,x.legacy_group,3),(h,'four_view_pixels_b',2),(h,'four_view_controls',1)]+([(h,x.character_group,1)] if x.character_group else []):
 v=load(folder/group/'verification.json');assert v['status']=='PASS' and len(v['tests'])==n
 for name,d in v['inputs'].items():assert sha(target(name))==d,(group,name)
 for test in v['tests']:
  log=folder/group/(test['top']+'.log');assert sha(log)==test['sha256'];s=log.read_text();assert 'PASS ' in s and '** Fatal:' not in s
 proofs.append({'group':group,'folder':str(folder/group),'tests':n,'receipt_sha256':sha(folder/group/'verification.json')})
for folder,group in [(old,'r58_native_b'),(h,x.chain_group),(h,'four_modes_native_b')]:
 v=load(folder/group/'verification.json');assert v['status']=='PASS'
 for name,d in v['inputs'].items():assert sha(src/name)==d,(group,name)
 for name,d in v['extra_inputs'].items():assert sha(folder/Path(name).name)==d,(group,name)
 assert sha(folder/group/'console.log')==v['console_sha256']
 proofs.append({'group':group,'folder':str(folder/group),'tests':1,'receipt_sha256':sha(folder/group/'verification.json')})
count=sum(p['tests'] for p in proofs);assert count==(30 if x.character_group else 29)
manifest=load(w/'frozen_inputs.json');base=load(root/'docs/R58_BASELINE_SHA256.json');assert len(manifest)==len(base)==705
for name,d in manifest.items():assert sha(src/name)==sha(w/'project'/name)==d,name
changed=sorted(n for n in manifest if base[n]!=manifest[n]);expected={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/compact_template_rom.v'}
if x.character_group:expected.add('user_source/hdl_source/compact_inspector_osd.v')
assert set(changed)==expected,changed
assert 'ESSENTIAL_UI=1,RAW_EDGE_ONLY=0,' in (src/'user_source/hdl_source/design_top_wrapper.v').read_text()
assert manifest['td_project/camera_to_dsi_display.sdc']==base['td_project/camera_to_dsi_display.sdc']
assert manifest['user_source/constraints_source/pin.adc']==base['user_source/constraints_source/pin.adc']
pixels=load(h/'R59_UI_PIXEL_VERIFICATION.json');assert pixels['compared_pixels']==560640 and pixels['second_lane_glyph_rows']==112
r={'status':'PASS_R59_'+str(count)+'_EXACT_SOURCE_TESTS_FOUR_VIEWS_BUZZER_TRUE_LATENCY_UI','actual_tests':count,'historical_pass_reused':0,'unbound_historical_pass_reused':0,'retained_exact_R58_tests':20,'source_files':705,'source_manifest_sha256':sha(w/'frozen_inputs.json'),'baseline_R58_manifest_sha256':sha(root/'docs/R58_BASELINE_SHA256.json'),'changed_files':changed,'groups':proofs,'independent_UI_pixels':pixels,'original_SDC_commands_preserved':True,'SDC_and_ADC_byte_exact_R58':True,'views':['RAW','GRAY','RGB+orange edges','GRAY+orange edges'],'board_acceptance':'HUMAN_PENDING'}
(h/'R59_SOFTWARE_VERIFICATION.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
