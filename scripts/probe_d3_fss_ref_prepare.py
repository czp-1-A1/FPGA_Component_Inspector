"""Create one isolated candidate; production and all other sources stay intact."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from d3_fss_ref_prepare_rewrite import apply, restore

parser = argparse.ArgumentParser()
parser.add_argument('--base', type=Path, required=True)
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args()
assert not args.out.exists()
shutil.copytree(args.base, args.out / 'project')
path = args.out / 'project/user_source/hdl_source/frame_shape_search.v'
raw = path.read_bytes()
original = raw.decode().replace('\r\n', '\n')
changed = apply(original)
assert restore(changed) == original
path.write_bytes(changed.encode())
sha = lambda data: hashlib.sha256(data).hexdigest()
receipt = {'status': 'ISOLATED_FSS_REFERENCE_PREPARATION_ONLY',
           'base': str(args.base.resolve()), 'production_modified': False,
           'changed_file': 'user_source/hdl_source/frame_shape_search.v',
           'before_sha256': sha(raw), 'after_sha256': sha(path.read_bytes()),
           'original_normalized_sha256': sha(original.encode()),
           'restored_normalized_sha256': sha(restore(changed).encode()),
           'scope': 'Five predicates prepared in existing REF_WAIT; fresh REF_CHECK dark_word selects. Original 9-bit comparisons, accumulator, 32-bit diagnostics, phases, cycles and priorities retained.'}
(args.out / 'PROVENANCE.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
