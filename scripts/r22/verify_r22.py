"""Portable read-only identity/evidence verification for the exact R22 release.

Requires Python3 standard library only. Does not synthesize, simulate or touch
a board. Full independent replays are provided in the immutable evidence ZIP.
"""
from pathlib import Path,PurePosixPath
import argparse,hashlib,json,zipfile

NAME='PocketCount_SW3_LocalEdge_r22_20261027'
MANIFEST_SHA='8e81b47dcd40d88b461aae525e946d5c41bd175691bc66f896b9dc34989541bf'
BIT_SHA='a07bd753296d320c495f234669477563f1f34cdc60af87089575b3bc1bad4df2'
ZIP_SHA='1ffbc00ab9b2573da938afa623d238f3545a2b4b89a8acda5962b7cc2917d8d6'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))

def verify(root,archive=None):
 release=root/'releases/r22_20261027';source=root/'fpga/component_inspector'
 frozen=release/'frozen_inputs.json';assert sha(frozen)==MANIFEST_SHA,'Frozen manifest identity mismatch'
 M=load(frozen);assert len(M)==615
 for n,h in M.items():assert sha(source/n)==h,('source',n)
 assets=load(release/'ASSETS_SHA256.json')
 for n,row in assets.items():assert (release/n).stat().st_size==row['bytes'] and sha(release/n)==row['sha256'],n
 assert sha(release/(NAME+'.bit'))==BIT_SHA
 archive=archive or release/(NAME+'_full.zip');assert sha(archive)==ZIP_SHA
 with zipfile.ZipFile(archive) as z:
  names=z.namelist();assert len(names)==len(set(names)) and z.testzip() is None
  assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts for n in names)
  payload=json.loads(z.read('PAYLOAD_SHA256.json'));assert len(payload)==3874 and set(names)==set(payload)|{'PAYLOAD_SHA256.json'}
  for n,row in payload.items():
   data=z.read(n);assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256'],('payload',n)
  assert json.loads(z.read('frozen_inputs.json'))==M
  for n,h in M.items():assert hashlib.sha256(z.read('fpga/component_inspector/'+n)).hexdigest()==h,('archived_source',n)
  assert hashlib.sha256(z.read(NAME+'.bit')).hexdigest()==BIT_SHA
  hardware=json.loads(z.read('hardware_inputs.json'));assert len(hardware)==102
  for n,h in hardware.items():assert M[n]==h,n
  tests=json.loads(z.read('validation/test_archive_map.json'));assert len(tests)==144
  for n,row in tests.items():
   for rel,h in {**row['inputs'],**row['runtime_inputs']}.items():assert M[rel]==h,(n,rel)
   for name,key in [('compile.log','compile_sha256'),('console.log','console_sha256')]:assert hashlib.sha256(z.read(row['archive_project']+'/sim/modelsim_work/'+n+'/'+name)).hexdigest()==row[key],(n,name)
  v=json.loads(z.read('validation/verification.json'));assert v['tests']==144 and v['independent_references']==46
  assert v['resources']=={'slice':19016,'eram':101,'dsp':27,'pll':5} and v['slice_percent']<90
  t=v['timing_ns'];assert t['SWNS']>=0 and t['HWNS']>=0 and t['STNS']==t['HTNS']==0
 feedback=load(release/'FIELD_FEEDBACK.json');assert feedback['normal_speed']=='USER_REPORTED_PASS' and feedback['high_speed']=='PENDING'
 return {'status':'PASS_R22_615_SOURCE_3874_PAYLOAD_144_LOG_102_DEPENDENCY_IDENTITY','manifest_sha256':MANIFEST_SHA,'bit_sha256':BIT_SHA,'zip_sha256':ZIP_SHA,'normal_speed':'USER_REPORTED_PASS','high_speed':'PENDING','scope':'Identity/evidence verification, not a fresh hardware build or all-speed board acceptance'}

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--archive',type=Path);p.add_argument('--output',type=Path);a=p.parse_args()
 result=verify(a.root.resolve(),a.archive.resolve() if a.archive else None)
 if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
 print(json.dumps(result,indent=2))
