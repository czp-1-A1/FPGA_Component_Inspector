from pathlib import Path
import subprocess
name='fpga/component_inspector/sim/run_modelsim.ps1'
original=subprocess.check_output(['git','show','HEAD:'+name]).decode('utf-8')
frozen=Path('tmp/video_first_v10_r4_20261015/sim/run_modelsim.ps1').read_bytes().decode('utf-8')
for parent,new in [('frame_wait_metadata','video_first'),('video_fallback_display','video_late_display'),('frame_process','frame_cadence')]:
 old_line=next(line for line in original.splitlines(keepends=True) if 'Name="'+parent+'"' in line)
 new_line=next(line for line in frozen.splitlines() if 'Name="'+new+'"' in line)
 ending='\r\n' if old_line.endswith('\r\n') else '\n'
 original=original.replace(old_line,new_line+ending+old_line)
original=original.replace('"frame_stop", "frame_process"','"frame_stop", "frame_process", "frame_cadence"')
normalized_original=original.replace('\r\n','\n').lstrip('\ufeff')
normalized_frozen=frozen.replace('\r\n','\n').lstrip('\ufeff')
if normalized_original!=normalized_frozen:
 import difflib
 print(''.join(difflib.unified_diff(normalized_original.splitlines(True),normalized_frozen.splitlines(True)))[:3000])
 raise AssertionError('Runner has a difference beyond EOL/BOM; no write performed')
Path(name).write_bytes(original.encode('utf-8'))
print('Restored original per-line EOL style; normalized bytes equal the tested frozen runner')
