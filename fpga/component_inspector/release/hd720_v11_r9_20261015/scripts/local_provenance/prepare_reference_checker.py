from pathlib import Path

root = Path(__file__).resolve().parent
original = Path('C:/Users/Li47/Desktop/aa/V11/v11_handoff_20261015/v11_handoff_20261015/scripts/check_hd_reference.py')
value = original.read_text(encoding='utf-8')
old = "    lines=log.read_text(encoding='utf-8',errors='replace')"
new = "    raw_log=log.read_bytes()\n    lines=raw_log.decode('utf-16' if raw_log.startswith((b'\\xff\\xfe',b'\\xfe\\xff')) else 'utf-8-sig',errors='strict')"
if value.count(old) != 1:
    raise RuntimeError('Unexpected independent reference checker')
(root / 'scripts/check_hd_reference.py').write_text(value.replace(old,new), encoding='utf-8')
(root / 'r9/reference_portability_failure.json').write_text(
    '{"original_checker_status":"FAIL_NO_RECORDS", "cause":"Windows PowerShell 5.1 console logs have UTF-16 BOM; original reader forced UTF-8", "fix":"BOM-aware decoding only; reference algorithm and expected values unchanged"}', encoding='utf-8')
print('Prepared encoding-compatible independent reference checker')
