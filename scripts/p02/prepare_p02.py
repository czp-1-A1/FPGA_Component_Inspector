"""Restore exact P02 inputs into a new portable TD project; never build or flash."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from verify_p02 import verify,load

def prepare(repo,work,td):
    verification=verify(repo)
    assert not work.exists(),'Refuse to overwrite: '+str(work)
    assert str(work).isascii() and ' ' not in str(work),'Use an ASCII path without spaces'
    assert (td/'scripts/DefaultFlow.tcl').is_file(),'TD path must contain scripts/DefaultFlow.tcl'
    project=repo/'fpga/component_inspector'
    frozen=load(repo/'releases/p02_20261024/frozen_inputs.json')
    expected=load(repo/'releases/p02_20261024/hardware_inputs.json')
    work.mkdir(parents=True)
    for name in frozen:
        destination=work/name;destination.resolve().relative_to(work.resolve())
        destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(project/name,destination)
    for name in ['P02_DESIGN_INPUTS.json','P02_ACCEPTANCE_GATE.json',
                 'P01_MEASUREMENT_GATE_REFERENCE.json','p01_final_inputs_before_p02.json']:
        shutil.copyfile(project/name,work/name)
    shutil.copyfile(project/'P02_FROZEN_INPUTS.json',work/'P02_FROZEN_INPUTS.json')
    result=subprocess.run([sys.executable,str(work/'tools/prepare_p02_project.py'),
                           '--project',str(work),'--td',str(td)],capture_output=True,text=True)
    (work/'p02_relocation_console.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    assert result.returncode==0,'Relocation failed; see p02_relocation_console.log'
    relocation=load(work/'td_project/p02_relocation.json')
    assert relocation['inputs']==expected and relocation['physical_seed']==2
    for name,digest in expected.items():assert hashlib.sha256((work/name).read_bytes()).hexdigest()==digest,name
    receipt=dict(status='PASS_FRESH_P02_SOURCE504_DEPENDENCIES100_SEED2_NO_BUILD',
                 project=str(work),td=str(td),inputs=expected,source_verification=verification,
                 build_executed=False,board_operation=False)
    (work/'p02_preparation.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    return receipt

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--work',type=Path,required=True)
    parser.add_argument('--td',type=Path,required=True)
    args=parser.parse_args()
    print(prepare(args.repo.resolve(),args.work.resolve(),args.td.resolve())['status'])
