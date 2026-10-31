"""Create the authorized RAW / monochrome-edge candidate; keep production intact."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from d3_raw_edge_rewrite import FILES, rewrite

p = argparse.ArgumentParser()
p.add_argument('--baseline', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
assert not a.out.exists()
manifest = json.loads((a.baseline / 'frozen_inputs.json').read_text())
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert len(manifest) == 704
for rel, digest in manifest.items():
    assert sha(a.baseline / 'project' / rel) == digest, rel
shutil.copytree(a.baseline / 'project', a.out / 'project')
changes = {}
for name in FILES:
    rel = 'user_source/hdl_source/' + name
    source = a.out / 'project' / rel
    original = source.read_text()
    changed = rewrite(name, original)
    assert rewrite(name, changed, inverse=True) == original, name
    source.write_bytes(changed.encode())
    changes[rel] = {'before_sha256': manifest[rel], 'after_sha256': sha(source),
                    'normalized_before_sha256': hashlib.sha256(original.encode()).hexdigest()}
for rel, digest in manifest.items():
    assert sha(a.out / 'project' / rel) == changes.get(rel, {}).get('after_sha256', digest), rel
result = {'status': 'ISOLATED_RAW_MONOCHROME_EDGE_DISPLAY_NOT_FUNCTION_OR_PHYSICAL_ACCEPTANCE',
          'baseline': str(a.baseline.resolve()), 'changed': changes,
          'unchanged_inputs': 700, 'rewrite_helper_sha256': sha(Path(__file__).with_name('d3_raw_edge_rewrite.py')),
          'scope': 'Only display selection/rendering and optional RGB background cache. RAW unchanged, monochrome Sobel mask in edge mode. Gradient magnitudes, feature taps, row credit schedule, fault guards, count/parking modules, IO/clocks/SDC unchanged. SW2 edge toggle, SW1 ignored in this profile; legacy parameter0 retains four modes.',
          'production_modified': False, 'hardware_operated': False}
(a.out / 'PROVENANCE.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
