"""Verify frozen inputs, actual compile commands, and test completion evidence.

No elaboration exemptions: every RTL/testbench file actually listed by vlog
must have exactly the final candidate's digest, even when a parameter is off.
"""
from pathlib import Path
import argparse, hashlib, json, re

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def read(p):
    b = p.read_bytes()
    return b.decode('utf-16' if b.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')

def verify(manifest_path, source, config_path, output):
    manifest = json.loads(read(manifest_path))
    for rel, digest in manifest.items():
        assert sha(source / rel) == digest, ('Frozen input changed', rel)
    config = json.loads(read(config_path))
    required = config['required_tests']
    assert len(required) == 24 and len(set(required)) == 24, 'Required validation set changed'
    tests = {}
    for origin in config['origins']:
        project = Path(origin['project'])
        runtime_inputs = {}
        for rel, digest in manifest.items():
            if rel.startswith('sim/') and Path(rel).suffix.lower() in ('.hex', '.mif', '.dat'):
                assert sha(project / rel) == digest, ('Runtime font/reference data changed', origin['project'], rel)
                runtime_inputs[rel] = digest
        runner = read(project / 'sim/run_modelsim.ps1')
        sentinels = dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"', runner))
        for name in origin['tests']:
            assert name in required and name not in tests, name
            root = project / 'sim/modelsim_work' / name
            compile_log = read(root / 'compile.log')
            console = read(root / 'console.log')
            assert sentinels[name] in console, ('No successful test sentinel', name)
            assert not re.search(r'\*\* (Fatal|Error):|Errors:\s*[1-9]', compile_log + console), name
            assert re.search(r'Errors:\s*0,\s*Warnings:', console), ('No simulator completion', name)
            inputs = {}
            for line in compile_log.splitlines():
                if 'vlog ' not in line or '-work' not in line:
                    continue
                for token in line.split():
                    if token.endswith(('.v', '.sv')):
                        p = (project / 'sim' / token).resolve()
                        rel = p.relative_to(project).as_posix()
                        digest = sha(p)
                        assert manifest.get(rel) == digest, ('Compiled input differs', name, rel)
                        inputs[rel] = digest
            assert inputs, ('No actual compiled input evidence', name)
            tests[name] = {'origin': str(project), 'inputs': inputs,
                           'runtime_inputs': runtime_inputs,
                           'console_sha256': sha(root / 'console.log'),
                           'compile_sha256': sha(root / 'compile.log'),
                           'pass_lines': [line for line in console.splitlines() if 'PASS ' in line]}
    assert set(tests) == set(required), ('Missing required tests', set(required) - set(tests))
    result = {'status': 'PASS24_FROZEN_ACTUAL_COMPILED_INPUTS_NO_EXCLUSIONS',
              'manifest_sha256': sha(manifest_path), 'source_count': len(manifest),
              'tests': tests, 'physical_count': 'HUMAN_KNOWN_SEQUENCE_ACCEPTANCE_PENDING'}
    output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--runs', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.manifest, args.source, args.runs, args.output)
    print(result['status'], len(result['tests']), 'tests,', result['source_count'], 'frozen inputs')
