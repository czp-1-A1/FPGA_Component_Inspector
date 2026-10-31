"""Exhaust the rewritten 14-bit distance algebra for the actual LINE_X."""
from pathlib import Path
import argparse,hashlib,json,time
import numpy as np
from d3_check_prepare_rewrite import NEW_GAP,NEW_RETIRE

a=argparse.ArgumentParser();a.add_argument('--source',type=Path,required=True);a.add_argument('--out',type=Path,required=True);x=a.parse_args()
p=x.source/'user_source/hdl_source/observed_classified_pocket_counter.v';s=p.read_text()
assert s.count(NEW_GAP)==s.count(NEW_RETIRE)==1
# t spans every residue of old_x + sign-extended missed_dx (a superset of
# reachable tracks). Additions/subtractions below model signed 14-bit stores.
wrap=lambda n:((n+8192)&16383)-8192
t=np.arange(-8192,8192,dtype=np.int32);count=0;started=time.monotonic()
for line in [640]:
 for step in range(-4096,4096):
  travelled=wrap(t+step)
  old_right=wrap(travelled-line);new_right=wrap(t+int(wrap(step-line)))
  old_left=wrap(line-travelled);new_left=wrap(int(wrap(line-step))-t)
  assert np.array_equal(old_right,new_right) and np.array_equal(old_left,new_left),(line,step)
  count+=2*len(t)
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
result={'status':'PASS_EXHAUSTIVE_CHECK_DISTANCE_MODULO_14','source_sha256':sha(p),'script_sha256':sha(Path(__file__)),'line_x':[640],'aggregate_track_residues':16384,'signed_gap_steps':8192,'directions':2,'comparisons':count,'seconds':round(time.monotonic()-started,3),'scope':'All 14-bit aggregate-track residues and all signed 13-bit frame gap steps, both directions, actual production LINE_X=640. Equality of the signed 14-bit distance preserves comparison against every signed 32-bit guard. Frame-parameter stability/cancellation and fresh RAM data require separate RTL paired tests; this is not full formal counter equivalence.'}
x.out.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],count)
