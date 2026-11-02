"""Read-only exact-Q timing proof for the new timer crossings and C12 output."""
from pathlib import Path
import hashlib,json,os,re,subprocess

sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def verify(work):
 project=work/'project';folder=project/'instrument_audit';script=work/'instrument_audit.tcl'
 script.write_text(r'''if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
set audit_root [pwd]
cd {WORK/runs/phy_1}
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_pr.db
cd $audit_root
file mkdir instrument_audit
analyze_clock -detail
update_timing -mode final
set fd [open instrument_audit/bindings.txt w]
foreach domain {u_latency_capture u_latency_display} {
 for {set bit 0} {$bit<32} {incr bit} {
  set src [get_regs [format {u_latency_clock/us_gray\[%d\]} $bit]]
  set qnet [get_nets [format {u_latency_clock/us_gray\[%d\]} $bit]]
  if {$bit==31 && [llength $src]==0} {set src [get_regs {u_latency_clock/us_binary\[31\]}]}
  if {$bit==31 && [llength $qnet]==0} {set qnet [get_nets {u_latency_clock/us_binary\[31\]}]}
  set first [get_regs [format {%s/gray_meta\[%d\]} $domain $bit]]
  set firstq [get_nets [format {%s/gray_meta\[%d\]} $domain $bit]]
  set second [get_regs [format {%s/gray_sync\[%d\]} $domain $bit]]
  if {[llength $src]!=1 || [llength $qnet]!=1 || [llength $first]!=1 || [llength $firstq]!=1 || [llength $second]!=1} {error "Unbound timer Gray Q/stages $domain $bit"}
  puts $fd "TIME_GRAY $domain $bit SOURCE $src THROUGH $qnet FIRST $first SECOND $second"
  report_timing_path -from $src -through $qnet -to $first -ep_num 4096 -path_num 8 -file [format {instrument_audit/gray_q_%s_%d.timing} $domain $bit]
  report_timing_path -from $first -through $firstq -to $second -ep_num 4096 -path_num 8 -file [format {instrument_audit/stage_q_%s_%d.timing} $domain $bit]
  report_timing_path -from $first -through $firstq -ep_num 4096 -path_num 8 -file [format {instrument_audit/meta_fanout_%s_%d.timing} $domain $bit]
 }
}
set alarm [get_regs {*dual_parking*controller/alarm_latched*}]
set sync [get_regs {buzzer_alarm_sync\[0\]*}]
if {[llength $alarm]!=2 || [llength $sync]<1} {error "Missing two-lane sound alarm crossing"}
puts $fd "BUZZER_ALARM SOURCE_COUNT [llength $alarm] FIRST_COUNT [llength $sync]"
report_timing_path -from $alarm -to $sync -ep_num 4096 -path_num 4 -file instrument_audit/buzzer_alarm.timing
report_timing_path -to [get_ports {O_buzzer_n}] -ep_num 16 -path_num 4 -file instrument_audit/buzzer_output.timing
foreach bit {0 1} {
 set first [get_regs [format {u_observation_controls/sync0\[%d\]} $bit]]
 set second [get_regs [format {u_observation_controls/sync1\[%d\]} $bit]]
 set firstq [get_nets [format {u_observation_controls/sync0\[%d\]} $bit]]
 if {[llength $first]!=1 || [llength $second]!=1 || [llength $firstq]!=1} {error "Unbound four-view switch stages $bit"}
 puts $fd "VIEW_SWITCH $bit FIRST $first THROUGH $firstq SECOND $second"
 report_timing_path -from $first -through $firstq -to $second -ep_num 4096 -path_num 8 -file [format {instrument_audit/view_switch_%d_stage.timing} $bit]
 report_timing_path -from $first -through $firstq -ep_num 4096 -path_num 8 -file [format {instrument_audit/view_switch_%d_fanout.timing} $bit]
}
close $fd
puts "PASS R59 INSTRUMENT REPORTS ONLY; numeric acceptance still required"
} reason]} {puts stderr $reason; exit 1}
exit 0
'''.replace('WORK',work.as_posix()),encoding='utf8')
 env=dict(os.environ);env['TEMP']=env['TMP']=str(work/'temp')
 log=work/'instrument_audit.log'
 with log.open('w',encoding='utf8') as f:
  p=subprocess.run(['D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe'],
   input='source {'+script.as_posix()+'}\n',text=True,cwd=project,env=env,
   stdout=f,stderr=subprocess.STDOUT,timeout=1200)
 assert p.returncode==0,log
 assert 'PASS R59 INSTRUMENT REPORTS ONLY' in log.read_text(encoding='utf8')
 bindings=(folder/'bindings.txt').read_text(encoding='utf8');evidence={}
 def timed(path):
  t=path.read_text(encoding='utf8');slacks=re.findall(r'^Slack\s*:\s*([-\d.]+)ns',t,re.M)
  assert slacks and min(map(float,slacks))>=0,(path,slacks)
  evidence[path.relative_to(project).as_posix()]={'sha256':sha(path),'minimum_slack_ns':min(map(float,slacks))}
  return t
 for domain in ['u_latency_capture','u_latency_display']:
  for bit in range(32):
   bind=next(l for l in bindings.splitlines() if l.startswith(f'TIME_GRAY {domain} {bit} SOURCE '))
   allowed=[f'u_latency_clock/us_gray[{bit}]',f'latency_us_gray[{bit}]']+(['u_latency_clock/us_binary[31]'] if bit==31 else [])
   assert any(a in bind.split(' FIRST ')[0] for a in allowed),bind
   direct=timed(folder/f'gray_q_{domain}_{bit}.timing')
   assert domain+f'/gray_meta[{bit}]' in direct,(domain,bit)
   assert any(a in direct for a in allowed),(domain,bit)
   assert any(re.search(r'\bnet:\s*'+re.escape(a)+r'(?:,|\s)',direct) for a in allowed),('Actual timer Q data net missing',domain,bit)
   assert re.search(r'\bnet:\s*'+re.escape(domain+f'/gray_meta[{bit}]')+r'(?:,|\s)',direct),('Actual first-stage data net missing',domain,bit)
   assert re.search(r'^Logic Level\s*:\s*0\s*$',direct,re.M),('Not a direct registered Gray Q wire',domain,bit)
   assert re.search(r'^clk2q\s+.*pin:\s+\S+\.oq\w+',direct,re.M),('Actual Gray source FF Q missing',domain,bit)
   constraints=re.findall(r'constraint delay\s+([\d.]+)\s+([\d.]+)',direct)
   assert constraints and all(float(a)==float(b)==8.0 for a,b in constraints),(domain,bit,constraints)
   fan=timed(folder/f'meta_fanout_{domain}_{bit}.timing')
   ends=set(re.findall(r'^End Point\s*:\s*(\S+)',fan,re.M));assert ends,(domain,bit)
   stage=timed(folder/f'stage_q_{domain}_{bit}.timing')
   second_ends=set(re.findall(r'^End Point\s*:\s*(\S+)',stage,re.M))
   assert domain+f'/gray_sync[{bit}]' in stage
   assert re.search(r'\bnet:\s*'+re.escape(domain+f'/gray_meta[{bit}]')+r'(?:,|\s)',stage)
   assert re.search(r'\bnet:\s*'+re.escape(domain+f'/gray_sync[{bit}]')+r'(?:,|\s)',stage)
   assert ends==second_ends,('First-stage fanout escaped its physically bound second stage',domain,bit,ends,second_ends)
 alarm=timed(folder/'buzzer_alarm.timing');output=timed(folder/'buzzer_output.timing')
 assert re.search(r'BUZZER_ALARM SOURCE_COUNT 2 FIRST_COUNT [1-9]',bindings)
 assert 'O_buzzer_n' in output
 launch=set(re.findall(r'^Begin Point\s*:\s*(\S+)\.clk\b',output,re.M))
 qcells=set(re.findall(r'^clk2q\s+.*pin:\s+(\S+)\.oq\w+',output,re.M))
 assert launch and launch==qcells and all('u_contest_buzzer/O_buzzer_n_reg' in cell for cell in launch),('Buzzer output not launched by its actual FF Q',launch,qcells)
 assert set(re.findall(r'^Logic Level\s*:\s*(.*)',output,re.M))=={'2 ( HDIO=2 )'}
 top=(project/'user_source/hdl_source/design_top_wrapper.v').read_text()
 assert '.us_gray(latency_us_gray)' in top

 area=(work/'runs/phy_1/final.area').read_text(encoding='utf8')
 assert re.search(r'O_buzzer_n\s+OUTPUT\s+C12\s+LVCMOS33\s+HDIO\s+4\s+PULLUP',area)
 sdc=(project/'td_project/camera_to_dsi_display.sdc').read_text(encoding='utf8')
 for line in [
  'set_output_delay -clock [get_clocks {pll_clk_100m}] -max 2.0 [get_ports {O_buzzer_n}]',
  'set_output_delay -clock [get_clocks {pll_clk_100m}] -min 0.0 [get_ports {O_buzzer_n}]']:
  assert sdc.count(line)==1
 for bit,pin in [(0,'A4'),(1,'B4')]:
  assert re.search(r'I_switch\['+str(bit)+r'\]\s+INPUT\s+'+pin+r'\s+LVCMOS33',area)
  assert re.search(r'^VIEW_SWITCH '+str(bit)+r' FIRST ',bindings,re.M)
  stage=timed(folder/f'view_switch_{bit}_stage.timing');fan=timed(folder/f'view_switch_{bit}_fanout.timing')
  assert re.search(r'net:\s+u_observation_controls/sync0\['+str(bit)+r'\],',stage)
  assert re.search(r'net:\s+u_observation_controls/sync1\['+str(bit)+r'\],',stage)
  assert set(re.findall(r'^End Point\s*:\s*(\S+)',stage,re.M))==set(re.findall(r'^End Point\s*:\s*(\S+)',fan,re.M))
 result={'status':'PASS_R59_ROUTED_64_TIME_GRAY_BITS_STAGES_C12_BUZZER',
  'four_view_switch_stages_and_fanouts':2,'time_gray_bits':64,'exact_source_Q_first_stage_paths':64,'first_stage_fanouts_checked':64,
  'all_first_stage_fanouts_only_corresponding_second_stage':True,
  'time_gray_budget_ns':8.0,'buzzer_pin':'C12','buzzer_active_low':True,
  'buzzer_output_registered':True,'both_lane_alarm_sources_bound':True,
  'buzzer_period_reference_hz':100000000,'evidence':evidence,
  'bindings_sha256':sha(folder/'bindings.txt'),'read_only_report_log_sha256':sha(log),
  'source_manifest_sha256':sha(work/'frozen_inputs.json'),'board_acceptance':'HUMAN_PENDING'}
 (work/'R59_INSTRUMENT_PHYSICAL_PROOF.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
 return result

if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);a=p.parse_args()
 print(json.dumps(verify(a.work.resolve()),indent=2))
