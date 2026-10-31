"""Read the routed DB; retain every R22 check and add relay mailbox/SW/output checks."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--left-v2',action='store_true');a.add_argument('--keys-v3',action='store_true');a.add_argument('--adjacent-v6',action='store_true');a.add_argument('--five-empty-v7',action='store_true');a.add_argument('--demo-rl7',action='store_true');args=a.parse_args()
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
 if name=='classified_audit_routed.tcl' and args.demo_rl7:
  text=text.replace('close $bind_fd',r'''
# New registered1us Gray time: bind each actual Q wire and BOTH first stages.
foreach bank {u_latency_capture u_latency_display} {
 for {set bit 0} {$bit<32} {incr bit} {
  set src [get_regs [format {u_latency_clock/us_gray\[%d\]} $bit]]
  set qnet [get_nets [format {u_latency_clock/us_gray\[%d\]} $bit]]
  set dst [get_regs [format {%s/gray_meta\[%d\]} $bank $bit]]
  puts $bind_fd "LATENCY_GRAY $bank $bit SOURCE $src THROUGH $qnet DESTINATION $dst"
  if {[llength $src]!=1 || [llength $qnet]!=1 || [llength $dst]!=1} {error "Latency Gray actual Q/first-stage binding missing"}
  report_timing_path -from $src -through $qnet -to $dst -ep_num 4096 -path_num 2 -file [format {classified_audit/latency_%s_%d.timing} $bank $bit]
 }
}
report_timing_path -to [get_ports {O_buzzer_n}] -ep_num 16 -path_num 2 -file classified_audit/buzzer_output.timing
set alarm_regs [get_regs {*left_station*controller/alarm_latched*}]
set buzzer_regs [get_regs {u_contest_buzzer/*}]
if {[llength $alarm_regs]<1 || [llength $buzzer_regs]<1} {error "Buzzer alarm binding missing"}
report_timing_path -from $alarm_regs -to $buzzer_regs -ep_num 4096 -path_num 2 -file classified_audit/alarm_buzzer.timing
close $bind_fd''')
 target=work/name;target.write_text(text)
 with (work/(name+'.log')).open('w',encoding='utf8') as log:
  result=subprocess.run(['E:/TD/bin/td_commands_prompt.exe'],input='source {'+target.as_posix()+'}\n',text=True,cwd=project,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600)
 assert result.returncode==0,(name,str(work/(name+'.log')))
 print('Generated read-only routed reports: '+name,flush=True)

original=(tools/'verify_classified_physical.py').read_text()
bounds=48 if args.demo_rl7 else 47
updated=original.replace('len(expected) == 44 and len(set(expected)) == 44',f'len(expected) == {bounds} and len(set(expected)) == {bounds}')
updated=updated.replace('len(observed) == 46',f'len(observed) == {bounds+2}')
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
if args.demo_rl7:extra_names+=['buzzer_output.timing','alarm_buzzer.timing']
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
expected_eram,expected_dsp=(99,30) if args.demo_rl7 else (98,30) if args.keys_v3 else (99,30) if args.left_v2 else (101,27)
assert resources['slice']<=21216 and resources['eram']==expected_eram and resources['dsp']==expected_dsp and resources['pll']==5
if args.left_v2 or args.keys_v3:
 assert 'RELAY_LEFT_LAYOUT=1' in (project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
 width=195 if args.demo_rl7 else 163 if args.adjacent_v6 else 64
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
if args.demo_rl7:
 assert args.keys_v3 and args.adjacent_v6 and args.five_empty_v7
 assert re.search(r'O_buzzer_n\s+OUTPUT\s+C12\s+LVCMOS33\s+HDIO\s+4\s+PULLUP',area),'C12 buzzer pin/voltage/pullup mismatch'
 assert 'DEMO_UI=1,' in top and '.WIDTH(195)) u_relay_display' in top
 new_gray=[]
 for bank in ['u_latency_capture','u_latency_display']:
  for bit in range(32):
   name=f'latency_{bank}_{bit}.timing';report=(folder/name).read_text()
   line=next(x for x in bindings.splitlines() if x.startswith(f'LATENCY_GRAY {bank} {bit} SOURCE '))
   assert f'{bank}/gray_meta[{bit}]' in report,(name,'destination missing')
   # TD binds the RTL us_gray alias to top-level latency_gray_us; bit31
   # shares the binary-MSB FF. Require actual Q net and exact binding, not
   # merely a logical source spelling in a printed SDC command.
   qname=f'latency_gray_us[{bit}]' if bit<31 else 'u_latency_clock/us_binary[31]'
   assert f'SOURCE {{{qname}}} THROUGH {{{qname}}}' in line,(name,'typed Q binding missing')
   assert re.search(r'net:\s+'+re.escape(qname)+r',',report),(name,'actual source Q missing')
   assert ' THROUGH ' in line and ' DESTINATION ' in line
   assert re.search(r'constraint delay\s+8\.000\s+8\.000',report),(name,'new8ns bound not dominant')
   assert 'Check Type          : setup' in report
   slacks=re.findall(r'^Slack\s*:\s*([-\d.]+)ns',report,re.M)
   assert slacks and min(map(float,slacks))>=0,(name,slacks)
   new_gray.append({'bank':bank,'bit':bit,'sha256':sha(folder/name),'minimum_slack_ns':min(map(float,slacks)),'binding':line})
 assert len(new_gray)==64
 result['status']='PASS_RL7_DEMO_ROUTED_50_BOUNDS_20_FIFO_GRAY_64_TIME_GRAY_KEYS_V2_C12'
 result['latency_gray_actual_q_paths']=new_gray
 result['latency_gray_paths']=64;result['relay_display_declared_bits']=195
 result['active_frame_display_declared_bits']=955
 result['buzzer_pin']='C12 LVCMOS33 PULLUP active-low';result['demo_ui']=True
 result['inherited_explicit_bounds_preserved']=47
(work/'physical_verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['status','timing_ns','resources','slice_delta_vs_r22','max_delays_matched','max_delays_ignored','gray_bits_dominating']},indent=2),flush=True)
