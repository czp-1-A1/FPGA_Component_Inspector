from pathlib import Path
import json,re,sys
root=Path.cwd();rd=root/'tmp'/sys.argv[1];p=root/'fpga/component_inspector'
data=json.loads((p/'tools/shape3528/calibration_180mm/session_holes80_1092_40_20261016/dataset.json').read_text(encoding='utf-8'))
rows=[r for r in data['readings'] if r['observation_threshold']==80]
assert len(rows)==4 and all(r['clip']==0 and r['sample_complete'] for r in rows)
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
s=read(rd/'work/sim/modelsim_work/cal180_holes/console.log')
records={int(k):int(word,16) for k,word in re.findall(r'REF CAL80 pattern=(\d+) records=([0-9a-f]+)',s)}
assert set(records)==set(range(9))
truth=[r for r in rows if r['truth']=='empty'];checked=0
for k in range(4):
 rec=(records[0]>>(76*k))&((1<<76)-1);r=truth[k%2]
 assert rec>>75==1 and (rec>>73)&3==3
 assert ((rec>>49)&127,(rec>>42)&127,(rec>>56)&8191)==(r['width_px'],r['height_px'],r['area_px'])
 checked+=1
assert records[3]==records[5]==0
for k in range(4):
 rec=(records[8]>>(76*k))&((1<<76)-1);assert rec>>75==1 and (rec>>73)&3==1
for k in range(4):
 rec=(records[1]>>(76*k))&((1<<76)-1)
 assert ((rec>>73)&3,(rec>>49)&127,(rec>>42)&127,(rec>>56)&8191)==(2,36,44,1456)
result=dict(status='PASS',cal80_rows=4,cal_empty_records_compared=checked,full_patterns=9,reference='Independent decode of actual simulation records against manually transcribed camera CAL numbers; synthetic fixtures, not native-frame accuracy',body_t100_exact_geometry_unchanged=True,feed_and_gap_no_empty=True,small_bright_object_not_empty=True)
(rd/'independent_hole_reference.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
