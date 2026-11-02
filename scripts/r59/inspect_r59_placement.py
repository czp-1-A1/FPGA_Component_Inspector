from pathlib import Path
import argparse,hashlib,json,re
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--compare',type=Path);a=p.parse_args();w=a.work
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();load=lambda p:json.loads(p.read_text())
v=load(w/'PLACEMENT_RESULT.json');assert v['status']=='PLACED_ONLY_NOT_ROUTED_NOT_DELIVERABLE'
run=w/'runs/phy_1';assert v['placement_database_sha256']==sha(run/'camera_to_dsi_display_place.db');area=(run/'placed_intermediate.area').read_text();text=(run/'placement_diagnostic.timing').read_text()
resources={n:int(re.search(r'^#'+n+r'\s+(\d+)',area,re.M)[1]) for n in ['slice','eram','dsp','pll']};assert resources['slice']<=21216 and resources['eram']==107 and resources['dsp']==31 and resources['pll']==5
s={n:float(re.search(r'\b'+n+r':\s*([-\d.]+)ns',text)[1]) for n in ['SWNS','HWNS','STNS','HTNS']}
paths={}
for clock in ['pll_clk_100m','u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk','MIPI_RX_BYTE_CLK','HDMI_PIXEL_CLK']:
 group=clock+' -> '+clock;part=text.split('Path Group     :     '+group,1)[1].split('Min Paths',1)[0];d={}
 for field in ['Slack','Begin Point','End Point','Data Path Delay','Logic Level']:
  m=re.search(r'^'+field+r'\s*:\s*(.*)',part,re.M)
  if m:d[field]=m[1]
 paths[clock]=d
r={'status':'PASS_R59_PLACEMENT_RESOURCE_AND_SETUP_NOT_ROUTED' if s['SWNS']>=0 and s['STNS']==0 else 'R59_PLACEMENT_SETUP_NEEDS_STRUCTURAL_REVIEW_NOT_ROUTED','resources':resources,'slice_percent':resources['slice']/21216*100,'eram_percent':resources['eram']/108*100,'timing_ns':s,'critical_paths':paths,'source_manifest_sha256':sha(w/'frozen_inputs.json'),'placement_database_sha256':v['placement_database_sha256'],'placed_timing_sha256':sha(run/'placement_diagnostic.timing'),'placed_area_sha256':sha(run/'placed_intermediate.area'),'scope':'Placed only, hold awaits route; not final acceptance'}
(w/'R59_PLACEMENT_GATE.json').write_text(json.dumps(r,indent=2)+'\n')
if a.compare:
 old=load(a.compare/'R59_PLACEMENT_GATE.json');first=load(a.compare/'frozen_inputs.json');second=load(w/'frozen_inputs.json');delta=[n for n in first if first[n]!=second[n]];assert delta==['user_source/hdl_source/compact_inspector_osd.v'],delta
 for name in ['official_flow_sha256','original_settings_sha256','active_settings_sha256']:
  assert load(w/'STAGE_PLACE.json')[name]==load(a.compare/'STAGE_PLACE.json')[name],name
 comparison={'scope':'Controlled sameDefault/seed4/tool/clock/SDC four-view placement comparison; not Routed timing','changed_files':delta,'slice_delta':resources['slice']-old['resources']['slice'],'SWNS_delta_ns':s['SWNS']-old['timing_ns']['SWNS'],'baseline':old,'candidate':r,'only_one_function_changed_receipt':'CANDIDATE_CHAR_SCOPE.json'}
 (w/'CONTROLLED_PLACEMENT_COMPARISON.json').write_text(json.dumps(comparison,indent=2)+'\n');print(json.dumps({k:comparison[k] for k in ['scope','changed_files','slice_delta','SWNS_delta_ns']},indent=2))
print(json.dumps(r,indent=2))
