"""Compare saved D3 placements, with an explicit reversible-FSS exception."""
import argparse
import hashlib
import json
import re
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_placement(work):
    run = work / 'runs/phy_1'
    receipt = json.loads((work / 'PLACEMENT_RESULT.json').read_text())
    assert receipt['status'] == 'PLACED_ONLY_NOT_ROUTED_NOT_DELIVERABLE'
    assert sha(run / 'camera_to_dsi_display_place.db') == receipt['placement_database_sha256']
    assert sha(run / 'placed_intermediate.area') == receipt['area_sha256']
    timing_path = run / 'camera_to_dsi_display_place.timing'
    assert sha(timing_path) == receipt['timing_sha256']
    log_path = run / 'place_console.log'
    assert sha(log_path) == receipt['console_sha256']
    area = (run / 'placed_intermediate.area').read_text()
    timing = timing_path.read_text()
    log = log_path.read_text()
    resources = {}
    for key in ['slice', 'eram', 'dsp', 'pll']:
        m = re.search(r'(?m)^#' + key + r'\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%', area)
        assert m, key
        resources[key] = {'used': int(m[1]), 'total': int(m[2]), 'percent': float(m[3])}
    components = {}
    for key, pattern in {'logic_lut_slices': r'#with luts', 'adder_slices': r'#with adder',
                         'register_only_slices': r'#reg only', 'distributed_ram_slices': r'#used ram',
                         'registers': r'#reg', 'lut6': r'#lut6'}.items():
        match = re.search(r'(?m)^\s*' + pattern + r'\s+(\d+)', area)
        assert match, key
        components[key] = int(match[1])
    assert sum(components[key] for key in ['logic_lut_slices', 'adder_slices',
               'register_only_slices', 'distributed_ram_slices']) == resources['slice']['used']
    assert 'Confidence          : Placed' in timing
    m = re.search(r'SWNS:\s*([\d.-]+)ns, STNS:\s*([\d.-]+)ns\s+HWNS:\s*([\d.-]+)ns, HTNS:\s*([\d.-]+)ns', timing)
    assert m
    summary = dict(zip(['setup_wns_ns', 'setup_tns_ns', 'hold_wns_ns', 'hold_tns_ns'], map(float, m.groups())))
    clock_ids = dict(re.findall(r'(?m)^\s+(clk\d+):\s+[\d.]+\s+\d+\s+(\S+)\s*$', timing))
    clocks = {}
    for line in timing.splitlines():
        row = re.match(r'^\s*(clk\d+)\s+(?:(?:User|Inferred)\s+)?(?:GCLK|MLCLK|local)\s+(.+)$', line)
        if row:
            columns = row[2].split()
            assert len(columns) == 15, line
            clocks[clock_ids[row[1]]] = {
                'clock_id': row[1], 'period_ns': float(columns[2]),
                'setup_wns_ns': float(columns[6]), 'setup_tns_ns': float(columns[7]),
                'hold_wns_ns': float(columns[8]), 'hold_tns_ns': float(columns[9]),
                'fanout': int(columns[11]), 'max_logic_level': int(columns[12]),
            }
    assert len(clocks) == len(clock_ids) == 15, (len(clocks), len(clock_ids))
    congestion = []
    for block in log.split('Congestion index:')[1:]:
        indices = {k: float(v) for k, v in re.findall(r'top(1|5|10|15)\s*=\s*([\d.]+)', block.split('End congestion update', 1)[0])}
        assert len(indices) == 4
        congestion.append(indices)
    assert congestion
    return {'work': str(work), 'resources': resources, 'area_components': components, 'timing': summary,
            'clock_groups': clocks, 'congestion_snapshots': congestion,
            'final_estimated_congestion': congestion[-1],
            'manifest_sha256': sha(work / 'frozen_inputs.json'),
            'synthesis_database_sha256': sha(work / 'runs/syn_1/camera_to_dsi_display_gate.db'),
            'placement_receipt_sha256': sha(work / 'PLACEMENT_RESULT.json'),
            'place_log_sha256': sha(log_path), 'timing_sha256': sha(timing_path)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    variants = parser.add_mutually_exclusive_group()
    variants.add_argument('--fss-reference-preparation', action='store_true')
    variants.add_argument('--slot-valid-storage', action='store_true')
    variants.add_argument('--raw-edge-display', action='store_true')
    variants.add_argument('--essential-ui', action='store_true')
    args = parser.parse_args()
    before, after = read_placement(args.reference.resolve()), read_placement(args.work.resolve())
    source_relation = 'IDENTICAL_SOURCE_AND_SYNTHESIS_DB'
    if args.essential_ui:
        from probe_d3_essential_ui import rewrite
        baseline_manifest = json.loads((args.reference / 'frozen_inputs.json').read_text())
        candidate_manifest = json.loads((args.work / 'frozen_inputs.json').read_text())
        names = ['design_top_wrapper.v', 'classified_dual_page_osd.v', 'compact_template_rom.v', 'compact_inspector_osd.v']
        expected = {'user_source/hdl_source/' + name for name in names}
        assert set(baseline_manifest) == set(candidate_manifest)
        assert {n for n in baseline_manifest if baseline_manifest[n] != candidate_manifest[n]} == expected
        proof = json.loads((args.work/'ESSENTIAL_UI_PROOF.json').read_text())
        assert proof['status'] == 'PASS_ESSENTIAL_UI_SOURCE_AND_TARGETED_SIMULATIONS_NOT_PHYSICAL_ACCEPTANCE'
        assert proof['reference_manifest_sha256'] == before['manifest_sha256']
        assert proof['source_manifest_sha256'] == after['manifest_sha256'] and proof['selected_checks'] == 8
        assert proof['rewrite_helper_sha256'] == sha(Path(__file__).with_name('probe_d3_essential_ui.py'))
        for name in names:
            rel = 'user_source/hdl_source/' + name
            assert rewrite(name, (args.reference/'project'/rel).read_text()) == (args.work/'project'/rel).read_text()
        source_relation = 'AUTHORIZED_ESSENTIAL_DISPLAY_ONLY_700_OTHER_INPUTS_IDENTICAL'
    elif args.raw_edge_display:
        from d3_raw_edge_rewrite import FILES, rewrite
        baseline_manifest = json.loads((args.reference / 'frozen_inputs.json').read_text())
        candidate_manifest = json.loads((args.work / 'frozen_inputs.json').read_text())
        expected = {'user_source/hdl_source/' + name for name in FILES}
        assert set(baseline_manifest) == set(candidate_manifest)
        assert {name for name in baseline_manifest if baseline_manifest[name] != candidate_manifest[name]} == expected
        proof = json.loads((args.work / 'RAW_EDGE_DISPLAY_PROOF.json').read_text())
        assert proof['status'] == 'PASS_RAW_EDGE_DISPLAY_SOURCE_AND_TARGETED_CHECKS'
        assert proof['baseline_manifest_sha256'] == before['manifest_sha256']
        assert proof['source_manifest_sha256'] == after['manifest_sha256']
        assert proof['rewrite_helper_sha256'] == sha(Path(__file__).with_name('d3_raw_edge_rewrite.py'))
        for name in FILES:
            rel = 'user_source/hdl_source/' + name
            assert rewrite(name, (args.work/'project'/rel).read_text(), inverse=True) == (args.reference/'project'/rel).read_text()
        source_relation = 'AUTHORIZED_RAW_MONOCHROME_EDGE_DISPLAY_ONLY_700_OTHER_INPUTS_IDENTICAL'
    elif args.fss_reference_preparation or args.slot_valid_storage:
        if args.slot_valid_storage:
            from d3_slot_valid_storage_rewrite import restore
            proof_name = 'SLOT_VALID_STORAGE_PROOF.json'
            proof_status = 'PASS_SLOT_VALID_PRIVATE_BUFFER_SOURCE_AND_TARGETED_EQUIVALENCE'
        else:
            from d3_fss_ref_prepare_rewrite import restore
            proof_name = 'FSS_REFERENCE_PREPARATION_PROOF.json'
            proof_status = 'PASS_FSS_REFERENCE_PREPARATION_SOURCE_AND_TARGETED_EQUIVALENCE'
        baseline_manifest = json.loads((args.reference / 'frozen_inputs.json').read_text())
        candidate_manifest = json.loads((args.work / 'frozen_inputs.json').read_text())
        target = 'user_source/hdl_source/frame_shape_search.v'
        assert set(baseline_manifest) == set(candidate_manifest)
        assert {name for name in baseline_manifest if baseline_manifest[name] != candidate_manifest[name]} == {target}
        assert restore((args.work / 'project' / target).read_text()) == (args.reference / 'project' / target).read_text()
        proof = json.loads((args.work / proof_name).read_text())
        assert proof['status'] == proof_status
        assert proof['source_manifest_sha256'] == after['manifest_sha256']
        assert proof['after_sha256'] == candidate_manifest[target] and proof['before_sha256'] == baseline_manifest[target]
        source_relation = 'ONLY_CANONICALLY_REVERSIBLE_SLOT_VALID_STORAGE_DIFFERENCE' if args.slot_valid_storage else 'ONLY_CANONICALLY_REVERSIBLE_FSS_REFERENCE_PREPARATION_DIFFERENCE'
    else:
        assert before['manifest_sha256'] == after['manifest_sha256']
        assert before['synthesis_database_sha256'] == after['synthesis_database_sha256']
    assert set(before['clock_groups']) == set(after['clock_groups'])
    clock_delta = {}
    for name, group in after['clock_groups'].items():
        old = before['clock_groups'][name]
        assert group['period_ns'] == old['period_ns']
        clock_delta[name] = {key: round(group[key] - old[key], 6) for key in
                             ['setup_wns_ns', 'setup_tns_ns', 'hold_wns_ns', 'hold_tns_ns']}
    result = {'status': 'ESSENTIAL_UI_PLACEMENT_COMPARISON_ONLY' if args.essential_ui else 'RAW_EDGE_DISPLAY_PLACEMENT_COMPARISON_ONLY' if args.raw_edge_display else 'EQUIVALENT_SLOT_VALID_PLACEMENT_COMPARISON_ONLY' if args.slot_valid_storage else 'EQUIVALENT_FSS_PLACEMENT_COMPARISON_ONLY' if args.fss_reference_preparation else 'SAME_NETLIST_PLACEMENT_COMPARISON_ONLY',
              'source_relation': source_relation,
              'reference': before, 'candidate': after,
              'slice_delta': after['resources']['slice']['used'] - before['resources']['slice']['used'],
              'area_component_deltas': {key: value - before['area_components'][key]
                                         for key, value in after['area_components'].items()},
              'estimated_congestion_delta_percentage_points': {
                  key: round(value - before['final_estimated_congestion'][key], 6)
                  for key, value in after['final_estimated_congestion'].items()},
              'timing_delta_ns': {key: round(value - before['timing'][key], 6)
                                  for key, value in after['timing'].items()},
              'clock_group_deltas_ns': clock_delta,
              'routed_timing_or_routability_proven': False, 'deliverable_bit': False}
    (args.work / 'PLACEMENT_COMPARISON.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ['reference', 'candidate', 'clock_group_deltas_ns']}, indent=2))


if __name__ == '__main__':
    main()
