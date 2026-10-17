"""Replay the frozen V12 handoff without modifying its original inputs (Windows)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

TESTS = ['hd_resize', 'hd_scaled_guard', 'hd_pins', 'field_chain']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ps_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def run(command, cwd, log):
    print('RUN', command, 'CWD', cwd, flush=True)
    started = time.time()
    with log.open('w', encoding='utf-8') as out:
        proc = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True,
                                encoding='utf-8', errors='replace')
        for line in proc.stdout:
            out.write(line)
            out.flush()
            if any(word in line for word in ['PASS ', 'Error', 'ERROR', 'Fatal',
                                             'SWNS', 'HWNS', 'OBS ', 'WARNING']):
                print(line.rstrip(), flush=True)
        code = proc.wait()
    log.with_suffix('.result.json').write_text(json.dumps({
        'command': command, 'cwd': str(cwd), 'exit_code': code,
        'elapsed_seconds': time.time() - started,
    }, indent=2), encoding='utf-8')
    if code:
        raise RuntimeError(f'Command exit {code}; see {log}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action', required=True,
                        choices=['verify', 'prepare', 'sim', 'build'])
    parser.add_argument('--snapshot', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'source_snapshot')
    parser.add_argument('--work', type=Path)
    parser.add_argument('--td-root', type=Path, default=Path('E:/TD'))
    parser.add_argument('--modelsim-bin', type=Path, default=Path('E:/Modelsim/win64'))
    parser.add_argument('--powershell', default=str(Path(os.environ.get('SystemRoot',
        'C:/Windows')) / 'System32/WindowsPowerShell/v1.0/powershell.exe'))
    parser.add_argument('--tests', nargs='+', choices=TESTS, default=TESTS)
    args = parser.parse_args()
    snapshot = args.snapshot.resolve()
    manifest_path = snapshot / 'inputs.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    extra_path = snapshot / 'extra_inputs.json'
    extra = json.loads(extra_path.read_text(encoding='utf-8')) if extra_path.exists() else {}
    for relative, expected in extra.items():
        if relative in manifest and manifest[relative] != expected:
            raise RuntimeError(f'Conflicting extra input: {relative}')
        manifest[relative] = expected
    for relative, expected in manifest.items():
        path = (snapshot / relative).resolve()
        if not path.is_relative_to(snapshot) or not path.is_file() or sha(path) != expected:
            raise RuntimeError(f'Frozen source missing or changed: {relative}')
    print(f'PASS frozen inputs: {len(manifest)} files; manifest {sha(manifest_path)}')
    if args.action == 'verify':
        return
    if not args.work:
        parser.error('--work is required for prepare/sim/build')
    work = args.work.resolve()
    if not str(work).isascii() or re.search(r'\s', str(work)):
        raise RuntimeError('Use an ASCII work path with no whitespace')
    origin = work / 'REPLAY_ORIGIN.json'
    identity = {'manifest_sha256': sha(manifest_path),
                'extra_manifest_sha256': sha(extra_path) if extra_path.exists() else None,
                'td_root': args.td_root.resolve().as_posix()}
    if args.action == 'prepare':
        if work.exists():
            raise RuntimeError(f'Work path already exists; use a fresh directory: {work}')
        work.mkdir(parents=True)
        for relative in manifest:
            dst = work / relative
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(snapshot / relative, dst)
        shutil.copy2(manifest_path, work / 'inputs_original.json')
        if extra_path.exists():
            shutil.copy2(extra_path, work / 'extra_inputs_original.json')
        td_root = args.td_root.resolve().as_posix()
        for relative in ['td_project/camera_to_dsi_display.al'] + [
            f'td_project/camera_to_dsi_display_Runs/{s}/camera_to_dsi_display.prj'
            for s in ['syn_1', 'phy_1']
        ]:
            path = work / relative
            value = path.read_text(encoding='utf-8')
            value = re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',
                           lambda m: m[1] + path.parent.as_posix(), value, count=1)
            path.write_text(value, encoding='utf-8')
            for relative_file in re.findall(r'<File Path="([^"]+)"', value):
                target = (path.parent / relative_file).resolve()
                if not target.is_file() or not target.is_relative_to(work):
                    raise RuntimeError(f'Unresolved or external project dependency: {target}')
        for stage in ['syn_1', 'phy_1']:
            run_dir = work / 'td_project/camera_to_dsi_display_Runs' / stage
            for name in ['build.tcl', 'settings.cfg']:
                path = run_dir / name
                contents = path.read_text(encoding='utf-8')
                if name == 'build.tcl':
                    flow_candidates = [args.td_root.resolve() / location for location in
                                       ['doc/scripts/DefaultFlow.tcl', 'scripts/DefaultFlow.tcl']]
                    flow = next((p for p in flow_candidates if p.is_file()), None)
                    if flow is None:
                        raise RuntimeError('Installed TD DefaultFlow.tcl not found')
                    contents, count = re.subn(r'source \{[^}]*DefaultFlow\.tcl\}',
                        lambda m: 'source {' + flow.as_posix() + '}', contents)
                    if count != 1:
                        raise RuntimeError('Unexpected vendor-flow source command')
                path.write_text(contents, encoding='utf-8')
        shutil.copy2(Path(__file__).resolve().with_name('audit_routed.tcl'), work / 'audit_routed.tcl')
        origin.write_text(json.dumps(identity, indent=2), encoding='utf-8')
        print('Prepared', work, 'for TD', td_root)
        return
    if not origin.is_file() or json.loads(origin.read_text()) != identity:
        raise RuntimeError('Prepare a fresh work directory with this snapshot and TD root first')
    # Replay metadata may be relocated; production RTL, IP and tests must remain identical.
    for relative, expected in manifest.items():
        if relative.startswith(('user_source/', 'sim/')) and sha(work / relative) != expected:
            raise RuntimeError(f'Replay source changed after prepare: {relative}')
    if args.action == 'sim':
        command_text = ('& ' + ps_quote(work / 'sim/run_modelsim.ps1') +
                        ' -ModelSimBin ' + ps_quote(args.modelsim_bin.resolve()) +
                        ' -TdSimRoot ' + ps_quote(args.td_root.resolve() / 'sim_release') +
                        ' -OnlyTests @(' + ','.join(ps_quote(t) for t in args.tests) + ')')
        run([args.powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
             command_text], work, work / 'replay_sim.log')
        return
    td = args.td_root.resolve() / 'bin/td_commands_prompt.exe'
    for stage in ['syn_1', 'phy_1']:
        stage_dir = work / 'td_project/camera_to_dsi_display_Runs' / stage
        run([str(td), 'build.tcl'], stage_dir, stage_dir / 'replay_build.log')
    report = work / 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_pr.timing'
    text = report.read_text(encoding='utf-8', errors='replace')
    for kind in ['SWNS', 'HWNS']:
        match = re.search(kind + r':\s*([-\d.]+)ns', text)
        if not match or float(match[1]) < 0:
            raise RuntimeError(f'Routed {kind} not passing; do not publish bit: {report}')
    print('PASS routed setup/hold; constraints/source identity and physical audit still required')


if __name__ == '__main__':
    main()
