from pathlib import Path
from collections import Counter
import re,json,hashlib
root=Path(__file__).resolve().parent.parent
record=root/'开发实施/验收记录/20261008_A3528调参判定_轮次2'
old=root/'开发实施/验收记录/20261007_A3528临时判定_轮次1'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
current,prior=load(record/'manifest.json'),load(old/'manifest.json')
def summary(path):
    table=read(path).split('MCP/SMD Details')[0]
    entries=[]
    for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',table,re.M):
        entries.append(dict(total=int(m[1]),dominated=int(m[2]),shadowed=int(m[3]),ignored=int(m[4]),constraint=m[5]))
    return entries
canonical=summary(record/'td_reports/phy_1/camera_to_dsi_display_exception.timing')
previous=summary(old/'td_reports/phy_1/camera_to_dsi_display_exception.timing')
mailbox=[x for x in canonical if '[get_regs {' in x['constraint']]
previous_mailbox=[x for x in previous if '[get_regs {' in x['constraint']]
assert len(canonical)==len(previous)==31 and len(mailbox)==24
assert [x['constraint'] for x in mailbox]==[x['constraint'] for x in previous_mailbox], 'Review changed mailbox constraints before release'
mailbox_counts_changed=[{'constraint':x['constraint'],'v1_total':y['total'],'v2_total':x['total']} for x,y in zip(mailbox,previous_mailbox) if x!=y]
assert [x['constraint'] for x in mailbox if x['shadowed']] == [x['constraint'] for x in previous_mailbox if x['shadowed']]
assert all(x['total']>0 and x['ignored']==0 for x in canonical)
assert current['coverage_summary']==prior['coverage_summary'], 'Review changed coverage categories before release'
def warning_lines(path):
    lines=[x for x in read(path).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',x)]
    return Counter(re.sub(r'(design_top_wrapper\.v)\(\d+\)',r'\1(LINE)',x) for x in lines)
warning_comparison={}
for stage in ['syn_1','phy_1']:
    now=warning_lines(record/'td_reports'/stage/'build_console.log')
    then=warning_lines(old/'td_reports'/stage/'build_console.log')
    warning_comparison[stage]={'current_lines':sum(now.values()),'v1_lines':sum(then.values()),'added':list((now-then).elements()),'removed':list((then-now).elements())}
report=record/'td_reports/phy_1/camera_to_dsi_display_pr.timing'
timing=read(report)
assert 'Confidence          : Routed' in timing
assert 'Check Corner        : Both (Slow and Fast)' in timing
corners=re.findall(r'^(Slow|Fast)\s*\|\s*yes\s+yes',timing,re.M)
assert corners==['Slow','Fast']
sw=re.findall(r'SWNS\s*:\s*([-\d.]+)ns',timing)
hw=re.findall(r'HWNS\s*:\s*([-\d.]+)ns',timing)
assert sw and hw and all(float(x)>=0 for x in sw+hw)
violations=re.findall(r'(\d+) Viol Endpoints',timing)
assert violations and all(int(x)==0 for x in violations)
data={'status':'current_constraints_met_existing_coverage_limits_retained','reviewer':'root read-only report audit; no additional agent','timing_corners':corners,'setup_wns_ns':[float(x) for x in sw],'hold_wns_ns':[float(x) for x in hw],'all_reported_viol_endpoints_zero':True,'resources':current['resources'],'v1_resource_delta':{k:current['resources'][k]-prior['resources'][k] for k in ['slice_used','lut6_used','reg_used','eram_used','dsp_used']},'coverage_summary_unchanged':True,'max_delay_rules':31,'mailbox_register_rules':24,'mailbox_constraints_unchanged':True,'mailbox_path_count_changes':mailbox_counts_changed,'mailbox_path_count_explanation':'Mapped timing path counts can change after removing top-level comparisons; all eight payload rules remain matched/dominated with ignored0, and the same four handshake rules remain shadowed. Counts are not register widths.','all_max_delay_rules_matched_ignored_zero':True,'canonical_max_delay_summary':canonical,'parser_correction':'R2 manifest parser uses only MCP/SMD Summary; 24 mailbox rows. The R1 inherited parser included detail repetitions; R1 evidence remains preserved.','warning_comparison':warning_comparison,'limits':['STA coverage is 94.57%, not 100%; prior clock/PLL/I/O and exception limitations remain.','Slice77.87% is in the project caution band 70-80%; no new image buffers or DSP resources.','Layout-resource delta reflects the whole mapped placement; LUT increase is not proof of new RTL logic.','No physical board acceptance or classifier-specific individual path report.'],'report_hashes':[{'path':x,'sha256':sha(record/'td_reports/phy_1'/x)} for x in ['camera_to_dsi_display_pr.timing','camera_to_dsi_display_phy.area','camera_to_dsi_display_exception.timing','constraint_coverage.txt']]}
data['limits'][0]=f"STA coverage is {current['timing']['sta_coverage_percent']:.2f}%, not 100%; prior clock/PLL/I/O and exception limitations remain."
data['limits'][1]=f"Slice{current['resources']['slice_percent']:.2f}% is in the project caution band 70-80%; no new image buffers or DSP resources."
(record/'report_audit.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in data.items() if k not in ['canonical_max_delay_summary','warning_comparison','report_hashes']},ensure_ascii=True))
print(json.dumps({stage:{'current_lines':v['current_lines'],'v1_lines':v['v1_lines'],'added_count':len(v['added']),'removed_count':len(v['removed']),'added_examples':v['added'][:3],'removed_examples':v['removed'][:3]} for stage,v in warning_comparison.items()}))
