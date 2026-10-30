"""Compare like-for-like TD reports; never label synthesis estimates as routed usage."""
from pathlib import Path
import argparse, hashlib, json, re

ROOT = Path(__file__).resolve().parents[1]
TMP = Path('E:/2026FPGA/.codex_tmp')
HANDOFF = TMP/'r27b_dual_merge_handoff_20261030/R27B_DualColumn_Code_and_Handoff/build_evidence/td_project/camera_to_dsi_display_Runs'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def report(path):
    text = path.read_text(errors='replace')
    result = {'path': str(path), 'sha256': sha(path)}
    for name in ['slice', 'slice*', 'eram', 'dsp', 'pll', 'reg', 'lut']:
        m = re.search(r'^#'+re.escape(name)+r'\s+(\d+)(?:\s+out of\s+(\d+)\s+([\d.]+)%)?', text, re.M)
        if m:
            result[name] = {'used': int(m[1])}
            if m[2]:
                result[name].update(capacity=int(m[2]), percent=float(m[3]))
    result['hierarchy'] = []
    for line in text.splitlines():
        cols = [x.strip() for x in line.split('|')[1:-1]]
        if len(cols) == 13 and cols[2].isdigit():
            result['hierarchy'].append(dict(zip(
                ['instance','module','logic_lut','ripple','seq','eram','dsp','dram_lut','shifter_lut','f7mux','f8mux','pll','ddr'],
                cols[:2]+list(map(int, cols[2:])))))
    return result

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--candidate',type=Path,required=True)
    ap.add_argument('--out',type=Path,default=ROOT/'docs/D3_RESOURCE_ANALYSIS.json')
    a=ap.parse_args()
    sources={
        'RL4_single_stop_final':TMP/'r22_wide_stop_build_r1_20261028/runs/phy_1/final.area',
        'RL7_single_stop_final':ROOT/'releases/r22_relay_shift_alarm_v7_20261028/build/runs/phy_1/final.area',
        'RL7_single_stop_synthesis':ROOT/'releases/r22_relay_shift_alarm_v7_20261028/build/runs/syn_1/camera_to_dsi_display_gate.area',
        'R27B_dual_count_final':HANDOFF/'phy_1/camera_to_dsi_display_phy.area',
        'R27B_dual_count_synthesis':HANDOFF/'syn_1/camera_to_dsi_display_gate.area',
        'D3_initial_repeated_station_synthesis':TMP/'d3_dual_stop_resource_probe_r3_20261030/runs/syn_1/camera_to_dsi_display_gate.area',
        'D3_direct_global_before_width_address_opt_synthesis':TMP/'d3_dual_stop_build_r9_20261030/runs/syn_1/camera_to_dsi_display_gate.area',
        'D3_direct_global_default_mapping_synthesis':TMP/'d3_dual_stop_build_r11_resource_opt_20261030/runs/syn_1/camera_to_dsi_display_gate.area',
        'D3_candidate_synthesis':a.candidate/'runs/syn_1/camera_to_dsi_display_gate.area',
    }
    final=a.candidate/'runs/phy_1/final.area'
    if final.is_file():sources['D3_candidate_final']=final
    reports={k:report(p) for k,p in sources.items() if p.is_file()}
    assert all(k in reports for k in ['RL4_single_stop_final','RL7_single_stop_final','R27B_dual_count_final'])
    result={'status':'REPORT_COMPARISON_NOT_BIT_ACCEPTANCE', 'reports':reports,
        'rules':['slice* is a synthesis estimate; slice in final.area is actual physical allocation.',
                 'Hierarchy rows include descendants. Do not sum parent and child rows.',
                 'logic_lut/ripple/seq are not physical Slice counts.',
                 'Final resource fit alone is not setup/hold timing acceptance.'],
        'candidate_final_available':final.is_file()}
    strategy=a.candidate/'BUILD_STRATEGY.json'
    if strategy.is_file():result['candidate_build_strategy']={'sha256':sha(strategy),'settings':json.loads(strategy.read_text())}
    a.out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    for name,r in reports.items():print(name, {k:v for k,v in r.items() if k not in ['path','sha256','hierarchy']})
    base=reports['R27B_dual_count_synthesis']['hierarchy']
    cand=reports.get('D3_candidate_synthesis',reports['D3_direct_global_default_mapping_synthesis'])['hierarchy']
    for mod in ['dual_region_count_pipeline','frame_shape_search','local_edge_surface_check','dual_lane_parking','compact_inspector_osd']:
        print(mod, 'baseline', [x for x in base if x['module']==mod], 'candidate', [x for x in cand if x['module']==mod])

if __name__=='__main__':main()
