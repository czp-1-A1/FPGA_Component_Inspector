"""Relocate P01 descriptors with the measured build's original seed2 settings."""
from pathlib import Path
import argparse
import json
import re
from prepare_classified_project import prepare


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--td', type=Path, required=True,
                        help='TD directory containing scripts/DefaultFlow.tcl (this machine: TD/doc)')
    args = parser.parse_args()
    project = args.project.resolve()
    entry = project / 'td_project/camera_to_dsi_display.al'
    content = entry.read_text(encoding='utf-8')
    content = re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',
                     lambda m: m[1] + entry.parent.as_posix(), content, count=1)
    entry.write_text(content, encoding='utf-8')
    result = prepare(project, args.td.resolve())
    cfg = project / 'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg'
    content = cfg.read_text(encoding='utf-8')
    assert content.count('place seed 1 ') == 1
    cfg.write_text(content.replace('place seed 1 ', 'place seed 2 '), encoding='utf-8')
    result['physical_seed'] = 2
    (project / 'td_project/p01_relocation.json').write_text(
        json.dumps(result, indent=2), encoding='utf-8')
    print('PASS P01 relocation:', len(result['inputs']), 'dependencies, original seed2; no RTL/SDC edits')
