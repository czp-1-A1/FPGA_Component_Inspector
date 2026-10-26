"""Create a fresh portable R19 project; never synthesize or operate hardware."""
from pathlib import Path
import argparse,importlib.util,json
from verify_r19 import verify
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--work',type=Path,required=True);p.add_argument('--td',type=Path,required=True);a=p.parse_args()
 repo=a.repo.resolve();verify(repo);source=repo/'fpga/component_inspector'
 spec=importlib.util.spec_from_file_location('r19_prepare',source/'tools/prepare_portable_project.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 result=m.prepare(source,repo/'releases/r19_20261025/frozen_inputs.json',a.work.resolve(),a.td.resolve())
 assert len(result['inputs'])==101
 assert result['inputs']==json.loads((repo/'releases/r19_20261025/hardware_inputs.json').read_text(encoding='utf8'))
 print('PASS R19 fresh portable project:559 frozen inputs and101 exact hardware dependencies; no build/flash; original SDC and seed preserved.')
