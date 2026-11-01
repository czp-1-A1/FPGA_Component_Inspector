"""Create an isolated result-buffer experiment from the validated R50 inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from d3_slot_valid_storage_rewrite import apply, restore

p = argparse.ArgumentParser()
p.add_argument('--base', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
assert not a.out.exists()
shutil.copytree(a.base, a.out / 'project')
source = a.out / 'project/user_source/hdl_source/frame_shape_search.v'
raw = source.read_bytes()
text = source.read_text()
changed = apply(text)
assert restore(changed) == text
source.write_bytes(changed.encode())
sha = lambda data: hashlib.sha256(data).hexdigest()
result = {'status': 'ISOLATED_SLOT_VALID_BUFFER_NOT_PRODUCTION', 'base': str(a.base.resolve()),
          'changed_file': 'user_source/hdl_source/frame_shape_search.v',
          'before_sha256': sha(raw), 'after_sha256': sha(source.read_bytes()),
          'original_normalized_sha256': sha(text.encode()),
          'restored_normalized_sha256': sha(restore(changed).encode()),
          'scope': 'Same private buffer word values on every edge, including partial packets and error publication; 16 reset word-valid flags instead of resetting all data FFs. Main control and all legacy configurations unchanged.',
          'production_modified': False, 'resource_or_function_acceptance': False}
(a.out / 'PROVENANCE.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
