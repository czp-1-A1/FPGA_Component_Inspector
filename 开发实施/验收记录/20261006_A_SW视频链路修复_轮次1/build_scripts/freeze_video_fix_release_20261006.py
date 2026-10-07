from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, re, shutil, subprocess

root=Path('.').resolve(); project=root/'fpga/component_inspector'
build=root/'tmp/video_fix_td_after_sof_20261006'
release=project/'release/video_fix_20261006'
record=root/'开发实施/验收记录/20261006_A_SW视频链路修复_轮次1'
assert not release.exists() and not record.exists(), 'Never overwrite a frozen release'
phy=build/'td_project/camera_to_dsi_display_Runs/phy_1'
bit=phy/'camera_to_dsi_display.bit'
assert (phy/'.bitgen.end.f').exists() and bit.stat().st_size==1789539
flow=(phy/'route_flow.status').read_text(encoding='utf-8',errors='replace')
assert 'Timing Mode      : final' in flow
setup=re.search(r'Setup\s*: WNS\s+(-?\d+)ps\s+TNS\s+(-?\d+)ps',flow)
hold=re.search(r'Hold\s*: WNS\s+(-?\d+)ps\s+TNS\s+(-?\d+)ps',flow)
assert setup and hold and int(setup[1])>=0 and int(hold[1])>=0 and int(setup[2])==0 and int(hold[2])==0
qor=(phy/'route.qor').read_text(encoding='utf-8',errors='replace')
timing=(phy/'final_timing.rpt').read_text(encoding='utf-8',errors='replace')
coverage=(phy/'constraint_coverage.txt').read_text(encoding='utf-8',errors='replace')
for check in ['no clock(0)','invalid constraint(0)','no path constraints(0)','combinational loops(0)']:
 assert check in coverage,check
budgets=[line.strip() for line in coverage.splitlines() if 'set_max_delay' in line and ('u_transport_display/' in line or 'u_overflow_display/' in line)]
assert len(budgets)==6
for line in budgets:
 values=re.match(r'(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+',line)
 assert values and int(values[1])>0 and int(values[3])==0 and int(values[4])==0,line

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def passed(log,marker):
 s=log.read_text(encoding='utf-8',errors='replace')
 assert marker in s and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',s),str(log)
 return [line for line in s.splitlines() if 'PASS' in line]

extra=[]
proof=root/'tmp/roi_proof_after_sof_20261006'
extra.append({'path':str((proof/'roi_console.log').relative_to(root)), 'pass_lines':passed(proof/'roi_console.log','PASS actual ISP transport proof:')})
transport=root/'tmp/transport_resume_verify_20261006'
for mode in range(4):
 log=transport/f'mode_{mode}.console.log'
 rows=passed(log,'PASS: FULL_TRANSPORT')
 assert any('writes=230400' in s and 'pixels=1228800' in s for s in rows)
 extra.append({'path':str(log.relative_to(root)), 'pass_lines':rows})
for name,marker in [('faults.console.log','PASS:'),('pre_sof_four_modes.console.log','PASS')]:
 log=transport/name
 extra.append({'path':str(log.relative_to(root)), 'pass_lines':passed(log,marker)})
awb=root/'tmp/awb_epoch_verify_20261006'
assert (awb/'README.md').exists() and (awb/'manifest.json').exists()
awb_manifest=json.loads((awb/'manifest.json').read_text(encoding='utf-8-sig'))
for entry in awb_manifest:
 assert sha(awb/entry['RelativePath'])==entry['SHA256'],entry['RelativePath']
extra.append({'path':str((awb/'fixed/console.log').relative_to(root)),
 'pass_lines':passed(awb/'fixed/console.log','PASS real AWB epoch isolation:')})
legacy=(awb/'legacy_contract/console.log').read_text(encoding='utf-8',errors='replace')
assert '** Fatal: new early epoch accepts old AWB tail mode=0' in legacy
assert 'PASS real AWB epoch isolation:' not in legacy
for entry in json.loads((awb/'fixed/inputs.json').read_text(encoding='utf-8-sig')):
 assert sha(Path(entry['Path']))==entry['SHA256'],entry['Path']

base_results=[]
runner=(project/'sim/run_modelsim.ps1').read_text(encoding='utf-8-sig')
for name,marker in re.findall(r'Name="([^"]+)"; Pass="([^"]+)"',runner):
 log=project/'sim/modelsim_work'/name/'console.log'
 base_results.append({'name':name,'path':str(log.relative_to(root)),
  'pass_lines':passed(log,marker),'log_sha256':sha(log),
  'scope':'latest source rerun' if name=='sobel_view' else
   'earlier pass; latest actual ISP proof supersedes ROI chain' if name=='roi_chain' else
   'pass; RTL dependency closure unchanged since test'})
assert len(base_results)==16
proof_log=(proof/'roi_console.log').read_text(encoding='utf-8',errors='replace')
proof_warning_codes={code:len(re.findall(r'\('+code+r'\)',proof_log))
 for code in ['vopt-2241','vopt-2685','vopt-2697','vopt-2718']}

