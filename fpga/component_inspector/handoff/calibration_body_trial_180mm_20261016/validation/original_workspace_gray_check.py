from pathlib import Path
import re,json
root=Path.cwd();audit=root/'tmp/body180_r1_20261016/work/audit_v3';paths={}
for f in audit.glob('gray_fanout_*.timing'):
 text=f.read_text(encoding='utf-8-sig')
 for chunk in text.split('Path Group')[1:]:
  header=chunk.split('Statistics:')[0]
  if '*continuous_processing*bridge/write_gray' not in header or 'Type           :     SMD' not in chunk:continue
  positions=list(re.finditer(r'^Slack\s*:\s*([-\d.]+)ns',chunk,re.M))
  for i,m in enumerate(positions):
   s=chunk[m.start():positions[i+1].start() if i+1<len(positions) else len(chunk)]
   src=re.search(r'^Begin Point\s*:\s*(\S+)',s,re.M)[1];dst=re.search(r'^End Point\s*:\s*(\S+)',s,re.M)[1]
   slack=float(m[1]);budget=float(re.search(r'^Budget\s*:\s*([-\d.]+)ns',s,re.M)[1]);assert slack>=0 and budget==8
   sm=re.search(r'/(read|write)_(?:gray|bin)_reg\[(\d+)\]',src);dm=re.search(r'/(read|write)_gray_sync1_reg\[(\d+)\]',dst)
   clocks=re.findall(r'triggered by clock (\S+)\s+\{',s)
   matched=bool(sm and dm and sm.groups()==dm.groups())
   key=(src,dst);entry={'source':src,'destination':dst,'same_logical_bit':matched,'clock_domains':clocks,'budget_ns':budget,'slack_ns':slack}
   if key not in paths or slack<paths[key]['slack_ns']:paths[key]=entry
result=sorted(paths.values(),key=lambda v:(v['source'],v['destination']))
summary=(audit/'exceptions.timing').read_text(encoding='utf-8-sig').split('MCP/SMD Details')[0]
row=re.search(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+set_max_delay -datapath_only 8.0 -from \[get_regs \{\*continuous_processing',summary,re.M)
endpoint_count=len({v['destination'] for v in result})
assert row and tuple(map(int,row.groups()))==(22,22,0,0)
assert endpoint_count==21 and len(result)==29
for direction in ['read','write']:
 for bit in range(10):
  text=(audit/f'gray_{direction}_{bit}.timing').read_text(encoding='utf-8-sig')
  selected=[c for c in text.split('Path Group') if '*continuous_processing*bridge/write_gray' in c and 'Type           :     SMD' in c]
  assert len(selected)==1 and 'Budget              : 8.000ns' in selected[0] and float(re.search(r'Slack\s*:\s*([-\d.]+)ns',selected[0])[1])>=0
assert all('continuous_processing$bridge/' in v['source'] and 'continuous_processing$bridge/' in v['destination'] for v in result)
out={'status':'PASS','logical_bits':20,'constraint_matched_paths':22,'constraint_dominated_paths':22,'constraint_ignored_paths':0,'unique_reported_physical_endpins':endpoint_count,'reported_paths':len(result),'all_matched_and_dominant':True,'minimum_slack_ns':min(v['slack_ns'] for v in result),'note':'Exception summary counts22 matching paths, not logical bus bits. Retain the separate20 logical bindings at8ns; additionally check29 reported physical data/control paths across21 endpins at8ns. Global routed STA verifies all applied constraints. No constraint or RTL change.','paths':result}
(root/'tmp/body180_r2_20261016/gray_constraint_paths.json').write_bytes((json.dumps(out,indent=2)+'\n').encode())
print(json.dumps(out,indent=2))
