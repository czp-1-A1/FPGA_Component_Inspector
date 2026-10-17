from pathlib import Path
import subprocess,json,re,sys
r=Path.cwd();rd=r/'tmp'/sys.argv[1];w=rd/'work_raw';out=rd/'transitions';out.mkdir(exist_ok=False);results=[]
cases=[dict(previous=a,schedule=b) for a in range(4) for b in range(4)]
cases += [dict(extra=n) for n in [0,8,32,64,128]]
for case in cases:
 name='_'.join(str(k)+str(v) for k,v in case.items());q=out/(name+'.log')
 params=['-g'+dict(previous='PREVIOUS',schedule='SCHEDULE',extra='EXTRA_GAPS')[k]+'='+str(v) for k,v in case.items()]
 with q.open('w',encoding='utf-8') as f:
  z=subprocess.run(['D:/modelsim/win64/vsim.exe','-c','-L','anlogic_sim','-voptargs=+acc=rn+/tb_raw_timing_probe',*params,'-onfinish','exit','-do','run -all; quit -code 1 -force','test_raw_timing_probe.tb_raw_timing_probe','anlogic_sim.glbl','anlogic_sim.PH1P_PHY_GSR'],cwd=w/'sim',stdout=f,stderr=subprocess.STDOUT)
 s=q.read_text('utf-8',errors='replace');passed='PASS raw timing probe:' in s and '** Fatal:' not in s and '** Error' not in s
 lines=[a for a in s.splitlines() if 'PROBE frame' in a]
 passed=passed and len(lines)==3 and all(re.search(r'outputs26880 diffs0 first-1 last-1 repack_groups26880 repack_changed0 repack_wrong0 baseline_wrong0',a) for a in lines)
 results.append(dict(**case,status='PASS' if passed else 'FAIL',log=q.relative_to(rd).as_posix()));print(results[-1],flush=True)
 (out/'results.json').write_bytes((json.dumps(results,indent=2)+'\n').encode('utf-8'))
 if not passed:sys.exit(1)
print('PASS 16 timing transitions plus5 input-gap bounds; independent RAW truth and all26880 demosaic groups unchanged')
