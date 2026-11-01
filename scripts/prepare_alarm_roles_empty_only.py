"""Port only the reviewed stop-policy delta onto the specified AlarmRoles V3."""
from pathlib import Path
import hashlib,json,shutil,subprocess
repo=Path(__file__).resolve().parents[1]
old=Path('D:/CodexWork/empty_only_stop_20261101')
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()=='904a2bb053a9e679b3f50378ca3163a55698b20e'
assert not subprocess.check_output(['git','diff','--name-only','--','fpga'],cwd=repo,text=True).strip()
rels=['fpga/component_inspector/user_source/hdl_source/'+n for n in ['design_top_wrapper.v','isp/isp_top.v','pocket_relay_stop_v2.v']]
patch=subprocess.check_output(['git','diff','--binary','--',*rels],cwd=old)
subprocess.run(['git','apply','--check','-'],input=patch,cwd=repo,check=True)
subprocess.run(['git','apply','-'],input=patch,cwd=repo,check=True)
p=repo/rels[-1];data=p.read_bytes()
before=b'phase_ms<=0;stable<=0;have_position<=0;capture_context(3,why);'
after=b'phase_ms<=0;stable<=0;have_position<=0;\n   if(!frozen_diagnostic[95])capture_context(3,why);'
assert data.count(before)==1;data=data.replace(before,after)
before=b'if(fifth_empty)begin alarm_latched<=1;fail(15);end'
after=b'''if(fifth_empty)begin
     alarm_latched<=1;
     if(EMPTY_ONLY_STOP && frozen_diagnostic[95])begin state<=FAULT;fault<=15;feed_command<=0;end
     else fail(15);
    end'''
assert data.count(before)==1;data=data.replace(before,after)
p.write_bytes(data)
for n in ['check_empty_only_stop.py','audit_r22_relay.py','build_r22_relay.py','relay_left_native_check.py']:
 shutil.copy2(old/'scripts'/n,repo/'scripts'/n)
target=repo/'tests/empty_only_stop';assert not target.exists();shutil.copytree(old/'tests/empty_only_stop',target)
# Freeze every original Git blob before build, avoiding dependence on archived downloads.
names=subprocess.check_output(['git','ls-tree','-r','--name-only','HEAD','fpga/component_inspector'],cwd=repo,text=True).splitlines();assert len(names)==638
cat=subprocess.Popen(['git','cat-file','--batch'],cwd=repo,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
manifest={}
for name in names:
 cat.stdin.write(('HEAD:'+name+'\n').encode());cat.stdin.flush()
 header=cat.stdout.readline().decode().split();assert len(header)==3 and header[1]=='blob'
 blob=cat.stdout.read(int(header[2]));assert cat.stdout.read(1)==b'\n'
 manifest[name.removeprefix('fpga/component_inspector/')]=hashlib.sha256(blob).hexdigest()
cat.stdin.close();assert cat.wait()==0
(repo/'validation').mkdir(exist_ok=True)
(repo/'validation/baseline_frozen_inputs.json').write_text(json.dumps(manifest,indent=2)+'\n')
(repo/'validation/stop_policy_port.patch').write_bytes(patch)
print('PASS stop-policy port onto904a2bb0: AlarmRoles independent ledger/role OSD retained; first prior-fault context preserved')
