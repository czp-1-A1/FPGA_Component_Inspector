from pathlib import Path
import hashlib,json,re,subprocess
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
read=lambda p:p.read_text(encoding='utf-8-sig')
load=lambda p:json.loads(read(p));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
metadata=load(project/'td_project/current_codex_build.json')
assert metadata['purpose']=='3528_FIXED_DIRECT_GRAY_EDGE_INDEPENDENT_V4'
release=project/'release/direct_detection_v4_20261013'
audit=load(release/'audit.json');inputs=load(release/'build_inputs.json')
assert len(inputs)==211 and len(audit['tests'])==9 and audit['status']=='PASS_source_simulation_and_routed_build'
assert sha(root/metadata['release']['path'])==metadata['release']['sha256']==audit['bit']['sha256']
assert audit['bit']['sha256'] in read(release/'SHA256.txt')
for e in inputs:assert sha(project/e['path'])==e['sha256'],e['path']
names=['20261013_B上孔下件几何错位修复_轮次1','20261013_A灰度边缘独立检测恢复_V4轮次1',
 '20261013_A_V4发布完整性复核_轮次1','20261013_A_V4现场对象有效性与边缘语义_轮次1']
counts={}
for name in names:
 record=root/'开发实施/验收记录'/name;manifest=load(record/'manifest.json')
 for e in manifest:
  p=record/e['path'];assert sha(p)==e['sha256'],str(p)
  if 'bytes' in e:assert p.stat().st_size==e['bytes'],str(p)
 counts[name]=len(manifest)
v4=root/metadata['validation_record'].removesuffix('.md')
for test in audit['tests']:
 candidates=list(v4.glob('**/'+test['test']+'/console.log'));assert len(candidates)==1,(test['test'],candidates)
 console=read(candidates[0]);assert all(p in console for p in test['passes']),test['test']
 assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',console),test['test']
paths=[p.decode('utf-8') for p in subprocess.check_output(['git','ls-files','--modified','--others','--exclude-standard','-z'],cwd=root).split(b'\0') if p]
selected=[root/p for p in paths if (p=='AGENTS.md' or p.startswith(('fpga/component_inspector/','开发实施/'))) and (root/p).is_file()]
assert all(p.stat().st_size<100*1024*1024 for p in selected)
result=dict(status='PASS_V4_SYNC_INTEGRITY',production_inputs=211,accepted_software_tests=9,
 archives=counts,archive_files=sum(counts.values()),bit_sha256=metadata['release']['sha256'],
 selected_changed_files=len(selected),new_payload_MiB=round(sum(p.stat().st_size for p in selected)/1048576,2),
 onsite='PENDING')
(root/'tmp/v4_sync_integrity_result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
