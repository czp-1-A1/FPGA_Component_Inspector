"""Commit and publish this authorized candidate without merging other branches."""
from pathlib import Path
import datetime,hashlib,json,os,subprocess,sys,zipfile
repo=Path(__file__).resolve().parents[1];base='904a2bb053a9e679b3f50378ca3163a55698b20e'
branch='codex/rl7-alarm-roles-empty-only-20261102';url='https://github.com/czp-1-A1/FPGA_Component_Inspector.git'
name='RL7_AlarmRolesV3_EmptyOnlyStop_v1_20261102';release=repo/'release'/name
verify=Path('D:/CodexWork/rl7_alarm_roles_empty_only_remote_20261102')
env=dict(os.environ);env['GIT_TERMINAL_PROMPT']='0'
env['GIT_CONFIG_COUNT']='5';env['GIT_CONFIG_KEY_0']='http.proxy';env['GIT_CONFIG_VALUE_0']='http://127.0.0.1:7897'
env['GIT_CONFIG_KEY_1']='https.proxy';env['GIT_CONFIG_VALUE_1']='http://127.0.0.1:7897';env['GIT_CONFIG_KEY_2']='credential.interactive';env['GIT_CONFIG_VALUE_2']='false'
env['GIT_CONFIG_KEY_3']='http.version';env['GIT_CONFIG_VALUE_3']='HTTP/1.1'
env['GIT_CONFIG_KEY_4']='http.postBuffer';env['GIT_CONFIG_VALUE_4']='524288000'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for c in iter(lambda:f.read(1048576),b''):h.update(c)
 return h.hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf8'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def git(*args,cwd=repo,data=None,timeout=600):
 r=subprocess.run(['git',*map(str,args)],cwd=cwd,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,timeout=timeout)
 if r.returncode:raise RuntimeError('git '+str(args[0])+': '+r.stderr.decode(errors='replace')[-3000:])
 return r.stdout
def push(logname):
 r=subprocess.run(['git','push','--set-upstream','origin','HEAD:refs/heads/'+branch],cwd=repo,env=env,capture_output=True,timeout=900)
 (repo/'validation'/logname).write_bytes(r.stdout+r.stderr)
 assert r.returncode==0,(r.stdout+r.stderr).decode(errors='replace')[-3000:]
def remote_head():return git('ls-remote','--heads','origin','refs/heads/'+branch).decode().split()[0]
def checkpoint(phase):
 subprocess.run([sys.executable,'-B','-X','utf8',str(repo/'scripts/checkpoint_alarm_roles_empty_only.py'),'--phase',phase],cwd=repo,check=True)
def commit(message):
 ident=[]
 for key,value in [('user.name','Codex'),('user.email','codex@openai.com')]:
  r=subprocess.run(['git','config','--get',key],cwd=repo,capture_output=True)
  if r.returncode or not r.stdout.strip():ident+=['-c',key+'='+value]
 git(*ident,'commit','-m',message)
 return git('rev-parse','HEAD').decode().strip()
assert git('branch','--show-current').decode().strip()==branch
assert git('rev-parse','HEAD').decode().strip()==base,'Refuse unexpected or already committed work; inspect saved state first'
cached=git('diff','--cached','--name-only','-z').decode().split('\0')[:-1]
if cached:
 assert '--resume-staging' in sys.argv[1:],'Never mix pre-existing staged changes'
 previous=load(repo/'validation/github_upload_state.json')
 assert previous['stage']=='READY_TO_COMMIT' and not previous['committed'] and not previous['pushed']
receipt=load(repo/'validation/delivery_receipt.json');sources=load(release/'SOURCE_SHA256.json');payload=load(release/'PAYLOAD_SHA256.json')
assert sha(Path(receipt['desktop_bit']))==receipt['bit_sha256']==sha(release/(name+'.bit'))
archive=repo/'release'/(name+'_full.zip');assert sha(archive)==receipt['zip_sha256']==sha(Path(receipt['desktop_zip']))
assert all(sha(release/rel)==d for rel,d in payload.items())
assert all(sha(repo/'fpga/component_inspector'/rel)==d for rel,d in sources.items())
state={'stage':'READY_TO_COMMIT','baseline_commit':base,'branch':branch,'repository':url,'committed':False,'pushed':False,'board_operated':False,'updated':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()}
state_path=repo/'validation/github_upload_state.json';save(state_path,state)
checkpoint('完整交付校验通过，准备提交和上传本次独立分支')
paths=['.gitignore','.gitattributes','AGENTS.md',
 'fpga/component_inspector/user_source/hdl_source/design_top_wrapper.v','fpga/component_inspector/user_source/hdl_source/isp/isp_top.v','fpga/component_inspector/user_source/hdl_source/pocket_relay_stop_v2.v',
 'scripts/audit_r22_relay.py','scripts/build_r22_relay.py','scripts/relay_left_native_check.py','scripts/check_rl7_alarm_roles_v3.py',
 'scripts/check_empty_only_stop.py','scripts/prepare_alarm_roles_empty_only.py','scripts/checkpoint_alarm_roles_empty_only.py',
 'scripts/prepare_alarm_roles_delivery_tool.py','scripts/package_alarm_roles_empty_only.py','scripts/verify_alarm_roles_preserved.py','scripts/review_alarm_roles_empty_only_resources.py','scripts/publish_alarm_roles_empty_only.py',
 'tests/empty_only_stop','docs/ALARM_ROLES_EMPTY_ONLY_20261102.md','validation','开发实施/验收记录/20261102_C_AlarmRolesV3仅空穴停车_轮次1.md',
 'release/'+name,'release/'+name+'_full.zip']
