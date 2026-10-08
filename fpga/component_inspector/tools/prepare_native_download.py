"""Prepare a separate TD GUI project around the already frozen stage2 bit."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,zipfile

ap=argparse.ArgumentParser()
ap.add_argument('destination',type=Path)
ap.add_argument('--build',type=Path,default=Path('C:/Users/Li47/Desktop/aa/native_1080p30_r4_20261007'))
ap.add_argument('--from-release',action='store_true',help='Use only the committed release ZIP, reports and bit; no local build cache required')
args=ap.parse_args()
engine=Path(__file__).resolve().parents[1]
release=engine/'release/native_1080p30/stage2_base_20261008'
dest=args.destination.resolve();build=args.build.resolve()
assert not dest.exists(),'Refusing to overwrite an existing download project'
assert str(dest).isascii()
assert ' ' not in str(dest)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
freeze=json.loads((release/'td_build_snapshot.json').read_text())
entries=[e for e in freeze['inputs'] if e['path'].startswith(('user_source/','td_project/'))]
from_release=args.from_release or not build.is_dir()
if from_release:
    with zipfile.ZipFile(release/'input_snapshot.zip') as archive:
        for entry in entries:
            assert hashlib.sha256(archive.read(entry['path'])).hexdigest()==entry['sha256'],entry['path']
        for entry in entries:
            target=dest/entry['path'];target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(archive.read(entry['path']))
    shutil.copytree(release/'reports',dest/'td_project/camera_to_dsi_display_Runs')
    shutil.copy2(release/'camera_to_dsi_display.bit',dest/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit')
else:
    for entry in entries:
        source=build/entry['path']
        assert source.is_file() and sha(source)==entry['sha256'],entry['path']
    for entry in entries:
        target=dest/entry['path'];target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(build/entry['path'],target)
    shutil.copytree(build/'td_project/camera_to_dsi_display_Runs',dest/'td_project/camera_to_dsi_display_Runs')
project=dest/'td_project/camera_to_dsi_display.al'
original=project.read_text(encoding='utf-8')
text=re.sub(r'(<Project\b[^>]*\bPath=")[^"]*(")',lambda m:m[1]+project.parent.as_posix()+m[2],original,count=1)
text=re.sub(r'<TD_Version>[^<]*</TD_Version>','<TD_Version>6.2.178840</TD_Version>',text,count=1)
project.write_text(text,encoding='utf-8')
for rel in re.findall(r'<File Path="([^"]+)"',text):
    source=(project.parent/rel).resolve()
    assert source.is_relative_to(dest) and source.is_file(),rel
bit=dest/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit'
candidate=json.loads((release/'release.json').read_text())
assert sha(bit)==candidate['bit_sha256']==sha(release/'camera_to_dsi_display.bit')
for entry in entries:
    if entry['path']!='td_project/camera_to_dsi_display.al':
        assert sha(dest/entry['path'])==entry['sha256'],entry['path']
info=dict(status='DIAGNOSTIC_CANDIDATE_NOT_ACCEPTED',project=str(project),bit=str(bit),
          bit_sha256=sha(bit),source_manifest=str(release/'td_build_snapshot.json'),
          inputs=len(entries),al_sha256=sha(project),
          source='committed release ZIP and reports' if from_release else 'local frozen build including run databases',
          al_changes='Project Path relocated; TD_Version set to6.2.178840; source list and build inputs unchanged',
          board_actions_performed=False)
(dest/'download_project.json').write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
(dest/'README.txt').write_text('Open td_project/camera_to_dsi_display.al in TD6.2.178840.\n'
 'Use the existing phy_1 bit for volatile FPGA download; no rebuild is needed.\n'
 'If asked to choose a bit, select td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit.\n'
 'SHA256 '+sha(bit)+'\n'
 'Native1920x1080p30 stage2 RAW/GRAY diagnostic candidate; not physically accepted.\n'
 'Keep the previous permanent Flash image. Rebuilding makes a new candidate requiring new validation.\n',encoding='utf-8')
print(json.dumps(info,indent=2))
