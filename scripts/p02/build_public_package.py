"""Make the P02 GitHub engineering archive from the immutable local delivery."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import re
import zipfile

BIT_SHA='dfd2e5c8f7081f32f526be0b9e02e754649f1509d872e7cd12aac4ffba9199b8'
LOCAL_ZIP_SHA='2957e9a60cbbd8c9e84b1597dd528cb14b63d1040efb4d9f4f3d6206722c72f8'
sha=lambda data:hashlib.sha256(data).hexdigest()

def build(source,destination,functional_commit):
    assert not destination.exists(), 'Never overwrite an archive'
    assert sha(source.read_bytes())==LOCAL_ZIP_SHA, 'Unexpected local P02 delivery'
    payload={}
    with zipfile.ZipFile(source) as z:
        assert z.testzip() is None
        old=json.loads(z.read('CONTENTS_SHA256.json'))
        assert len(z.namelist())==len(set(z.namelist()))==len(old)+1
        for name,record in old.items():
            data=z.read(name)
            assert sha(data)==record['sha256'] and len(data)==record['bytes'],name
            if name.startswith('evidence/p01_fiveclips/') and PurePosixPath(name).name not in [
                    'ANALYSIS.json','readouts.csv','analyze_probe_readouts.py']:
                continue
            payload[name]=data
    frozen=json.loads(payload['P02_FROZEN_INPUTS.json'])
    assert len(frozen)==504
    for name,h in frozen.items():assert sha(payload['project/'+name])==h,name
    bit=next(n for n in payload if n.endswith('.bit') and '/' not in n)
    assert sha(payload[bit])==BIT_SHA
    # Engineering inputs and synthetic validation images are publishable;
    # original phone captures, photos and their personal source paths stay local.
    private_path=re.compile(rb'C:[/\\]+Users[/\\]|xwechat|wxid_|D:[/\\]+wx[/\\]',re.I)
    token=re.compile(rb'(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{30,})')
    text_suffixes={'.md','.json','.csv','.py','.ps1','.v','.sv','.tcl','.sdc','.adc','.cfg','.prj','.al','.log','.txt'}
    for name,data in payload.items():
        if PurePosixPath(name).suffix.lower() in text_suffixes:
            assert not private_path.search(data),('Personal source path in public text',name)
            assert not token.search(data),('Credential-like text in public payload',name)
    record=dict(version='P02',tag='p02-present-surface-20261024',functional_commit=functional_commit,
        bit=bit,bit_sha256=BIT_SHA,frozen_source_count=504,
        source_manifest_sha256=sha(payload['P02_FROZEN_INPUTS.json']),
        original_local_archive_sha256=LOCAL_ZIP_SHA,
        difference_from_local_archive='Original phone videos/photos/source-location manifest remain local; frozen source, bit, synthetic validation and routed evidence preserved',
        real_board_feedback='User said 测试正常; overall feedback, no added speed/lighting matrix')
    payload['PUBLIC_PACKAGE.json']=json.dumps(record,ensure_ascii=False,indent=2).encode('utf-8')
    inventory={n:dict(bytes=len(data),sha256=sha(data)) for n,data in sorted(payload.items())}
    with zipfile.ZipFile(destination,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=7) as z:
        for name,data in sorted(payload.items()):z.writestr(name,data)
        z.writestr('CONTENTS_SHA256.json',json.dumps(inventory,ensure_ascii=False,indent=2).encode('utf-8'))
    with zipfile.ZipFile(destination) as z:
        assert z.testzip() is None and len(z.namelist())==len(inventory)+1
        for name,r in inventory.items():assert sha(z.read(name))==r['sha256'],name
    record.update(archive=destination.name,archive_bytes=destination.stat().st_size,
                  archive_sha256=sha(destination.read_bytes()),archive_members=len(inventory)+1,
                  github_url='https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/download/'+record['tag']+'/'+destination.name)
    destination.with_suffix('.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    return record

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--local-package',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--functional-commit',required=True)
    args=parser.parse_args()
    print(json.dumps(build(args.local_package,args.out,args.functional_commit),ensure_ascii=True,indent=2))
