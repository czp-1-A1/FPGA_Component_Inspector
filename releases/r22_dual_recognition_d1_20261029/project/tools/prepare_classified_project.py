"""Prepare relocatable TD run descriptors from the single checked-in .al.

Only generated project descriptors/settings are rewritten. RTL, pins and SDC
remain byte-identical. No tool execution, board access, or release promotion.
"""
from pathlib import Path
import argparse, hashlib, json, os, re

def prepare(project, td):
    entry = project / 'td_project/camera_to_dsi_display.al'
    text = entry.read_text(encoding='utf-8')
    files = re.findall(r'<File Path="([^"]+)"', text)
    inputs = {}
    for rel in files:
        p = (entry.parent / rel).resolve()
        if not p.is_file():
            raise RuntimeError('Missing project dependency: ' + str(p))
        p.relative_to(project)
        inputs[p.relative_to(project).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    flow = td / 'scripts/DefaultFlow.tcl'
    if not flow.is_file():
        raise RuntimeError('Missing TD DefaultFlow: ' + str(flow))
    for stage in ['syn_1', 'phy_1']:
        wd = entry.parent / 'camera_to_dsi_display_Runs' / stage
        wd.mkdir(parents=True, exist_ok=True)
        prj = re.sub(r'(<Project\b[^>]*\bPath=")[^"]*', lambda m: m[1] + wd.as_posix(), text, count=1)
        def pathfix(match):
            p = (entry.parent / match[1]).resolve()
            return '<File Path="' + Path(os.path.relpath(p, wd)).as_posix() + '"'
        prj = re.sub(r'<File Path="([^"]+)"', pathfix, prj)
        (wd / 'camera_to_dsi_display.prj').write_text(prj, encoding='utf-8')
        cfg = '''# Derived TD6.2 descriptor; speed and physical clocks unchanged.
set ADCList {"../../../user_source/constraints_source/pin.adc"}
set IpADCList { ddr2 ../../../user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc }
set IpSDCList { ddr2 ../../../user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc w128_d512_fifo ../../../user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl }
set SDCList {"../../camera_to_dsi_display.sdc"}
set area_option -packarea
set device_name ph1_35p.db
set package_name PH1P35MDG324
set prj_name {camera_to_dsi_display}
set speed 3
set top_model_name {design_top_wrapper}
'''
        cfg += 'set start_step read_design\nset end_step opt_gate\nset run_type syn\n' if stage == 'syn_1' else '''set arr_filter false
set phyWildParams {place seed 1 place logic_level_opt on place opt_timing high place effort high place fix_hold on}
set drHoldFix on
set parent ../syn_1
set start_step opt_place
set end_step bitgen
set run_type phy
'''
        (wd / 'settings.cfg').write_text(cfg, encoding='utf-8')
        (wd / 'build.tcl').write_text('if {[catch {\nsource {' + flow.as_posix() + '''}
analyze_clock -detail
check_timing -file constraint_coverage.txt -verbose
} reason]} {puts stderr $reason; exit 1}
exit 0
''', encoding='utf-8')
    # The constraints path list also contains the DDR IP dependencies above.
    for rel in ['user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc',
                'user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc',
                'user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl']:
        p = project / rel
        if not p.is_file():
            raise RuntimeError('Missing IP constraint: ' + str(p))
        inputs[rel] = hashlib.sha256(p.read_bytes()).hexdigest()
    for rel, digest in inputs.items():
        assert hashlib.sha256((project / rel).read_bytes()).hexdigest() == digest, rel
    result = {'status': 'PASS_INTERNAL_DEPENDENCIES_AND_PRODUCTION_INPUT_IDENTITY',
              'project': str(project), 'td': str(td), 'inputs': inputs,
              'physical_and_software_acceptance': 'NOT_ASSERTED_BY_PREPARATION'}
    (entry.parent / 'classified_prepare.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--td', type=Path, default=Path('D:/td6.2.1'))
    args = parser.parse_args()
    result = prepare(args.project.resolve(), args.td.resolve())
    print('PASS portable TD preparation:', len(result['inputs']), 'production dependencies; no RTL/SDC changes')