inputs=json.loads((build/'inputs.json').read_text(encoding='utf-8'))
for e in inputs: assert sha(project/e['path'])==e['sha256'],e['path']
assert re.search(r'CLASS_CALIBRATED\s*=\s*0\s*;', (project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf-8'))
for entry in json.loads((proof/'roi_proof_inputs_manifest.json').read_text(encoding='utf-8-sig')):
 assert sha(Path(entry['Path']))==entry['SHA256'],entry['Path']
for entry in json.loads((transport/'tested_inputs.json').read_text(encoding='utf-8-sig')):
 assert sha(root/entry['path'])==entry['sha256'],entry['path']
for name,expected in [('sample_ui_20261005','ab23766b4b51c4df1d331fc14ad7f5bcc8a5ddeeeae3a2aedb8929cf04332ea1'),('sw_edge_20261005','a43156b8fc076d7940e12b8f7ba46d026a3053466b759724bef79235570bcd8c')]:
 assert sha(project/'release'/name/bit.name)==expected

record.mkdir(parents=True); release.mkdir(parents=True)
copies=[]
def copy(src,dest):
 dst=record/dest;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 assert sha(src)==sha(dst)
 copies.append({'source':str(src.relative_to(root)).replace('\\','/'),'copy':str(dst.relative_to(record)).replace('\\','/'),'bytes':dst.stat().st_size,'sha256':sha(dst)})
for e in inputs: copy(project/e['path'],Path('source_snapshot')/e['path'])
copy(build/'inputs.json','build_inputs.json')
for file in build.rglob('*.tcl'):
 if 'source_snapshot' not in file.parts:
  copy(file,Path('build_scripts')/file.relative_to(build))
for name in ['prepare_video_fix_build.py','freeze_video_fix_release_20261006.py']:
 copy(root/'tmp'/name,Path('build_scripts')/name)
for stage in ['syn_1','phy_1']:
 for file in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir():
  if file.is_file() and file.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit'}:
   copy(file,Path('td_reports')/stage/file.name)
sim=project/'sim'
for file in sim.iterdir():
 if file.is_file() and file.suffix.lower() in {'.v','.ps1','.py','.do','.md','.log'}:
  copy(file,Path('simulation')/file.name)
for file in (sim/'osd_assets').rglob('*'):
 if file.is_file(): copy(file,Path('simulation/osd_assets')/file.relative_to(sim/'osd_assets'))
for file in (sim/'modelsim_work').rglob('*.log'):
 copy(file,Path('simulation/model_logs')/file.relative_to(sim/'modelsim_work'))
for folder in [proof,transport,awb,root/'tmp/pre_sof_fix_20261006',root/'tmp/io_fix_review_20261006',root/'tmp/sobel_fix_review_20261006']:
 for file in folder.rglob('*'):
  if file.is_file() and file.suffix.lower() in {'.v','.sv','.ps1','.py','.md','.json','.log','.csv'}:
   copy(file,Path('additional_tests')/folder.name/file.relative_to(folder))
shutil.copy2(bit,release/bit.name);assert sha(bit)==sha(release/bit.name)
for name,expected in [('sample_ui_20261005','ab23766b4b51c4df1d331fc14ad7f5bcc8a5ddeeeae3a2aedb8929cf04332ea1'),('sw_edge_20261005','a43156b8fc076d7940e12b8f7ba46d026a3053466b759724bef79235570bcd8c')]:
 assert sha(project/'release'/name/bit.name)==expected
metrics={'setup_wns_ns':int(setup[1])/1000,'setup_tns_ns':int(setup[2])/1000,
 'hold_wns_ns':int(hold[1])/1000,'hold_tns_ns':int(hold[2])/1000,
 'slices':int(re.search(r'#slices\s*\|\s*(\d+)',qor)[1]),
 'slices_percent':float(re.search(r'slices percentage\s*\|\s*([\d.]+)%',qor)[1]),
 'eram':int(re.search(r'#RAMs\s*\|\s*(\d+)',qor)[1]),'dsp':int(re.search(r'#DSPs\s*\|\s*(\d+)',qor)[1]),
 'sta_coverage':re.search(r'STA coverage\s*:\s*([\d.]+%)',timing)[1], 'new_mailbox_budgets':budgets}
data={'created_at':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),
 'status':'candidate_software_verified_board_validation_pending', 'branch':subprocess.check_output(['git','branch','--show-current'],text=True).strip(),
 'HEAD':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(), 'commit_status':'uncommitted_unpushed_workspace_snapshot',
 'tool':'TD 6.2.168116 / ModelSim 2019.2','device':'PH1P35MDG324 speed3','classification_enabled':False,
 'bit':{'path':str((release/bit.name).relative_to(root)).replace('\\','/'),'bytes':bit.stat().st_size,'sha256':sha(bit)},
 'build_directory':str(build.relative_to(root)).replace('\\','/'),'build_inputs':inputs,'metrics':metrics,
 'test_results':extra,'base_test_results':base_results,'awb_manifest':awb_manifest,'copies':copies,
 'actual_isp_warning_codes':proof_warning_codes,
 'limits':['No board/JTAG validation','DDR MC behavioral model does not validate physical DDR PHY',
 'Static optics/material classification not calibrated','Vendor PLL/IO/exception constraint warnings retained']}
(record/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(release/'manifest.json').write_text(json.dumps({k:v for k,v in data.items() if k not in ['copies','awb_manifest']},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(release/'build_inputs.json').write_text(json.dumps(inputs,indent=2)+'\n',encoding='utf-8')
(release/'SHA256.txt').write_text(f'{sha(bit)}  {bit.name}\n',encoding='ascii')
print(json.dumps({'release':str(release),'record':str(record),'bit':data['bit'],'metrics':metrics,'verified_copies':len(copies)},ensure_ascii=True))