assert all(any(rel==p or rel.startswith(p+'/') for p in paths) for rel in cached),'Unrelated staged path'
git('add','--sparse','--',*paths)
staged=git('diff','--cached','--name-only','-z').decode().split('\0')[:-1]
assert staged
for rel in staged:
 p=repo/rel;assert p.is_file() and p.stat().st_size<100*1024*1024,(rel,'GitHub single-file limit')
 assert not rel.startswith(('release/independent_unpack/','release/portable_check/'))
# Read raw indexed blobs: protect source, all payloads and the exact ZIP from CRLF conversion.
expected={'fpga/component_inspector/'+r:d for r,d in sources.items()}
expected.update({'release/'+name+'/'+r:d for r,d in payload.items()})
expected['release/'+name+'/PAYLOAD_SHA256.json']=sha(release/'PAYLOAD_SHA256.json')
expected['release/'+name+'_full.zip']=sha(archive)
cat=subprocess.Popen(['git','cat-file','--batch'],cwd=repo,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
for rel,digest in expected.items():
 cat.stdin.write((':'+rel+'\n').encode());cat.stdin.flush();header=cat.stdout.readline().decode().split()
 assert len(header)==3 and header[1]=='blob',(rel,header)
 blob=cat.stdout.read(int(header[2]));assert cat.stdout.read(1)==b'\n';assert hashlib.sha256(blob).hexdigest()==digest,rel
cat.stdin.close();assert cat.wait()==0
source_commit=commit('Apply EMPTY-only automatic stop policy to RL7 AlarmRoles V3 with verified delivery')
state.update(stage='COMMITTED_READY_TO_PUSH',source_commit=source_commit,committed=True,indexed_source_payload_zip_sha256_count=len(expected));save(state_path,state)
print('Committed verified source and delivery '+source_commit,flush=True)
push('github_source_push.log');assert remote_head()==source_commit
state.update(stage='SOURCE_PUSHED_REMOTE_HEAD_VERIFIED',pushed=True,remote_source_head=source_commit);save(state_path,state)
assert not verify.exists(),'Refuse to overwrite an independent verification clone'
git('clone','--filter=blob:none','--single-branch','--branch',branch,'--no-checkout',url,verify,cwd=repo,timeout=900)
git('sparse-checkout','init','--no-cone',cwd=verify)
patterns='/fpga/\n/.gitattributes\n/AGENTS.md\n/release/'+name+'/'+name+'.bit\n/release/'+name+'_full.zip\n'
git('sparse-checkout','set','--no-cone','--stdin',cwd=verify,data=patterns.encode())
git('checkout','--detach',source_commit,cwd=verify,timeout=900)
assert git('rev-parse','HEAD',cwd=verify).decode().strip()==source_commit
for rel,d in sources.items():assert sha(verify/'fpga/component_inspector'/rel)==d,rel
remote_bit=verify/'release'/name/(name+'.bit');remote_zip=verify/'release'/(name+'_full.zip')
assert sha(remote_bit)==receipt['bit_sha256'] and sha(remote_zip)==receipt['zip_sha256']
with zipfile.ZipFile(remote_zip) as z:
 assert z.testzip() is None
 for rel,d in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==d,rel
verified={'status':'PASS_INDEPENDENT_REMOTE_638_SOURCES_BIT_COMPLETE_ZIP_PAYLOADS','source_commit':source_commit,'remote_source_head':remote_head(),'sources':len(sources),'zip_payloads':len(payload),'bit_sha256':sha(remote_bit),'zip_sha256':sha(remote_zip),'independent_clone':str(verify),'board_operated':False}
save(repo/'validation/github_remote_verification.json',verified)
state.update(stage='COMPLETE_REMOTE_SOURCE_BIT_ZIP_INDEPENDENTLY_VERIFIED',remote_verified=True,source_commit=source_commit,view_branch='https://github.com/czp-1-A1/FPGA_Component_Inspector/tree/'+branch,verified_payloads=len(payload));save(state_path,state)
checkpoint('已同步：源码、bit和完整交接包已在远端独立下载核验，等待同一冻结镜像人工实板')
git('add','--sparse','--','AGENTS.md','validation/current_status.json','validation/github_upload_state.json','validation/github_remote_verification.json','validation/github_source_push.log')
metadata_commit=commit('Record independent GitHub verification and AlarmRoles stop-policy handoff')
assert not git('diff',source_commit,metadata_commit,'--','fpga','release').strip(),'Publication receipt changed frozen code or release'
push('github_receipt_push.log');assert remote_head()==metadata_commit
# The second push log is a local receipt, not another commit to chase its own hash.
final={'status':'COMPLETE_REMOTE_SOURCE_AND_RECEIPT_VERIFIED','source_commit':source_commit,'final_remote_head':metadata_commit,'branch':branch,'branch_url':state['view_branch'],'bit_sha256':receipt['bit_sha256'],'zip_sha256':receipt['zip_sha256'],'independent_remote_sources':638,'independent_remote_payloads':len(payload),'merged_to_main':False}
save(Path('D:/CodexWork/rl7_alarm_roles_empty_only_upload_receipt_20261102.json'),final)
save(Path('C:/Users/Li47/Desktop')/(name+'_GitHub回执.json'),final)
print(json.dumps(final,ensure_ascii=False,indent=2),flush=True)
