"""Restore exact P03 in a fresh portable TD directory without building/flashing."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from verify_p03 import verify,load

def prepare(repo,work,td):
    validation=verify(repo)
    assert not work.exists(),'Refuse to overwrite: '+str(work)
    assert str(work).isascii() and ' ' not in str(work),'Use an ASCII path without spaces'
    assert (td/'scripts/DefaultFlow.tcl').is_file(),'TD path must contain scripts/DefaultFlow.tcl'
    p=repo/'fpga/component_inspector';release=repo/'releases/p03_20261025'
    frozen=load(release/'frozen_inputs.json');hardware=load(release/'hardware_inputs.json')
    work.mkdir(parents=True)
    for n in frozen:
        target=work/n;target.resolve().relative_to(work.resolve())
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p/n,target)
    for n in ['P03_FROZEN_INPUTS.json','P03_DESIGN_INPUTS.json','P03_ACCEPTANCE_GATE.json',
              'P03_SCOPE_VERIFICATION.json','P03_SOFTWARE_VERIFICATION.json','P03_NATIVE_RASTER_VERIFICATION.json',
              'p02_final_inputs_before_p03.json','P01_MEASUREMENT_GATE_REFERENCE.json',
              'P02_DESIGN_INPUTS.json','P02_ACCEPTANCE_GATE.json','p01_final_inputs_before_p02.json']:
        shutil.copyfile(p/n,work/n)
    result=subprocess.run([sys.executable,str(work/'tools/prepare_p03_project.py'),
        '--project',str(work),'--td',str(td)],capture_output=True,text=True)
    (work/'p03_relocation_console.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    assert result.returncode==0,'Relocation failed; see p03_relocation_console.log'
    relocated=load(work/'td_project/p03_relocation.json')
    assert relocated['inputs']==hardware and relocated['physical_seed']==2
    for n,h in hardware.items():assert hashlib.sha256((work/n).read_bytes()).hexdigest()==h,n
    receipt=dict(status='PASS_FRESH_P03_SOURCE526_DEPENDENCIES100_SEED2_NO_BUILD',project=str(work),
        source_verification=validation,inputs=hardware,build_executed=False,board_operation=False)
    (work/'p03_preparation.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    return receipt

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--work',type=Path,required=True)
    parser.add_argument('--td',type=Path,required=True)
    args=parser.parse_args()
    print(prepare(args.repo.resolve(),args.work.resolve(),args.td.resolve())['status'])
