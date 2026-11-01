"""Publish the authorized independent row-role branch and verify remote bytes."""
from pathlib import Path
import hashlib,json,os,subprocess,zipfile
repo=Path(__file__).resolve().parents[1];base='1b8a097f9dd7d7dee2783e9dcbcf43986f7650f4'
branch='codex/rl7-empty-aperture-role-20261102';name='RL7_EmptyTailRowRoles_v2_20261102'
url='https://github.com/czp-1-A1/FPGA_Component_Inspector.git';release=repo/'release'/name
validation=repo/'validation/pocket_row_roles';state_path=validation/'github_upload_state.json'
verify=Path('D:/CodexWork/erole_remote_r0_20261102')
env=dict(os.environ);env['GIT_TERMINAL_PROMPT']='0'
settings=[('http.proxy','http://127.0.0.1:7897'),('https.proxy','http://127.0.0.1:7897'),('credential.interactive','false'),('http.version','HTTP/1.1'),('http.postBuffer','524288000')]
env['GIT_CONFIG_COUNT']=str(len(settings))
for i,(k,v) in enumerate(settings):env[f'GIT_CONFIG_KEY_{i}']=k;env[f'GIT_CONFIG_VALUE_{i}']=v
def load(p):return json.loads(p.read_text(encoding='utf8'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for c in iter(lambda:f.read(1048576),b''):h.update(c)
 return h.hexdigest()
def git(*args,cwd=repo,data=None,timeout=900):
 r=subprocess.run(['git',*map(str,args)],cwd=cwd,env=env,input=data,capture_output=True,timeout=timeout)
 if r.returncode:raise RuntimeError('git '+str(args[0])+': '+r.stderr.decode(errors='replace')[-2500:])
 return r.stdout
def commit(msg):
 ident=[]
 for k,v in [('user.name','Codex'),('user.email','codex@openai.com')]:
  r=subprocess.run(['git','config','--get',k],cwd=repo,capture_output=True)
  if r.returncode or not r.stdout.strip():ident+=['-c',k+'='+v]
 git(*ident,'commit','-m',msg);return git('rev-parse','HEAD').decode().strip()
def remote():
 t=git('ls-remote','--heads','origin','refs/heads/'+branch,timeout=90).decode().split()
 return t[0] if t else None
def push_verified(expected,log):
 h=remote();assert h is None or h==expected or h==base or h==state.get('source_commit'),('Remote advanced, never force',h)
 if h!=expected:
  r=subprocess.run(['git','push','--set-upstream','origin','HEAD:refs/heads/'+branch],cwd=repo,env=env,capture_output=True,timeout=900)
  (validation/log).write_bytes(r.stdout+r.stderr)
  # A reset after server acceptance can still have succeeded; read first.
  if remote()!=expected:raise RuntimeError((r.stdout+r.stderr).decode(errors='replace')[-2500:])
 assert remote()==expected
assert git('branch','--show-current').decode().strip()==branch
receipt=load(validation/'delivery_receipt.json');sources=load(release/'SOURCE_SHA256.json');payload=load(release/'PAYLOAD_SHA256.json')
archive=repo/'release'/(name+'_full.zip')
assert sha(Path(receipt['desktop_bit']))==receipt['bit_sha256']==sha(release/(name+'.bit'))
assert sha(archive)==receipt['zip_sha256']==sha(Path(receipt['desktop_zip']))
for r,d in sources.items():assert sha(repo/'fpga/component_inspector'/r)==d,r
for r,d in payload.items():assert sha(release/r)==d,r
head=git('rev-parse','HEAD').decode().strip()
state=load(state_path) if state_path.exists() else {'stage':'READY_TO_COMMIT','baseline_commit':base,'branch':branch,'committed':False,'pushed':False,'board_operated':False}
if not state['committed']:
 assert head==base and not git('diff','--cached','--name-only').strip(),'Unexpected HEAD or pre-existing staging; inspect before proceeding'
 paths=['.gitattributes','AGENTS.md','fpga/component_inspector/user_source/hdl_source/design_top_wrapper.v','fpga/component_inspector/user_source/hdl_source/isp/isp_top.v','fpga/component_inspector/user_source/hdl_source/frame_shape_search.v','scripts/check_pocket_row_roles.py','scripts/package_pocket_row_roles.py','scripts/publish_pocket_row_roles.py','scripts/review_pocket_row_resources.py','scripts/checkpoint_pocket_row_roles.py','tests/pocket_row_roles','docs/EMPTY_TAIL_ROW_ROLES_20261102.md','validation/pocket_row_roles','release/'+name,'release/'+name+'_full.zip']
 paths += [p.relative_to(repo).as_posix() for p in (repo/'开发实施/验收记录').glob('20261102_C_全空尾段角色_轮次*.md')]
 save(state_path,state);git('add','--sparse','--',*paths)
 staged=git('diff','--cached','--name-only','-z').decode().split('\0')[:-1];assert staged
 for r in staged:
  assert any(r==p or r.startswith(p+'/') for p in paths),r
  assert (repo/r).is_file() and (repo/r).stat().st_size<100*1024*1024,r
 expected={'fpga/component_inspector/'+r:d for r,d in sources.items()}
 expected.update({'release/'+name+'/'+r:d for r,d in payload.items()})
 expected['release/'+name+'/PAYLOAD_SHA256.json']=sha(release/'PAYLOAD_SHA256.json')
 expected['release/'+name+'_full.zip']=sha(archive)
 cat=subprocess.Popen(['git','cat-file','--batch'],cwd=repo,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
 for r,d in expected.items():
  cat.stdin.write((':'+r+'\n').encode());cat.stdin.flush();header=cat.stdout.readline().decode().split();assert len(header)==3 and header[1]=='blob',(r,header)
  blob=cat.stdout.read(int(header[2]));assert cat.stdout.read(1)==b'\n' and hashlib.sha256(blob).hexdigest()==d,r
 cat.stdin.close();assert cat.wait()==0
 head=commit('Fix all-empty tail aperture roles with frozen RGB native and routed verification')
 state.update(stage='COMMITTED_READY_TO_PUSH',source_commit=head,committed=True,indexed_source_payload_zip_sha256_count=len(expected));save(state_path,state)
 print('Committed source and complete audited release '+head,flush=True)
source_commit=state['source_commit']
if head!=source_commit:
 assert git('rev-parse','HEAD^').decode().strip()==source_commit
 assert not git('diff',source_commit,head,'--','fpga','release').strip()
if head==source_commit:
 push_verified(source_commit,'source_push.log');state.update(stage='SOURCE_PUSHED_REMOTE_HEAD_VERIFIED',pushed=True);save(state_path,state)
 if not verify.exists():
  git('clone','--filter=blob:none','--single-branch','--branch',branch,'--no-checkout',url,verify)
  git('sparse-checkout','init','--no-cone',cwd=verify)
  patterns='/fpga/\n/.gitattributes\n/AGENTS.md\n/release/'+name+'/'+name+'.bit\n/release/'+name+'_full.zip\n'
  git('sparse-checkout','set','--no-cone','--stdin',cwd=verify,data=patterns.encode())
  git('checkout','--detach',source_commit,cwd=verify)
 assert git('rev-parse','HEAD',cwd=verify).decode().strip()==source_commit
 for r,d in sources.items():assert sha(verify/'fpga/component_inspector'/r)==d,r
 rb=verify/'release'/name/(name+'.bit');rz=verify/'release'/(name+'_full.zip')
 assert sha(rb)==receipt['bit_sha256'] and sha(rz)==receipt['zip_sha256']
 with zipfile.ZipFile(rz) as z:
  assert z.testzip() is None
  for r,d in payload.items():assert hashlib.sha256(z.read(r)).hexdigest()==d,r
 proof={'status':'PASS_INDEPENDENT_REMOTE_SOURCE_BIT_ZIP_ALL_PAYLOAD_SHA256','source_commit':source_commit,'sources':len(sources),'payloads':len(payload),'bit_sha256':sha(rb),'zip_sha256':sha(rz),'clone':str(verify),'board_operated':False}
 save(validation/'github_remote_verification.json',proof)
 state.update(stage='COMPLETE_REMOTE_SOURCE_BIT_ZIP_INDEPENDENTLY_VERIFIED',remote_verified=True);save(state_path,state)
 subprocess.run([os.sys.executable,'-X','utf8',str(repo/'scripts/checkpoint_pocket_row_roles.py'),'--phase','已同步源码、bit、完整包；远端独立下载逐SHA核验，待人实板'],cwd=repo,check=True)
 metadata=['AGENTS.md','validation/pocket_row_roles/current_status.json','validation/pocket_row_roles/github_upload_state.json','validation/pocket_row_roles/github_remote_verification.json']
 metadata += [p.relative_to(repo).as_posix() for p in validation.glob('*push.log')]
 git('add','--sparse','--',*metadata)
 head=commit('Record independent remote readback and empty-tail candidate handoff')
 assert not git('diff',source_commit,head,'--','fpga','release').strip()
push_verified(head,'receipt_push.log')
final={'status':'COMPLETE_REMOTE_SOURCE_AND_RECEIPT_VERIFIED','source_commit':source_commit,'final_remote_head':head,'branch':branch,'branch_url':'https://github.com/czp-1-A1/FPGA_Component_Inspector/tree/'+branch,'download_package_url':'https://github.com/czp-1-A1/FPGA_Component_Inspector/raw/refs/heads/'+branch+'/release/'+name+'_full.zip','bit_sha256':receipt['bit_sha256'],'zip_sha256':receipt['zip_sha256'],'remote_sources':638,'remote_payloads':len(payload),'merged_to_main':False,'field_acceptance_pending':True}
save(validation/'final_github_receipt.json',final);save(Path('C:/Users/Li47/Desktop')/(name+'_GitHub回执.json'),final)
print(json.dumps(final,ensure_ascii=False,indent=2),flush=True)
