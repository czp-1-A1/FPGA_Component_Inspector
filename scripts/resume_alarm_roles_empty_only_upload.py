"""Resume a committed candidate after transport reset; never rewrite its source."""
from pathlib import Path
import datetime,hashlib,json,os,subprocess,sys,time,zipfile
repo=Path(__file__).resolve().parents[1];branch='codex/rl7-alarm-roles-empty-only-20261102'
name='RL7_AlarmRolesV3_EmptyOnlyStop_v1_20261102';release=repo/'release'/name
url='https://github.com/czp-1-A1/FPGA_Component_Inspector.git'
env=dict(os.environ);env['GIT_TERMINAL_PROMPT']='0'
config=[('http.proxy','http://127.0.0.1:7897'),('https.proxy','http://127.0.0.1:7897'),('credential.interactive','false'),('http.version','HTTP/1.1'),('http.postBuffer','524288000')]
env['GIT_CONFIG_COUNT']=str(len(config))
for i,(k,v) in enumerate(config):env[f'GIT_CONFIG_KEY_{i}']=k;env[f'GIT_CONFIG_VALUE_{i}']=v
def load(p):return json.loads(p.read_text(encoding='utf8'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
 return h.hexdigest()
def git(*args,cwd=repo,data=None,timeout=900):
 r=subprocess.run(['git',*map(str,args)],cwd=cwd,env=env,input=data,capture_output=True,timeout=timeout)
 if r.returncode:raise RuntimeError('git '+str(args[0])+': '+r.stderr.decode(errors='replace')[-2400:])
 return r.stdout
def remote():
 data=git('ls-remote','--heads','origin','refs/heads/'+branch,timeout=90).decode().split()
 return data[0] if data else None
def push(log):
 r=subprocess.run(['git','push','--set-upstream','origin','HEAD:refs/heads/'+branch],cwd=repo,env=env,capture_output=True,timeout=900)
 (repo/'validation'/log).write_bytes(r.stdout+r.stderr)
 if r.returncode:raise RuntimeError((r.stdout+r.stderr).decode(errors='replace')[-2400:])
state_path=repo/'validation/github_upload_state.json';state=load(state_path)
source_commit=state['source_commit'];receipt=load(repo/'validation/delivery_receipt.json')
sources=load(release/'SOURCE_SHA256.json');payload=load(release/'PAYLOAD_SHA256.json')
assert state['committed'] and git('rev-parse','HEAD').decode().strip()==source_commit
assert git('branch','--show-current').decode().strip()==branch and not git('diff','--cached','--name-only').strip()
for rel,d in sources.items():assert sha(repo/'fpga/component_inspector'/rel)==d
assert sha(repo/'release'/(name+'_full.zip'))==receipt['zip_sha256']
for attempt in range(1,4):
 try:
  head=remote();assert head in (None,source_commit),'Remote advanced; never force'
  if head!=source_commit:push(f'github_source_push_r{attempt}.log')
  assert remote()==source_commit
  break
 except (RuntimeError,subprocess.TimeoutExpired) as error:
  state.update(stage='COMMITTED_UPLOAD_RETRY',last_transport_error=str(error),attempt=attempt);save(state_path,state)
  print('Upload transport attempt '+str(attempt)+' failed; committed source preserved',flush=True)
  if attempt==3:raise
  time.sleep(3)
state.update(stage='SOURCE_PUSHED_REMOTE_HEAD_VERIFIED',pushed=True,remote_source_head=source_commit);save(state_path,state)
print('Remote source HEAD verified '+source_commit,flush=True)
verify=Path('D:/CodexWork/rl7_alarm_roles_empty_only_remote_proxy_20261102')
assert not verify.exists(),'Inspect existing verification tree before resuming'
git('clone','--filter=blob:none','--single-branch','--branch',branch,'--no-checkout',url,verify)
git('sparse-checkout','init','--no-cone',cwd=verify)
patterns='/fpga/\n/.gitattributes\n/AGENTS.md\n/release/'+name+'/'+name+'.bit\n/release/'+name+'_full.zip\n'
git('sparse-checkout','set','--no-cone','--stdin',cwd=verify,data=patterns.encode())
git('checkout','--detach',source_commit,cwd=verify)
assert git('rev-parse','HEAD',cwd=verify).decode().strip()==source_commit
for rel,d in sources.items():assert sha(verify/'fpga/component_inspector'/rel)==d,rel
remote_bit=verify/'release'/name/(name+'.bit');remote_zip=verify/'release'/(name+'_full.zip')
assert sha(remote_bit)==receipt['bit_sha256'] and sha(remote_zip)==receipt['zip_sha256']
with zipfile.ZipFile(remote_zip) as z:
 assert z.testzip() is None
 for rel,d in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==d,rel
proof={'status':'PASS_INDEPENDENT_REMOTE_638_SOURCES_BIT_COMPLETE_ZIP_PAYLOADS','source_commit':source_commit,'remote_source_head':remote(),'sources':len(sources),'zip_payloads':len(payload),'bit_sha256':sha(remote_bit),'zip_sha256':sha(remote_zip),'independent_clone':str(verify),'board_operated':False}
save(repo/'validation/github_remote_verification.json',proof)
state.update(stage='COMPLETE_REMOTE_SOURCE_BIT_ZIP_INDEPENDENTLY_VERIFIED',remote_verified=True,view_branch='https://github.com/czp-1-A1/FPGA_Component_Inspector/tree/'+branch,verified_payloads=len(payload),transport='Per-command HTTP1.1 with non-chunked buffer; normal TLS unchanged');save(state_path,state)
subprocess.run([sys.executable,'-B','-X','utf8',str(repo/'scripts/checkpoint_alarm_roles_empty_only.py'),'--phase','已同步：源码、bit、完整交接包已远端独立下载核验，实板待测'],cwd=repo,check=True)
metadata=['AGENTS.md','scripts/resume_alarm_roles_empty_only_upload.py','scripts/publish_alarm_roles_empty_only.py','validation/network_route.json','validation/remote_readback_recovery.json','validation/current_status.json','validation/github_upload_state.json','validation/github_remote_verification.json']
metadata += [p.relative_to(repo).as_posix() for p in (repo/'validation').glob('github_source_push*.log')]
git('add','--sparse','--',*metadata)
ident=[]
for k,v in [('user.name','Codex'),('user.email','codex@openai.com')]:
 r=subprocess.run(['git','config','--get',k],cwd=repo,capture_output=True)
 if r.returncode or not r.stdout.strip():ident+=['-c',k+'='+v]
git(*ident,'commit','-m','Record independent remote verification and resumed AlarmRoles upload')
metadata_commit=git('rev-parse','HEAD').decode().strip()
assert not git('diff',source_commit,metadata_commit,'--','fpga','release').strip()
push('github_receipt_push.log');assert remote()==metadata_commit
final={'status':'COMPLETE_REMOTE_SOURCE_AND_RECEIPT_VERIFIED','source_commit':source_commit,'final_remote_head':metadata_commit,'branch':branch,'branch_url':state['view_branch'],'bit_sha256':receipt['bit_sha256'],'zip_sha256':receipt['zip_sha256'],'independent_remote_sources':638,'independent_remote_payloads':len(payload),'merged_to_main':False}
save(Path('D:/CodexWork/rl7_alarm_roles_empty_only_upload_receipt_20261102.json'),final)
save(Path('C:/Users/Li47/Desktop')/(name+'_GitHub回执.json'),final)
print(json.dumps(final,ensure_ascii=False,indent=2),flush=True)
