"""Publish verified V11 software artifacts to the Desktop without programming hardware."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parent
PACKAGE = Path('C:/Users/Li47/Desktop/aa/V11/v11_handoff_20261015/v11_handoff_20261015')
WORK = ROOT / 'r9/fpga/component_inspector'
DESKTOP = Path('C:/Users/Li47/Desktop')
VERSION = 'V11_FHD_to_720p60_r9_20261015'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)

def main():
    verification = json.loads((ROOT / 'r9/verification.json').read_text())
    if verification['status'] != 'PASS_SOFTWARE_AND_ROUTED_STA_PHYSICAL_PENDING':
        raise RuntimeError('Required software/STA audit has not passed')
    release = ROOT / 'release' / VERSION
    release.mkdir(parents=True, exist_ok=False)
    shutil.copytree(ROOT / 'r9/source_snapshot', release / 'source_snapshot')
    shutil.copytree(WORK / 'td_project', release / 'built_project/td_project')
    shutil.copytree(WORK / 'user_source', release / 'built_project/user_source')
    shutil.copytree(WORK / 'audit', release / 'evidence/r9/routed_audit')
    for name in ['replay.py', 'check_hd_reference.py']:
        copy(ROOT / 'scripts' / name, release / 'scripts' / name)
    for name in ['audit_routed.tcl','build_local.py','verify_release.py','prepare_round.py',
                 'prepare_portable_replay.py','prepare_reference_checker.py', 'package_release.py']:
        copy(ROOT / name, release / 'scripts/local_provenance' / name)
    copy(ROOT / 'audit_routed.tcl', release / 'scripts/audit_routed.tcl')
    for name in ['verification.json','changes.json','routed_audit.log','routed_audit_exit.txt',
                 'reference_portability_failure.json','independent_reference.log','independent_reference_exit.txt']:
        copy(ROOT / 'r9' / name, release / 'evidence/r9' / name)
    for name in ['replay_sim.log','replay_sim.result.json','independent_reference_results.json']:
        copy(WORK / name, release / 'evidence/r9' / name)
    for test in verification['tests']:
        src = WORK / 'sim/modelsim_work' / test
        for name in ['compile.log','console.log','transcript.log']:
            copy(src / name, release / 'evidence/r9/sim/modelsim_work' / test / name)
    # Actual generated images remain available for independent recomputation.
    for pattern in ['*.pgm','*.ppm','*.png']:
        for src in (WORK / 'sim').glob(pattern):
            copy(src, release / 'evidence/r9/sim' / src.name)
    # check_hd_reference expects a round root with sim/ and its raw records.
    # Its invocation is documented as scripts/check_hd_reference.py evidence/r9.
    for test in ['roi_guard']:
        for name in ['compile.log','console.log','transcript.log']:
            copy(ROOT / 'r8_repro/sim/modelsim_work' / test / name,
                 release / 'history/r8_compatibility_failure' / test / name)
    copy(ROOT / 'r8_repro/replay_sim.result.json', release / 'history/r8_compatibility_failure/runner.result.json')
    copy(ROOT / 'r8_repro/replay_sim.log', release / 'history/r8_compatibility_failure/runner.log')
    copy(WORK / 'td_project/camera_to_dsi_display_Runs/syn_1/replay_build.log',
         release / 'history/r9_initial_td_path_failure.log')
    shutil.copytree(PACKAGE / 'source_snapshot', release / 'history/r8_source_snapshot')
    for stage in ['syn_1','phy_1']:
        for src in (PACKAGE / 'evidence/r8/td_reports' / stage).iterdir():
            if src.is_file():
                copy(src, release / 'history/r8_td_reports' / stage / src.name)
    for name in ['STATUS.json','MANIFEST.json','62_A_V11分辨率迁移_跨机详细交接.md']:
        copy(PACKAGE / name, release / 'history/original_handoff' / name)
    copy(ROOT / 'handoff_verification.json', release / 'history/handoff_verification.json')
    shutil.copytree(PACKAGE / 'fallback_v10', release / 'fallback_v10')
    shutil.copytree(PACKAGE / 'calibration', release / 'calibration')
    copy(ROOT / 'constraint_audit.md', release / 'constraint_audit.md')
    copy(ROOT / '开发实施/验收记录/20261015_A_V11续接_轮次9.md', release / 'validation_record.md')
    bit = Path(verification['bit']['path'])
    if sha(bit) != verification['bit']['sha256']:
        raise RuntimeError('Bit changed after audit')
    bit_name = VERSION + '.bit'
    copy(bit, release / bit_name)
    notes_name = VERSION + '_烧录与验收.md'
    notes = (ROOT / 'board_instructions_draft.md').read_text(encoding='utf-8')
    notes = notes.replace('状态：待本轮全部软件及路由审计完成后写入最终版本、镜像SHA和报告数值；此草稿不是交付回执。',
        f'版本：`{VERSION}`。软件/路由验证已通过，实板与220mm配方待现场验收。\n\n'
        f'桌面镜像：`C:/Users/Li47/Desktop/{bit_name}`\n\n'
        f'镜像SHA-256：`{verification["bit"]["sha256"]}`（{verification["bit"]["bytes"]}字节）。\n\n'
        '本机TD6.2.178840，28项ModelSim及18张独立实际图像参考全部通过；路由setup+0.117ns、hold+0.020ns、TNS0。'
        'Slice69.40%，ERAM94/108，DSP26/40，PLL5/6。完整告警边界见constraint_audit.md。')
    (release / notes_name).write_text(notes, encoding='utf-8')
    (release / 'README_FIRST.md').write_text(f'''# {VERSION}

Read {notes_name} for programming and physical acceptance. No hardware was programmed by the assistant.
Software and routed STA pass; physical video and 220mm calibration remain pending.

The full project input is source_snapshot/ (342 hashed files, including the independent font reference).
The original Git provenance is lj4747-contest-work / da195838d8a1df052edeaa86f60312d32eeedf9a.
This imported source bundle is not a Git checkout. No commit or push was performed.

Windows replay (Python3.10+, NumPy, installed licensed ModelSim and TD):

    python scripts/replay.py --action verify
    python scripts/replay.py --action prepare --work D:/v11_replay --td-root D:/td6.2.1
    python scripts/replay.py --action sim --work D:/v11_replay --td-root D:/td6.2.1 --modelsim-bin D:/modeltech64_10.5/win64
    python scripts/check_hd_reference.py D:/v11_replay
    python scripts/replay.py --action build --work D:/v11_replay --td-root D:/td6.2.1

The runner resolves both TD doc/scripts and scripts flow locations. The image checker reads UTF8/UTF16 logs without changing its reference algorithm.
The tests and production inputs are checked before use. Use a new ASCII directory with no spaces.
Recheck timing/constraints after rebuilding with another tool version; a build exit alone is insufficient.

To independently recheck the bundled actual output images:

    python scripts/check_hd_reference.py evidence/r9

For routed Gray-bit audit run TD with scripts/audit_routed.tcl from built_project/.
The archived built project retains the actual machine's absolute project Path metadata; relocate via prepare before normal rebuilding.
Vendor tools/libraries/licenses are external dependencies and are not packaged.
''', encoding='utf-8')
    meta = dict(verification, version=VERSION, base_branch='lj4747-contest-work',
        base_commit='da195838d8a1df052edeaa86f60312d32eeedf9a',
        git_committed=False, git_pushed=False, hardware_programmed=False)
    (release / 'release.json').write_text(json.dumps(meta, indent=2), encoding='utf-8')
    (release / 'current_codex_build.json').write_text(json.dumps(meta, indent=2), encoding='utf-8')
    manifest = {p.relative_to(release).as_posix():sha(p)
                for p in sorted(release.rglob('*')) if p.is_file()}
    (release / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    archive = release.parent / (VERSION + '_full.zip')
    if archive.exists():
        raise RuntimeError('Refusing to overwrite archive')
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for src in sorted(release.rglob('*')):
            if src.is_file():
                z.write(src, VERSION + '/' + src.relative_to(release).as_posix())
    expected = dict(manifest, **{'MANIFEST.json':sha(release / 'MANIFEST.json')})
    with zipfile.ZipFile(archive) as z:
        if len(z.infolist()) != len(expected):
            raise RuntimeError('Archive file count mismatch')
        for name,digest in expected.items():
            if hashlib.sha256(z.read(VERSION + '/' + name)).hexdigest() != digest:
                raise RuntimeError('Archive hash mismatch: '+name)
    deliver = [release / bit_name, archive, release / notes_name]
    for src in deliver:
        dst = DESKTOP / src.name
        if dst.exists():
            raise RuntimeError('Refusing to overwrite desktop file: '+str(dst))
    receipt = {'version':VERSION, 'payload_files':len(manifest), 'archive_entries':len(expected),
               'source_manifest_sha256':verification['source_manifest_sha256'], 'files':{}}
    for src in deliver:
        dst = DESKTOP / src.name
        copy(src, dst)
        digest = sha(src)
        if sha(dst) != digest:
            raise RuntimeError('Desktop copy mismatch')
        receipt['files'][str(dst)] = {'bytes':dst.stat().st_size, 'sha256':digest}
    checksum_name = VERSION + '_SHA256.txt'
    checksums = ''.join(item['sha256']+'  '+Path(name).name+'\n' for name,item in receipt['files'].items())
    (DESKTOP / checksum_name).write_text(checksums, encoding='ascii')
    (ROOT / 'delivery_receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    (DESKTOP / (VERSION + '_交付回执.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    pointer = dict(meta, desktop_bit=str(DESKTOP / bit_name), desktop_package=str(DESKTOP / archive.name),
                   delivery_receipt=str(DESKTOP / (VERSION + '_交付回执.json')))
    for dst in [ROOT / 'development/fpga/component_inspector/current_codex_build.json',
                DESKTOP / 'aa/V11/current_codex_build.json']:
        dst.write_text(json.dumps(pointer, indent=2), encoding='utf-8')
    print(json.dumps(receipt, indent=2), flush=True)

if __name__ == '__main__':
    main()
