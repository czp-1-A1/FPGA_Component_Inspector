"""Promote the separately frozen refinement only after old jobs close cleanly."""
from pathlib import Path
import hashlib,json,time
root=Path(__file__).resolve().parent;repo=Path('D:/CodexWork/erole_fix_20261102');build=Path('D:/CodexWork/erole_build_r0_20261102')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf8'))
deadline=time.monotonic()+2400
while not all(p.exists() for p in [root/'native_r0/verification.json',root/'refine_run_r1/verification.json',build/'build_result.json']):
 assert time.monotonic()<deadline,'Old validation not complete; inspect exact processes and logs before promotion'
 time.sleep(2)
assert load(root/'native_r0/verification.json')['status']=='PASS'
assert load(root/'refine_run_r1/verification.json')['status']=='PASS_ISOLATED_REFINEMENT_NOT_YET_PRODUCTION'
manifest=load(build/'frozen_inputs.json')
for r,d in manifest.items():assert sha(repo/'fpga/component_inspector'/r)==d,r
p=repo/'fpga/component_inspector/user_source/hdl_source/frame_shape_search.v';data=p.read_bytes()
old=b'wire role_sprocket=row_role_required && small_pass && circular && !covers_body &&'
new=b'''// A fully quantized3x3 feed disk loses its circular fill ratio. Accept this
// upper-row role witness only; real lower apertures retain their own proof.
wire compact_feed_disk=width_now==3 && height_now==3 && component_count==9;
wire role_sprocket=row_role_required && small_pass && (circular || compact_feed_disk) && !covers_body &&'''
if b'\r\n' in data:new=new.replace(b'\n',b'\r\n')
assert data.count(old)==1;updated=data.replace(old,new)
preview=(root/'refine_phase_r1/frame_shape_search.v').read_bytes().replace(b'\r\n',b'\n')
assert updated.replace(b'\r\n',b'\n')==preview
p.write_bytes(updated)
# Preserve every original phase assertion; add feed-only negative witnesses.
p=repo/'tests/pocket_row_roles/tb_pocket_row_phases.sv';data=p.read_bytes();newline=b'\r\n' if b'\r\n' in data else b'\n'
needle=b'  $display("PASS POCKET ROW FOUR PHASES:8 fullRGB sources;'
assert data.count(needle)==1
extra=b'''  for(xp=0;xp<2;xp++)for(yp=0;yp<2;yp++)begin
   xyphase=xp;pocket_y=320+yp;pocket_gray=30;
   check_frame(0);
  end
'''.replace(b'\n',newline)
data=data.replace(needle,extra+b'  $display("PASS POCKET ROW FOUR PHASES:12 fullRGB sources;')
p.write_bytes(data)
f=repo/'tests/pocket_row_roles';derivation=load(f/'derivation.json')
derivation['base_sha256']=sha(repo/'tests/empty_only_stop/tb_empty_only_native.sv');derivation['new_sha256']=sha(f/'tb_pocket_row_native.sv')
derivation['hashes_are_actual_file_bytes']=True
(f/'derivation.json').write_text(json.dumps(derivation,indent=2)+'\n')
# Point all final acceptance and packaging at the refined frozen build.
for n in ['package_pocket_row_roles.py','review_pocket_row_resources.py','checkpoint_pocket_row_roles.py']:
 p=repo/'scripts'/n;d=p.read_bytes().replace(b'erole_build_r0_20261102',b'erole_build_r1_20261102').replace(b"'alarm_r0'",b"'alarm_r1'").replace(b"'contracts_r0'",b"'contracts_r1'").replace(b"'native_r0'",b"'native_r1'")
 if n=='package_pocket_row_roles.py':
  d=d.replace(b"['frozen_r2','frozen_r3','motion_r3']",b"['frozen_r4','frozen_r5']")
  d=d.replace(b'len(tests)==11',b'len(tests)==12').replace(b'_11_SOFTWARE_',b'_12_SOFTWARE_').replace(b"'software_contracts':11",b"'software_contracts':12")
  d=d.replace(b"'motion_run_r3']",b"'motion_run_r3','frozen_r4','frozen_r5','run_r4','run_r5','phases_r0','phase_trace_r0','refine_phase_r1','refine_run_r1','native_r0']")
 p.write_bytes(d)
state={'status':'PROMOTED_REFINEMENT_REQUIRES_FRESH_NATIVE_AND_ROUTING','prior_phase_failure':'phases_r0:case7 actual_E0 expected_E1','cause':'Weak8px locating disk quantizes to3x3,9/9cells; circular fill upper bound rejects it so no current feed row. Genuine lower aperture remains unclassified.','fix':'Only upper locating-role witness permits actual compact3x3/9cell disk; original lower aperture evidence and first8 phase goals preserved.','production_frame_sha256':sha(repo/'fpga/component_inspector/user_source/hdl_source/frame_shape_search.v'),'old_native_passed':True,'old_build_finished_but_not_release_candidate':True,'preview_4_contracts_passed':True,'next_build':'D:/CodexWork/erole_build_r1_20261102','field_acceptance':False}
(root/'refinement_status.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps(state,indent=2),flush=True)
