"""Isolate the frame-only CHECK preparation experiment without changing production."""
from pathlib import Path
import argparse,hashlib,json,shutil
from d3_check_prepare_rewrite import apply,restore

a=argparse.ArgumentParser();a.add_argument('--base',type=Path,required=True);a.add_argument('--out',type=Path,required=True);a.add_argument('--variant',choices=['offset','minimal'],default='offset');x=a.parse_args()
assert not x.out.exists()
shutil.copytree(x.base,x.out/'project')
p=x.out/'project/user_source/hdl_source/observed_classified_pocket_counter.v'
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
before=sha(p);s=p.read_text();changed=apply(s,x.variant);assert restore(changed)==s
p.write_bytes(changed.encode())
(x.out/'PROVENANCE.json').write_text(json.dumps({'variant':x.variant,'base':str(x.base.resolve()),'before_sha256':before,'after_sha256':sha(p),'production_modified':False,'scope':'Capture frame-only CHECK parameters in the existing READ_CHECK; retain fresh track_word at CHECK, modulo-14-bit arithmetic, original action cycles and cancellation priorities. No added FSM stage or feature removal.'},indent=2)+'\n')
print(x.out)
