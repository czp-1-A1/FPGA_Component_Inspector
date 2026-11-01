from pathlib import Path
import hashlib,json,os,subprocess,sys,time
root=Path(__file__).resolve().parent;repo=Path('D:/CodexWork/erole_fix_20261102');work=Path('D:/CodexWork/erole_build_r1_20261102')
limit=time.monotonic()+2600
while not (work/'build_result.json').exists():
 assert time.monotonic()<limit,'Final build did not finish; inspect build session59020 and logs'
 time.sleep(2)
assert not (work/'physical_verification.json').exists(),'Never repeat an already completed physical audit'
manifest=json.loads((work/'frozen_inputs.json').read_text())
for rel,d in manifest.items():assert hashlib.sha256((repo/'fpga/component_inspector'/rel).read_bytes()).hexdigest()==d,rel
env=dict(os.environ);env['PYTHONUTF8']='1'
with (root/'final_audit_launcher.log').open('w',encoding='utf8') as f:
 r=subprocess.run([sys.executable,'-X','utf8',str(repo/'scripts/audit_r22_relay.py'),'--work',str(work),'--td','D:/td6.2.1','--keys-v3','--adjacent-v6','--five-empty-v7','--demo-rl7','--ui-opt-v2'],cwd=repo,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
assert r.returncode==0,(root/'final_audit_launcher.log').read_text(errors='replace')[-3500:]
p=json.loads((work/'physical_verification.json').read_text());assert p['status'].startswith('PASS_')
subprocess.run([sys.executable,'-X','utf8',str(repo/'scripts/review_pocket_row_resources.py')],cwd=repo,env=env,check=True)
print('PASS final routed audit and resource review',flush=True)
