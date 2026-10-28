"""Read the routed DB; retain every R22 check and add relay mailbox/SW/output checks."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--left-v2',action='store_true');a.add_argument('--keys-v3',action='store_true');a.add_argument('--adjacent-v6',action='store_true');a.add_argument('--five-empty-v7',action='store_true');args=a.parse_args()
work=args.work.resolve();project=work/'project';tools=project/'tools';env=dict(os.environ)
env['TEMP']=env['TMP']=str(work/'temp')
audit_names=['classified_audit_routed.tcl','classified_audit_gray_packing.tcl']
for name in audit_names:
 text=(tools/name).read_text()
 text=text.replace('cd td_project/camera_to_dsi_display_Runs/phy_1','cd {'+(work/'runs/phy_1').as_posix()+'}')
 if name=='classified_audit_routed.tcl':
  text=text.replace('foreach box {u_count_command u_count_live_display}', 'foreach box {u_count_command u_count_live_display u_relay_display}')
  if args.keys_v3:
   text=text.replace('close $bind_fd',r'''
for {set bit 0} {$bit<4} {incr bit} {
 set rf [get_regs [format {*count_controls*controls/button_meta\[%d\]*} $bit]]
 set rs [get_regs [format {*count_controls*controls/button_sync\[%d\]*} $bit]]
 set rq [get_nets [format {*count_controls*controls/button_meta\[%d\]*} $bit]]
 puts $bind_fd "KEY_SYNC $bit FIRST_COUNT [llength $rf] SECOND_COUNT [llength $rs] Q_COUNT [llength $rq]"
 if {[llength $rf]<1 || [llength $rs]<1 || [llength $rq]<1} {error "Key synchronizer binding missing"}
 report_timing_path -from $rf -through $rq -to $rs -ep_num 4096 -path_num 2 -file classified_audit/key_${bit}_sync.timing
 report_timing_path -from $rf -through $rq -ep_num 4096 -path_num 2 -file classified_audit/key_${bit}_fanout.timing
}
report_timing_path -to [get_ports {O_relay_control}] -ep_num 16 -path_num 2 -file classified_audit/relay_output.timing
close $bind_fd''')
  else:
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
 if name=='classified_audit_routed.tcl' and args.five_empty_v7:
  text=text.replace('close $bind_fd',r'''
set alarm_regs [get_regs {*left_station*controller/alarm_latched*}]
set motor_regs [get_regs {motor_output*}]
puts $bind_fd "V7_ALARM_MOTOR SOURCE_COUNT [llength $alarm_regs] DESTINATION_COUNT [llength $motor_regs]"
if {[llength $alarm_regs]<1 || [llength $motor_regs]<1} {error "V7 alarm/motor FF missing"}
report_timing_path -from $alarm_regs -to $motor_regs -ep_num 4096 -path_num 2 -file classified_audit/alarm_motor_interlock.timing
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
extra_names=['relay_output.timing']
if args.five_empty_v7:extra_names+=['alarm_motor_interlock.timing']
if args.keys_v3:
 extra_names+=[f'key_{i}_{kind}.timing' for i in range(4) for kind in ['sync','fanout']]
else:extra_names+=['relay_sw_sync.timing','relay_sw_fanout.timing']
ends=lambda t:set(re.findall(r'^End Point\s*:\s*(\S+)',t,re.M))
for name in extra_names:
 text=(folder/name).read_text();slacks=re.findall(r'^Slack\s*:\s*([-\d.]+)ns',text,re.M)
 assert slacks and min(map(float,slacks))>=0,(name,slacks)
 extra[name]={'sha256':sha(folder/name),'minimum_slack_ns':min(map(float,slacks))}
if args.keys_v3:
 for bit in range(4):
  direct=(folder/f'key_{bit}_sync.timing').read_text();fan=(folder/f'key_{bit}_fanout.timing').read_text()
  assert f'button_meta[{bit}]' in direct and f'button_sync[{bit}]' in direct
  assert ends(direct) and ends(direct)==ends(fan),('Key first stage fanout escapes second stage',bit)
 bindings=(folder/'bindings.txt').read_text()
 m=re.search(r'COUNT_CDC_BIND u_count_command payload SOURCE_COUNT (\d+) DESTINATION_COUNT (\d+)',bindings)
 assert m and int(m[1])>=20 and int(m[2])>=20,('20-bit RUN + motor mode mailbox not bound',bindings)
else:
 direct=(folder/'relay_sw_sync.timing').read_text();fan=(folder/'relay_sw_fanout.timing').read_text()
 assert 'relay_switch_sync[0]' in direct and 'relay_switch_sync[1]' in direct
 assert ends(direct) and ends(direct)==ends(fan),'Relay SW first stage fanout escapes second stage'
area=(work/'runs/phy_1/final.area').read_text()
assert re.search(r'O_relay_control\s+OUTPUT\s+V2\s+LVCMOS33\s+HDIO\s+4\s+PULLDOWN',area)
assert 'O_led' not in area
resources={key:int(re.search(r'^#'+key+r'\s+(\d+)',area,re.M)[1]) for key in ['slice','eram','dsp','pll']}
expected_eram,expected_dsp=(98,30) if args.keys_v3 else (99,30) if args.left_v2 else (101,27)
assert resources['slice']<=21216 and resources['eram']==expected_eram and resources['dsp']==expected_dsp and resources['pll']==5
if args.left_v2 or args.keys_v3:
 assert 'RELAY_LEFT_LAYOUT=1' in (project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
 width=163 if args.adjacent_v6 else 64
 assert f'.WIDTH({width})) u_relay_display' in (project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
source=json.loads((work/'frozen_inputs.json').read_text())
for name,digest in source.items():assert sha(project/name)==digest,('Frozen source changed',name)
result.update({'status':'PASS_R22_RELAY_ROUTED_ALL_49_BOUNDS_20_GRAY_9_MAILBOX_GROUPS_SW3_V2_NO_LED',
 'resources':resources,'slice_percent':round(resources['slice']/21216*100,5),'slice_delta_vs_r22':resources['slice']-19016,
 'extra_relay_checks':extra,'bit_sha256':sha(work/'runs/phy_1/camera_to_dsi_display.bit'),
 'baseline_physical_verifier_sha256':sha(tools/'verify_classified_physical.py'),
 'adapted_physical_verifier_sha256':sha(target),'board_acceptance':False})
if args.left_v2 or args.keys_v3:result['layout']='left refill / right count; gray cache48..847 x224..415; ERAM99/DSP30 (gray cache-3 ERAM, P/E history+1 ERAM)'
if args.keys_v3:
 result['status']='PASS_R22_RELAY_V3_ROUTED_ALL_49_BOUNDS_20_GRAY_9_MAILBOX_GROUPS_SW3_4_KEYS_V2_NO_LED'
 result['layout']='left refill / right count; ERAM98/DSP30; fixed camera gain40 removes SC500GainTbl ROM (V2 gain_tbl1ERAM, V3 gain_tbl0); classifier and kind history retained'
 result['control_mailbox_bits']=20
 result['relay_output_registered']=True
 assert 'reg motor_output;' in (project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
if args.adjacent_v6:
 assert args.keys_v3
 assert 'ADJACENT_V6=1,' in (project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
 result['relay_display_declared_bits']=163
 result['status']='PASS_R22_RELAY_V6_ROUTED_ALL_49_BOUNDS_20_GRAY_9_MAILBOX_GROUPS_SW3_4_KEYS_V2_NO_LED'
if args.five_empty_v7:
 assert args.adjacent_v6 and args.keys_v3
 top=(project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
 assert 'FIVE_EMPTY_V7=1,' in top and 'RELAY_TARGET_X=152,' in top and 'RELAY_TOL_PX=80,' in top
 assert 'ENABLE_AUTO_RELAY && !relay_alarm &&' in top
 # TD may pack motor_output into a cell named for another FF. Bind the
 # actual alarm Q net, registered LUT data net and the V2 output launch cell.
 alarm_text=(folder/'alarm_motor_interlock.timing').read_text()
 output_text=(folder/'relay_output.timing').read_text()
 capture_cells={p.rsplit('.',1)[0] for p in re.findall(r'^End Point\s*:\s*(\S+)',alarm_text,re.M)}
 output_cells={p.rsplit('.',1)[0] for p in re.findall(r'^Begin Point\s*:\s*(\S+)',output_text,re.M)}
 assert capture_cells and output_cells and capture_cells<=output_cells,('Alarm capture is not V2 output FF cell',capture_cells,output_cells)
 assert re.search(r'net:\s+\S*controller/alarm_stop,',alarm_text), 'Actual alarm Q net missing'
 assert re.search(r'LUT\d+\s+\(reg\).*net:\s+O_relay_control(?:_dup_\d+)?,',alarm_text), 'Registered motor LUT/net missing'
 result['alarm_interlock_packed_cell_proof']={'capture_cells':sorted(capture_cells),'V2_output_launch_cells':sorted(output_cells),'actual_alarm_Q_and_registered_motor_LUT':True}
 result['alarm_interlock_routed']=True
 result['status']='PASS_R22_RELAY_V7_ROUTED_ALL_49_BOUNDS_20_GRAY_9_MAILBOX_GROUPS_SW3_4_KEYS_V2_ALARM_NO_LED'
(work/'physical_verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['status','timing_ns','resources','slice_delta_vs_r22','max_delays_matched','max_delays_ignored','gray_bits_dominating']},indent=2),flush=True)
