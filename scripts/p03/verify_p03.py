"""Verify frozen P03 source, bit and archived evidence; never build or flash."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import importlib.util
import json
import re
import shutil
import tempfile
import zipfile

BIT_SHA='21d1004fc74505ae7b5ee0c05aadc9c07cb780a2dd0fd763115b3796def060db'
SOURCE_SHA='4f1b15dd327c2e51a6b538502d6cf4ec660d63cc9f74e8d3320aeff9cb347fc2'
sha=lambda data:hashlib.sha256(data).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))

def verify(repo,archive=None):
    project=repo/'fpga/component_inspector';release=repo/'releases/p03_20261025'
    frozen=load(release/'frozen_inputs.json');hardware=load(release/'hardware_inputs.json')
    assert sha((release/'frozen_inputs.json').read_bytes())==SOURCE_SHA
    assert (project/'P03_FROZEN_INPUTS.json').read_bytes()==(release/'frozen_inputs.json').read_bytes()
    assert (project/'P03_DESIGN_INPUTS.json').read_bytes()==(release/'hardware_inputs.json').read_bytes()
    assert len(frozen)==526 and len(hardware)==100
    for n,h in frozen.items():
        path=(project/n).resolve();path.relative_to(project.resolve())
        assert sha(path.read_bytes())==h,('Frozen source changed',n)
    for n,h in hardware.items():assert frozen[n]==h
    entry=project/'td_project/camera_to_dsi_display.al'
    observed={(entry.parent/n).resolve().relative_to(project.resolve()).as_posix()
              for n in re.findall(r'<File Path="([^"]+)"',entry.read_text(encoding='utf-8'))}
    observed.update(['user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc',
                     'user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc',
                     'user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl'])
    assert observed==set(hardware),'Dependency closure mismatch'
    info=load(release/'INTEGRATION.json');delivery=load(release/'LOCAL_DELIVERY_RECEIPT.json')
    assert info['frozen_manifest_sha256']==SOURCE_SHA
    assert info['hardware_manifest_sha256']==sha((release/'hardware_inputs.json').read_bytes())
    old=load(repo/'releases/p02_20261024/hardware_inputs.json')
    delta={n for n in hardware if hardware[n]!=old[n]}
    assert delta==set(info['hardware_changed'])=={
        'user_source/hdl_source/present_surface_check.v','user_source/hdl_source/compact_template_rom.v'}
    assert info['hardware_added']==[] and info['hardware_unchanged']==98
    parent=load(repo/'releases/p02_20261024/frozen_inputs.json')
    relocation={'td_project/camera_to_dsi_display.al',
        'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.prj',
        'td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display.prj'}
    assert len(parent)==504
    for n,h in parent.items():
        if n not in delta|relocation:assert frozen[n]==h,('Unrelated P02 input changed',n)
    bit=release/delivery['bit'];assert bit.stat().st_size==1789539 and sha(bit.read_bytes())==BIT_SHA
    soft=load(release/'software_verification.json')
    assert soft['status']=='PASS_P03_STANDING_SOFTWARE_GATE' and soft['compiled_dependencies']==hardware
    assert soft['original_related_tests']==24 and not soft['original72_all_rerun']
    index=load(release/'EVIDENCE_INDEX.json');assert len(index)==31
    for n,item in index.items():
        path=(release/item['path']).resolve();path.relative_to(release.resolve())
        data=path.read_bytes();assert sha(data)==item['sha256']==soft['checks'][n]['sha256'],n
        if path.suffix=='.log':
            text=data.decode('utf-8-sig')
            assert 'PASS ' in text and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',text),n
        else:
            result=json.loads(data);assert result['status']=='PASS'
            assert sum(f['pixels'] for f in result['frames'])==3686400
            assert sum(f['mismatch'] for f in result['frames'])==0
    native=load(release/'native_raster_verification.json')
    assert native['surface_decisions']==28 and native['probe_exact_mean_comparisons']==70
    assert load(release/'scope_verification.json')['status']=='PASS_DECLARED_P02_TO_P03_SCOPE_AND_EXACT_HARDWARE100'
    assert load(release/'FIELD_FEEDBACK.json')['board_acceptance']=='PENDING'
    spec=importlib.util.spec_from_file_location('p03_physical',project/'tools/verify_classified_physical.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    scratch_root=repo/'tmp';scratch_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='p03_verify_',dir=scratch_root) as directory:
        scratch=Path(directory).resolve();scratch.relative_to(scratch_root.resolve())
        shutil.copytree(release/'evidence/classified_audit',scratch/'classified_audit')
        (scratch/'td_project').mkdir()
        shutil.copyfile(project/'td_project/camera_to_dsi_display.sdc',scratch/'td_project/camera_to_dsi_display.sdc')
        physical=module.verify(scratch)
    assert physical['timing_ns']==delivery['timing_ns']
    area=(release/'evidence/physical/camera_to_dsi_display_phy.area').read_text(encoding='utf-8')
    for resource,value in [('slice',18385),('lut6',16565),('reg',21244),('eram',103),('dsp',28),('pll',5)]:
        assert re.search(r'^#'+resource+r'\s+'+str(value)+r'\s*',area,re.M),resource
    members=None
    if archive:
        public=load(release/'public_package.json');assert sha(archive.read_bytes())==public['archive_sha256']
        with zipfile.ZipFile(archive) as z:
            names=z.namelist();assert len(names)==len(set(names)) and z.testzip() is None
            inventory=json.loads(z.read('CONTENTS_SHA256.json'));assert set(names)==set(inventory)|{'CONTENTS_SHA256.json'}
            for n,item in inventory.items():
                assert not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts
                data=z.read(n);assert len(data)==item['bytes'] and sha(data)==item['sha256'],n
            for n,h in frozen.items():assert sha(z.read('project/'+n))==h,n
            assert sha(z.read(bit.name))==BIT_SHA
            members=len(names)
    return dict(status='PASS_P03_GIT_SOURCE526_BIT_EVIDENCE31_ROUTED_DEPENDENCIES100',
                source_count=526,hardware_dependencies=100,software_evidence_groups=31,protected_p02_inputs=499,
                bit_sha256=BIT_SHA,source_manifest_sha256=SOURCE_SHA,timing_ns=physical['timing_ns'],
                archive_members=members,board_acceptance='PENDING',new_full_build_or_board_operation=False)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--archive',type=Path)
    args=parser.parse_args()
    print(json.dumps(verify(args.repo.resolve(),args.archive),indent=2))
