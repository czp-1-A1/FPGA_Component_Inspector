"""Read the routed DB; retain every R22 check and add relay mailbox/SW/output checks."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--left-v2',action='store_true');args=a.parse_args()
work=args.work.resolve();project=work/'project';tools=project/'tools';env=dict(os.environ)
env['TEMP']=env['TMP']=str(work/'temp')
audit_names=['classified_audit_routed.tcl','classified_audit_gray_packing.tcl']
for name in audit_names:
 text=(tools/name).read_text()
 text=text.replace('cd td_project/camera_to_dsi_display_Runs/phy_1','cd {'+(work/'runs/phy_1').as_posix()+'}')
 if name=='classified_audit_routed.tcl':
  text=text.replace('foreach box {u_count_command u_count_live_display}', 'foreach box {u_count_command u_count_live_display u_relay_display}')
  text=text.replace('close $bind_fd',r'''
set rf [get_regs {relay_switch_sync\[0\]*}]
set rs [get_regs {relay_switch_sync\[1\]*}]
set rq [get_nets {relay_switch_sync\[0\]*}]
puts $bind_fd "RELAY_SW FIRST_COUNT [llength $rf] SECOND_COUNT [llength $rs] Q_COUNT [llength $rq]"
if {[llength $rf]<1 || [llength $rs]<1 || [llength $rq]<1} {error "Relay SW3 binding missing"}
report_timing_path -from $rf -through $rq -to $rs -ep_num 4096 -path_num 2 -file classified_audit/relay_sw_sync.timing
report_timing_path -from $rf -through $rq -ep_num 4096 -path_num 2 -file classified_audit/relay_sw_fanout.timing
report_timing_path -to [get_ports {O_relay_control}] -ep_num 16 -path_num 2 -file classified_audit/relay_output.timing
close $bind_fd''')
 target=work/name;target.write_text(text)
 with (work/(name+'.log')).open('w',encoding='utf8') as log:
  result=subprocess.run(['E:/TD/bin/td_commands_prompt.exe'],input='source {'+target.as_posix()+'}\n',text=True,cwd=project,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600)
 assert result.returncode==0,(name,str(work/(name+'.log')))
 print('Generated read-only routed reports: '+name,flush=True)

original=(tools/'verify_classified_physical.py').read_text()
updated=original.replace('len(expected) == 44 and len(set(expected)) == 44','len(expected) == 47 and len(set(expected)) == 47')
updated=updated.replace('len(observed) == 46','len(observed) == 49')
updated=updated.replace("for box in ['u_count_command', 'u_count_live_display']:","for box in ['u_count_command', 'u_count_live_display', 'u_relay_display']:")
updated=updated.replace("'new_mailbox_groups': 6","'new_mailbox_groups': 9")
target=work/'verify_relay_physical.py';target.write_text(updated)
sys.path.insert(0,str(tools));namespace={'__name__':'relay_audit_verifier','__file__':str(target)}
exec(compile(updated,str(target),'exec'),namespace)
result=namespace['verify'](project)
folder=project/'classified_audit'
extra={}
for name in ['relay_sw_sync.timing','relay_sw_fanout.timing','relay_output.timing']:
 text=(folder/name).read_text();slacks=re.findall(r'^Slack\s*:\s*([-\d.]+)ns',text,re.M)
 assert slacks and min(map(float,slacks))>=0,(name,slacks)
 extra[name]={'sha256':sha(folder/name),'minimum_slack_ns':min(map(float,slacks))}
direct=(folder/'relay_sw_sync.timing').read_text();fan=(folder/'relay_sw_fanout.timing').read_text()
assert 'relay_switch_sync[0]' in direct and 'relay_switch_sync[1]' in direct
ends=lambda t:set(re.findall(r'^End Point\s*:\s*(\S+)',t,re.M))
assert ends(direct) and ends(direct)==ends(fan),'Relay SW first stage fanout escapes second stage'
area=(work/'runs/phy_1/final.area').read_text()
assert re.search(r'O_relay_control\s+OUTPUT\s+V2\s+LVCMOS33\s+HDIO\s+4\s+PULLDOWN',area)
assert 'O_led' not in area
resources={key:int(re.search(r'^#'+key+r'\s+(\d+)',area,re.M)[1]) for key in ['slice','eram','dsp','pll']}
expected_eram,expected_dsp=(99,30) if args.left_v2 else (101,27)
assert resources['slice']<=21216 and resources['eram']==expected_eram and resources['dsp']==expected_dsp and resources['pll']==5
if args.left_v2:
 assert 'RELAY_LEFT_LAYOUT=1' in (project/'user_source/hdl_source/design_top_wrapper.v').read_text()
 assert '.WIDTH(64)) u_relay_display' in (project/'user_source/hdl_source/design_top_wrapper.v').read_text()
source=json.loads((work/'frozen_inputs.json').read_text())
for name,digest in source.items():assert sha(project/name)==digest,('Frozen source changed',name)
result.update({'status':'PASS_R22_RELAY_ROUTED_ALL_49_BOUNDS_20_GRAY_9_MAILBOX_GROUPS_SW3_V2_NO_LED',
 'resources':resources,'slice_percent':round(resources['slice']/21216*100,5),'slice_delta_vs_r22':resources['slice']-19016,
 'extra_relay_checks':extra,'bit_sha256':sha(work/'runs/phy_1/camera_to_dsi_display.bit'),
 'baseline_physical_verifier_sha256':sha(tools/'verify_classified_physical.py'),
 'adapted_physical_verifier_sha256':sha(target),'board_acceptance':False})
if args.left_v2:result['layout']='left refill / right count; gray cache48..847 x224..415; ERAM99/DSP30 (gray cache-3 ERAM, P/E history+1 ERAM)'
(work/'physical_verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['status','timing_ns','resources','slice_delta_vs_r22','max_delays_matched','max_delays_ignored','gray_bits_dominating']},indent=2),flush=True)
