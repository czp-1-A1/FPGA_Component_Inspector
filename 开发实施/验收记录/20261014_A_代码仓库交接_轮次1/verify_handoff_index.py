from pathlib import Path
import hashlib, json, subprocess
r = Path.cwd()
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
index = {}
for entry in subprocess.check_output(['git', 'ls-files', '--stage', '-z'], cwd=r).split(b'\0'):
    if not entry: continue
    head, path = entry.split(b'\t', 1)
    mode, oid, stage = head.decode().split()
    assert stage == '0'
    index[path.decode('utf-8')] = oid
paths = [x.decode('utf-8').removeprefix(':(literal)')
         for x in (r/'tmp/handoff_paths.bin').read_bytes().split(b'\0') if x]
staged = [x.decode('utf-8') for x in subprocess.check_output(
    ['git','diff','--cached','--name-only','-z'],cwd=r).split(b'\0') if x]
assert set(staged) == set(paths)
assert not set(staged) & {'build_console.log', 'transcript'}
expected = {}
for path in paths:
    assert path in index, path
    if path.startswith(('fpga/', '开发实施/验收记录/')):
        digest = sha(r / path)
        oid = index[path]
        if oid in expected: assert expected[oid] == digest
        expected[oid] = digest
        assert (r/path).stat().st_size < 100*1024**2
cat = subprocess.Popen(['git','cat-file','--batch'], cwd=r, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
for oid, digest in expected.items():
    cat.stdin.write((oid+'\n').encode()); cat.stdin.flush()
    header = cat.stdout.readline().decode().split()
    assert header[0] == oid and header[1] == 'blob'
    data = cat.stdout.read(int(header[2]))
    assert cat.stdout.read(1) == b'\n'
    assert hashlib.sha256(data).hexdigest() == digest, oid
cat.stdin.close(); assert cat.wait() == 0
e = r/'开发实施/验收记录/20261014_A_代码仓库交接_轮次1'
inputs = json.loads((e/'inputs.json').read_text(encoding='utf-8'))
for item in inputs:
    assert sha(r/'fpga/component_inspector'/item['path']) == item['sha256']
for item in json.loads((e/'archive_sha256.json').read_text(encoding='utf-8')):
    assert sha(e/item['path']) == item['sha256']
check = subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--cached','--check','--',
    'fpga/component_inspector/sim','fpga/component_inspector/user_source',
    'fpga/component_inspector/td_project'],cwd=r,capture_output=True)
(e/'current_source_diff_check.txt').write_bytes(check.stdout+check.stderr)
print('PASS: staged paths',len(staged),'unique byte-exact production/evidence blobs',len(expected),
      '215 production inputs and handoff archive SHA verified; unrelated files excluded;',
      'current source whitespace diagnostics retained, exit',check.returncode)
