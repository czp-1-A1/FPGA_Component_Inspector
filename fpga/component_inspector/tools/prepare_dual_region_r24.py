"""Restore exact R24 inputs to a fresh ASCII path and retain seed2."""
from pathlib import Path
import argparse
import importlib.util
import json


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--td', type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    spec = importlib.util.spec_from_file_location('portable', source / 'tools/prepare_portable_project.py')
    portable = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portable)
    result = portable.prepare(source, source / 'R24_FROZEN_INPUTS.json', args.work.resolve(), args.td.resolve())
    settings = args.work / 'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg'
    text = settings.read_text(encoding='utf8')
    assert 'place seed 1 ' in text
    settings.write_text(text.replace('place seed 1 ', 'place seed 2 '), encoding='utf8')
    result['physical_seed'] = 2
    (args.work / 'r24_preparation.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print('PASS R24 fresh preparation:', len(result['inputs']), 'project/IP dependencies; seed2')
