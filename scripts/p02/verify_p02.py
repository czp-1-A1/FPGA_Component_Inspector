"""Verify the exact P02 Git source, delivered bit and archived acceptance evidence."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import importlib.util
import json
import re
import shutil
import tempfile
import zipfile

BIT_SHA='dfd2e5c8f7081f32f526be0b9e02e754649f1509d872e7cd12aac4ffba9199b8'
SOURCE_SHA='f51a6f86874a8544f7ee95def859f0a875f31a8b170c79316b153e1e00d9f21c'
HARDWARE_SHA='52909475069d102783cbd37ace6a5af49d7531be654bf4b0eee652347dd27a51'
sha=lambda data:hashlib.sha256(data).hexdigest()
load=lambda path:json.loads(path.read_text(encoding='utf-8-sig'))

def verify(repo,archive=None):
    project=repo/'fpga/component_inspector';release=repo/'releases/p02_20261024'
    manifest=release/'frozen_inputs.json';hardware_path=release/'hardware_inputs.json'
    assert sha(manifest.read_bytes())==SOURCE_SHA and sha(hardware_path.read_bytes())==HARDWARE_SHA
    assert (project/'P02_FROZEN_INPUTS.json').read_bytes()==manifest.read_bytes()
    assert (project/'P02_DESIGN_INPUTS.json').read_bytes()==hardware_path.read_bytes()
    frozen=load(manifest);hardware=load(hardware_path)
    assert len(frozen)==504 and len(hardware)==100
    for name,digest in frozen.items():
        target=(project/name).resolve();target.relative_to(project.resolve())
        assert sha(target.read_bytes())==digest,('Source changed',name)
    for name,digest in hardware.items():assert frozen[name]==digest
    entry=project/'td_project/camera_to_dsi_display.al'
    observed={(entry.parent/name).resolve().relative_to(project.resolve()).as_posix()
              for name in re.findall(r'<File Path="([^"]+)"',entry.read_text(encoding='utf-8'))}
    observed.update(['user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc',
                     'user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc',
                     'user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl'])
    assert observed==set(hardware),'TD dependency closure mismatch'
    info=load(release/'INTEGRATION.json');bit=release/load(release/'LOCAL_DELIVERY_RECEIPT.json')['bit']
    assert bit.stat().st_size==1789539 and sha(bit.read_bytes())==BIT_SHA
    assert info['frozen_manifest_sha256']==SOURCE_SHA and info['hardware_manifest_sha256']==HARDWARE_SHA
    assert len(info['hardware_added'])==2 and len(info['hardware_changed'])==6 and info['hardware_unchanged']==92
    software=load(release/'software_verification.json')
    assert software['status']=='PASS_P02_SURFACE_SOFTWARE_GATE'
    assert software['compiled_dependencies']==hardware and software['original_related_tests']==24
    assert software['original72_all_rerun'] is False
    index=load(release/'EVIDENCE_INDEX.json');assert len(index)==30
    for name,record in index.items():
        target=(release/record['path']).resolve();target.relative_to(release.resolve())
        data=target.read_bytes();assert sha(data)==record['sha256']==software['checks'][name]['sha256']
        if target.suffix=='.log':
            text=data.decode('utf-8-sig')
            assert 'PASS ' in text and not re.search(r'(?m)^#?\s*\*\* (?:Fatal|Error):',text),name
        else:
            data=json.loads(data);assert data['status']=='PASS'
            assert sum(f['pixels'] for f in data['frames'])==3686400
            assert sum(f['mismatch'] for f in data['frames'])==0
    assert load(release/'native_raster_verification.json')['surface_decisions']==24
    feedback=load(release/'FIELD_FEEDBACK.json')
    assert feedback['user_statement_verbatim']=='测试正常' and feedback['associated_delivered_bit_sha256']==BIT_SHA
    # Apply the unchanged production physical verifier to the real archived reports.
    spec=importlib.util.spec_from_file_location('p02_physical',project/'tools/verify_classified_physical.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    scratch_root=repo/'tmp';scratch_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='p02_verify_',dir=scratch_root) as work:
        work=Path(work).resolve();assert work.parent==scratch_root.resolve()
        shutil.copytree(release/'evidence/routed',work/'classified_audit')
        (work/'td_project').mkdir()
        shutil.copyfile(project/'td_project/camera_to_dsi_display.sdc',work/'td_project/camera_to_dsi_display.sdc')
        physical=module.verify(work)
    assert physical['timing_ns']=={'SWNS':0.005,'HWNS':0.02,'STNS':0.0,'HTNS':0.0}
    area=(release/'evidence/final_routed.area').read_text(encoding='utf-8-sig')
    for resource,number in [('slice',18266),('eram',103),('dsp',28),('pll',5)]:
        assert re.search(r'^#'+resource+r'\s+'+str(number)+r'\s+',area,re.M),resource
    archive_members=None
    if archive:
        public=load(release/'public_package.json')
        assert sha(archive.read_bytes())==public['archive_sha256']
        with zipfile.ZipFile(archive) as z:
            names=z.namelist();assert len(names)==len(set(names)) and z.testzip() is None
            inventory=json.loads(z.read('CONTENTS_SHA256.json'))
            assert set(names)==set(inventory)|{'CONTENTS_SHA256.json'}
            for name,record in inventory.items():
                assert not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts
                data=z.read(name);assert len(data)==record['bytes'] and sha(data)==record['sha256'],name
            for name,digest in frozen.items():assert sha(z.read('project/'+name))==digest,name
            assert sha(z.read(bit.name))==BIT_SHA
            archive_members=len(names)
    return dict(status='PASS_P02_GIT_SOURCE504_BIT_EVIDENCE30_ROUTED_AND_DEPENDENCIES100',
                source_count=504,hardware_dependencies=100,software_evidence_groups=30,
                bit_sha256=BIT_SHA,source_manifest_sha256=SOURCE_SHA,physical=physical['timing_ns'],
                field_feedback='User reported 测试正常; no new quantitative matrix asserted',
                archive_members=archive_members,new_simulation_or_build=False)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--archive',type=Path)
    args=parser.parse_args()
    print(json.dumps(verify(args.repo.resolve(),args.archive),ensure_ascii=True,indent=2))
