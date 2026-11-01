from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parent;repo=Path('D:/CodexWork/erole_fix_20261102')
out=root/'refine_phase_r1';out.mkdir(exist_ok=False)
for p in (root/'frozen_r3').glob('*.v'):shutil.copy2(p,out/p.name)
p=out/'frame_shape_search.v';s=p.read_text()
old='wire role_sprocket=row_role_required && small_pass && circular && !covers_body &&'
new='''// A fully quantized3x3 feed disk loses its circular fill ratio. Accept this
// upper-row role witness only; real lower apertures retain their own proof.
wire compact_feed_disk=width_now==3 && height_now==3 && component_count==9;
wire role_sprocket=row_role_required && small_pass && (circular || compact_feed_disk) && !covers_body &&'''
assert s.count(old)==1;s=s.replace(old,new);p.write_text(s)
for n in ['tb_pocket_row_phases','tb_pocket_row_contract','tb_tail_29_plus_7_rgb','tb_small_tail_closed_loop']:
 shutil.copy2(repo/'tests/pocket_row_roles'/(n+'.sv'),out/(n+'.sv'))
hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()}
(out/'INPUT_SHA256.json').write_text(json.dumps(hashes,indent=2)+'\n')
print('Frozen isolated refinement; old native/build current production NOT edited; original8 assertions unchanged')
