from pathlib import Path
import json,hashlib
root=Path.cwd();base=root/'tmp/shape_v5_r4_20261013';inputs=json.loads((base/'inputs.json').read_text())
checks=[('shape_model','shape_v5_r4_20261013'),('direct_modes','shape_v5_r4_20261013'),('shape_video','shape_v5_r6_20261013'),('direct_osd','shape_v5_r6_20261013'),('writer_epoch','shape_v5_r6_20261013'),('video_fallback_display','shape_v5_r6_20261013'),('shape_snapshot','shape_v5_r8_20261013'),('shape_osd','shape_v5_r8_20261013'),('wb_epoch','shape_v5_r8_20261013'),('display_state','shape_v5_r8_20261013'),('observation','shape_v5_r8_20261013')]
results=[]
for test,round in checks:
 p=root/'tmp'/round/'sim/modelsim_work'/test/'console.log';s=p.read_text(encoding='utf-8-sig',errors='replace');assert 'PASS ' in s and '** Fatal:' not in s and '** Error:' not in s,test
 e=dict(name=test,round=round,console_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),status='PASS');results.append(e)
# Verify compiled production dependencies are unchanged for earlier accepted unit/legacy tests as well.
for test,round in checks:
 old={e['path']:e['sha256'] for e in json.loads((root/'tmp'/round/'inputs.json').read_text())}
 for e in inputs:assert old[e['path']]==e['sha256'],(test,e['path'])
(base/'verified_tests_pending_isp.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print('Verified',len(results),'completed tests with identical production inputs; shape_isp still running')
