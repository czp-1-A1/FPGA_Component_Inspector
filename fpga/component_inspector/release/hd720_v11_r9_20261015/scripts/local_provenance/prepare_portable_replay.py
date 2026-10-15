"""Retain the handoff runner with explicit TD-version path adaptation."""
from pathlib import Path

root = Path(__file__).resolve().parent
original = Path('C:/Users/Li47/Desktop/aa/V11/v11_handoff_20261015/v11_handoff_20261015/scripts/replay.py')
value = original.read_text(encoding='utf-8')
old = '''                path.write_text(path.read_text(encoding='utf-8').replace('E:/TD', td_root),
                                encoding='utf-8')'''
new = '''                contents = path.read_text(encoding='utf-8')
                if name == 'build.tcl':
                    flow_candidates = [args.td_root.resolve() / location for location in
                                       ['doc/scripts/DefaultFlow.tcl', 'scripts/DefaultFlow.tcl']]
                    flow = next((p for p in flow_candidates if p.is_file()), None)
                    if flow is None:
                        raise RuntimeError('Installed TD DefaultFlow.tcl not found')
                    contents, count = re.subn(r'source \\{[^}]*DefaultFlow\\.tcl\\}',
                        lambda m: 'source {' + flow.as_posix() + '}', contents)
                    if count != 1:
                        raise RuntimeError('Unexpected vendor-flow source command')
                path.write_text(contents, encoding='utf-8')'''
if value.count(old) != 1:
    raise RuntimeError('Unexpected original replay script')
value = value.replace(old, new)
destination = root / 'scripts/replay.py'
destination.parent.mkdir(exist_ok=True)
destination.write_text(value, encoding='utf-8')
print(destination)
