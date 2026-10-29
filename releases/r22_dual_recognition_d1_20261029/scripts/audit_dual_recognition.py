"""D1 recognition-only audit: 44 live bounds +2 vendor, 20 Gray, 6 manual mailboxes."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys
a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);args=a.parse_args()
w=args.work.resolve();p=w/'project';t=p/'tools';env=dict(os.environ);env['TEMP']=env['TMP']=str(w/'temp')
sha=lambda x:hashlib.sha256(x.read_bytes()).hexdigest()
orig=(p/'td_project/camera_to_dsi_display.sdc').read_bytes();active=(p/'td_project/camera_to_dsi_recognition.sdc').read_bytes()
removed=[s for s in orig.splitlines(keepends=True) if b'set_max_delay' in s and b'u_count_live_display/' in s]
assert len(removed)==3 and active==b''.join(s for s in orig.splitlines(keepends=True) if s not in removed)
for name in ['classified_audit_routed.tcl','classified_audit_gray_packing.tcl']:
 s=(t/name).read_text().replace('cd td_project/camera_to_dsi_display_Runs/phy_1','cd {'+(w/'runs/phy_1').as_posix()+'}')
 if name=='classified_audit_routed.tcl':
  s=s.replace('foreach box {u_count_command u_count_live_display}','foreach box {u_count_command u_relay_display}')
  s=s.replace('close $bind_fd',r'''
for {set bit 0} {$bit<4} {incr bit} {
 set rf [get_regs [format {*count_controls*controls/button_meta\[%d\]*} $bit]]
 set rs [get_regs [format {*count_controls*controls/button_sync\[%d\]*} $bit]]
 set rq [get_nets [format {*count_controls*controls/button_meta\[%d\]*} $bit]]
 puts $bind_fd "KEY_SYNC $bit FIRST_COUNT [llength $rf] SECOND_COUNT [llength $rs] Q_COUNT [llength $rq]"
 if {[llength $rf]<1 || [llength $rs]<1 || [llength $rq]<1} {error "Manual key synchronizer missing"}
 report_timing_path -from $rf -through $rq -to $rs -ep_num 4096 -path_num 2 -file classified_audit/key_${bit}_sync.timing
 report_timing_path -from $rf -through $rq -ep_num 4096 -path_num 2 -file classified_audit/key_${bit}_fanout.timing
}
report_timing_path -to [get_ports {O_relay_control}] -ep_num 16 -path_num 2 -file classified_audit/relay_output.timing
close $bind_fd''')
 target=w/name;target.write_text(s)
 with (w/(name+'.log')).open('w',encoding='utf8') as f:
  q=subprocess.run(['E:/TD/bin/td_commands_prompt.exe'],input='source {'+target.as_posix()+'}\n',cwd=p,env=env,text=True,stdout=f,stderr=subprocess.STDOUT,timeout=600)
 assert q.returncode==0,(name,str(w/(name+'.log')))
 print('Generated D1 '+name,flush=True)
s=(t/'verify_classified_physical.py').read_text().replace("project / 'td_project/camera_to_dsi_display.sdc'","project / 'td_project/camera_to_dsi_recognition.sdc'")
s=s.replace("for box in ['u_count_command', 'u_count_live_display']:","for box in ['u_count_command', 'u_relay_display']:")
target=w/'verify_dual_recognition_physical.py';target.write_text(s);sys.path.insert(0,str(t));ns={'__name__':'d1_audit','__file__':str(target)};exec(compile(s,str(target),'exec'),ns);result=ns['verify'](p)
folder=p/'classified_audit';extra={}
for name in ['relay_output.timing']+[f'key_{b}_{k}.timing' for b in range(4) for k in ['sync','fanout']]:
 text=(folder/name).read_text();slack=re.findall(r'^Slack\s*:\s*([-\d.]+)ns',text,re.M);assert slack and min(map(float,slack))>=0,(name,slack)
 extra[name]={'sha256':sha(folder/name),'minimum_slack_ns':min(map(float,slack))}
ends=lambda text:set(re.findall(r'^End Point\s*:\s*(\S+)',text,re.M))
for b in range(4):
 direct=(folder/f'key_{b}_sync.timing').read_text();fan=(folder/f'key_{b}_fanout.timing').read_text()
 assert f'button_meta[{b}]' in direct and f'button_sync[{b}]' in direct and ends(direct) and ends(direct)==ends(fan)
area=(w/'runs/phy_1/final.area').read_text();assert re.search(r'O_relay_control\s+OUTPUT\s+V2\s+LVCMOS33\s+HDIO\s+4\s+PULLDOWN',area) and 'O_led' not in area
resources={key:int(re.search(r'^#'+key+r'\s+(\d+)',area,re.M)[1]) for key in ['slice','eram','dsp','pll']}
assert resources['slice']<=21216 and resources['eram']<=108 and resources['dsp']<=40 and resources['pll']==5
syn=(w/'runs/syn_1/camera_to_dsi_display_gate.area').read_text()
assert 'classified_count_pipeline' not in syn and 'pocket_relay_stop' not in syn,'Object counting/auto parking unexpectedly instantiated'
top=(p/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8');assert 'DUAL_RECOGNITION_ONLY=1,' in top and '.MANUAL_ONLY(DUAL_RECOGNITION_ONLY)' in top and '&& !DUAL_RECOGNITION_ONLY' in top
assert 'camera_to_dsi_recognition.sdc' in (folder/'routed_summary.timing').read_text()
for rel,d in json.loads((w/'frozen_inputs.json').read_text()).items():assert sha(p/rel)==d,rel
result.update({'status':'PASS_DUAL_RECOGNITION_46_LIVE_BOUNDS_20_GRAY_6_MANUAL_MAILBOX_GROUPS_4_KEYS_SW3_V2_NO_COUNTER_NO_LED','resources':resources,'slice_percent':round(resources['slice']/21216*100,5),'counting_instantiated':False,'auto_parking_instantiated':False,'manual_mode_bits':3,'extra_manual_checks':extra,'constraint_profile':'separate recognition SDC; only three inactive count-live mailbox bounds omitted; original SDC unchanged','bit_sha256':sha(w/'runs/phy_1/camera_to_dsi_display.bit'),'board_acceptance':False})
(w/'physical_verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k] for k in ['status','timing_ns','resources','max_delays_matched','max_delays_ignored','gray_bits_dominating']},indent=2))
