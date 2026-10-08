"""Preserve prior frozen HDMI failures/observations without rewriting them."""
from pathlib import Path
import hashlib,json,shutil,zipfile
engine=Path(__file__).resolve().parents[1];repo=engine.parents[1]
workspace=repo.parent
out=repo/'开发实施/验收记录/20261008_1080p30_HDMI上板失败_轮次1/rounds'
if out.exists():raise SystemExit('Refusing to replace archived rounds')
out.mkdir(parents=True)
roots=sorted(workspace.glob('native_1080p30_hdmi_failure_r*_20261008'))
roots+=sorted(workspace.glob('native_1080p30_hdmi_probe_r*_20261008'))
roots+=sorted(workspace.glob('native_1080p30_hdmi_tpg_r[1-7]_20261008'))
for root in roots:
 meta=json.loads((root/'freeze.json').read_text());dest=out/root.name;dest.mkdir()
 shutil.copy2(root/'freeze.json',dest/'freeze.json')
 with zipfile.ZipFile(dest/'inputs.zip','w',zipfile.ZIP_DEFLATED) as z:
  for e in meta['inputs']:
   p=root/e['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256']
   z.write(p,e['path'])
 for folder in ('sim','td_project'):
  if not (root/folder).exists():continue
  for p in (root/folder).rglob('*'):
   if p.is_file() and p.suffix in ('.log','.logw','.txt','.rpt','.cfg','.tcl','.prj','.area'):
    target=dest/p.relative_to(root);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
manifest=[dict(path=p.relative_to(out).as_posix(),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
 for p in sorted(out.rglob('*')) if p.is_file()]
(out/'SHA256SUMS.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Archived {len(roots)} immutable rounds, {len(manifest)} payload files')
