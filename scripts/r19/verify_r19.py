"""Verify published R19 bytes and recorded evidence. Does not build or flash.

Archive mode independently checks every public payload and112 actual
compile/runtime/log identities. Recorded references are checked as evidence;
this command does not rerun RTL or the26 pixel oracles.
"""
from pathlib import Path
import argparse,hashlib,importlib.util,json,posixpath,re,shutil,sys,tempfile,zipfile
MANIFEST='684e4fa0c723d0f38c14b0acb7f54e39c3e12e5f3fd00e89f1733a0b89f6bd0e'
BIT='feaa11d1df1e009b10b239da85916f4c7709cf80a9d77c44850250a68800b444'
sha=lambda b:hashlib.sha256(b).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def text(b):return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
def verify(repo,archive=None):
 repo=repo.resolve();source=repo/'fpga/component_inspector';release=repo/'releases/r19_20261025';info=load(release/'RELEASE.json')
 M=load(release/'frozen_inputs.json');H=load(release/'hardware_inputs.json');assert len(M)==559 and len(H)==101
 assert sha((release/'frozen_inputs.json').read_bytes())==MANIFEST
 assert (source/'R19_FROZEN_INPUTS.json').read_bytes()==(release/'frozen_inputs.json').read_bytes()
 for n,h in M.items():
  p=(source/n).resolve();p.relative_to(source.resolve());assert sha(p.read_bytes())==h,('Frozen source',n)
 for n,h in H.items():assert M[n]==h,n
 assert sha((release/info['bit']).read_bytes())==BIT==info['bit_sha256']
 assert (release/info['bit']).stat().st_size==1789539
 soft=load(release/'all112_verification.json');assert soft['manifest_sha256']==MANIFEST and len(soft['tests'])==112
 refs=load(release/'references_status.json');assert refs['status']=='PASS_ALL26_FROZEN_INDEPENDENT_REFERENCES' and len(refs['completed'])==26
 assert all(x['exit_code']==0 for x in refs['completed']) and refs['manifest_sha256']==MANIFEST
 assert load(release/'FIELD_FEEDBACK.json')['board_acceptance']=='NOT_COMPLETE'
 for line in (release/'SHA256.txt').read_text(encoding='utf8').splitlines():
  h,n=line.split('  ',1);p=(release/n).resolve();p.relative_to(release.resolve());assert sha(p.read_bytes())==h,n
 # Recompute the full physical evidence audit using frozen code in a fresh
 # scratch tree. Keep generated reports for diagnosis; never delete sources.
 scratch_root=repo/'tmp';scratch_root.mkdir(exist_ok=True)
 scratch=Path(tempfile.mkdtemp(prefix='r19_audit_',dir=scratch_root)).resolve();scratch.relative_to(scratch_root.resolve())
 for folder in ['classified_audit','gray_packing_audit']:
  shutil.copytree(release/'evidence'/folder,scratch/folder)
 (scratch/'td_project').mkdir();shutil.copy2(source/'td_project/camera_to_dsi_display.sdc',scratch/'td_project/camera_to_dsi_display.sdc')
 sys.path.insert(0,str(source/'tools'))
 spec=importlib.util.spec_from_file_location('r19_physical',source/'tools/verify_classified_physical.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 physical=module.verify(scratch);assert physical['timing_ns']==info['timing_ns']
 assert physical['max_delays_matched']==46 and physical['max_delays_ignored']==0 and physical['gray_bits_dominating']==20 and physical['new_mailbox_groups']==6
 assert info['resources']['slice']==18971 and info['resources']['eram']==101
 assert info['resources']['slice']<=19094 and info['timing_ns']['SWNS']>=0 and info['timing_ns']['HWNS']>=0
 checked_logs=0;payload_count=None
 if archive:
  assert sha(archive.read_bytes())==info['public_archive_sha256']
  with zipfile.ZipFile(archive) as z:
   names=z.namelist();payload=json.loads(z.read('PAYLOAD_SHA256.json'));assert len(names)==len(set(names)) and set(names)==set(payload)|{'PAYLOAD_SHA256.json'} and z.testzip() is None
   for n,row in payload.items():
    b=z.read(n);assert len(b)==row['bytes'] and sha(b)==row['sha256'],n
   for n,h in M.items():assert sha(z.read('fpga/component_inspector/'+n))==h,n
   assert sha(z.read(info['bit']))==BIT
   export=json.loads(z.read('PUBLIC_EXPORT.json'));assert export['omitted_entries']==['field_analysis/video_inputs.json']
   mapping=json.loads(z.read('validation/test_archive_map.json'));assert set(mapping)==set(soft['tests']) and len(mapping)==112
   sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',text(z.read('fpga/component_inspector/sim/run_modelsim.ps1'))))
   for n,row in mapping.items():
    prefix=row['archive_project']+'/sim/modelsim_work/'+n+'/'
    cb=z.read(prefix+'compile.log');lb=z.read(prefix+'console.log')
    assert sha(cb)==row['compile_sha256'] and sha(lb)==row['console_sha256'],n
    comp=text(cb);log=text(lb);assert sentinels[n] in log and re.search(r'Errors:\s*0,\s*Warnings:',log),n
    assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',comp+log),n
    actual={}
    for line in comp.splitlines():
     if 'vlog ' in line and '-work' in line:
      for token in line.split():
       if token.endswith(('.v','.sv')):
        rel=posixpath.normpath('sim/'+token.replace('\\','/'));assert not rel.startswith('../')
        assert rel in M;actual[rel]=M[rel]
    assert actual==row['inputs'],(n,'Compiled input set')
    for rel,h in row['runtime_inputs'].items():assert M[rel]==h,n
    checked_logs+=1
   payload_count=len(payload)
 result={'status':'PASS_R19_FROZEN_SOURCE_BIT_PHYSICAL_AUDIT_AND_ARCHIVE_LOG_IDENTITIES','sources':559,'hardware_dependencies':101,'recorded_tests':112,'archive_logs_rechecked':checked_logs,'recorded_reference_groups':26,'reference_oracles_rerun':False,'rtl_or_place_route_rerun':False,'payloads':payload_count,'bit_sha256':BIT,'manifest_sha256':MANIFEST,'resources':info['resources'],'timing_ns':info['timing_ns'],'board_acceptance':'NOT_COMPLETE_NORMAL_SPEED_EMPTY_MISSES_REPORTED','audit_scratch':str(scratch)}
 (scratch/'publication_verification.json').write_text(json.dumps(result,indent=2),encoding='utf8');return result
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--archive',type=Path);p.add_argument('--output',type=Path);a=p.parse_args();result=verify(a.repo,a.archive)
 if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
 print(json.dumps(result,indent=2))
