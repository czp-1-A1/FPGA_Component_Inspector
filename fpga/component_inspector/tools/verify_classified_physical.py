"""Strict numeric acceptance of an actual completed routed build and audit.

This checks evidence, not the correctness of a synthetic or physical count.
Run after classified_audit_routed.tcl; no stale gate/placed report is accepted.
"""
from pathlib import Path
import argparse, hashlib, json, re

def text(p):
    b = p.read_bytes()
    return b.decode('utf-16' if b.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')

def timing(t):
    assert 'Confidence          : Routed' in t, 'Not an actual Routed report'
    assert 'Check Corner        : Both (Slow and Fast)' in t, 'Missing timing corner'
    values = {}
    for key in ['SWNS', 'HWNS', 'STNS', 'HTNS']:
        m = re.search(r'\b' + key + r':\s*([-\d.]+)ns', t)
        assert m, key
        values[key] = float(m[1])
        assert values[key] >= 0, (key, values[key])
    assert values['STNS'] == values['HTNS'] == 0, 'Nonzero total negative slack'
    return values

def normalize(line):
    return re.sub(r'\s+', ' ', line.strip())

def verify(project):
    audit = project / 'classified_audit'
    values = timing(text(audit / 'routed_summary.timing'))
    sdc = text(project / 'td_project/camera_to_dsi_display.sdc')
    expected = [normalize(x) for x in sdc.splitlines() if x.strip().startswith('set_max_delay')]
    # Original SDC has38 explicit bounds; six new bounds make44. TD adds
    # two inherited vendor-FIFO bounds, so the complete audited total is46.
    assert len(expected) == 44 and len(set(expected)) == 44, 'Unexpected current SDC contract'
    exceptions = text(audit / 'exceptions.timing')
    table = exceptions.split('MCP/SMD Summary', 1)[1].split('Min Check', 1)[0]
    observed, aliases, previous = {}, [], None
    for line in table.splitlines():
        if 'set_max_delay' not in line:
            continue
        row = re.match(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay.*)', line)
        if row:
            previous = [int(x) for x in row.groups()[:4]]
            command = normalize(row[5])
        else:
            # TD merges physically identical status-mailbox token registers.
            # Continuation aliases inherit the SAME preceding physical stats.
            assert previous is not None, ('Unbound alias row', line)
            command = normalize(line[line.index('set_max_delay'):])
            aliases.append(command)
        assert command not in observed, command
        observed[command] = previous.copy()
    missing = set(expected) - set(observed)
    vendor = set(observed) - set(expected)
    assert not missing and len(vendor) == 2 and len(observed) == 46, ('Constraint mismatch', missing, vendor)
    vendor_budgets = set()
    for command in vendor:
        assert 'primary_addr_gray_reg' in command and 'sync_r1' in command, command
        match = re.search(r'-datapath_only ([\d.]+)$', command)
        assert match, command
        vendor_budgets.add(float(match[1]))
    assert vendor_budgets == {9.7, 13.168}, ('Unexpected vendor FIFO budgets', vendor_budgets)
    for command, (total, dominating, shadowed, ignored) in observed.items():
        assert total > 0 and ignored == 0 and dominating + shadowed == total, (command, total, dominating, shadowed, ignored)
    gray_line = next(x for x in expected if 'bridge/write_gray' in x)
    assert observed[gray_line] == [20, 20, 0, 0], 'All20 explicit Gray budgets must dominate'
    bindings = text(audit / 'bindings.txt')
    files = []
    for direction in ['write', 'read']:
        for bit in range(10):
            path = audit / f'gray_{direction}_{bit}.timing'
            t = text(path)
            # Gray MSB equals binary MSB exactly; TD merges those two FFs.
            line = next(x for x in bindings.splitlines() if x.startswith(f'GRAY_BIND {direction} {bit} SOURCE '))
            allowed = [f'{direction}_gray[{bit}]'] + ([f'{direction}_bin[9]'] if bit == 9 else [])
            bound = [name for name in allowed if f'bridge/{name}' in line.split(' DESTINATION ')[0]]
            assert len(bound) == 1, ('Unexpected Gray physical alias', line)
            source_name = bound[0]
            assert source_name in t and f'{direction}_gray_sync1[{bit}]' in t, path
            assert f'bridge/{source_name}' in line and f'bridge/{direction}_gray_sync1[{bit}]' in line, ('Logical/physical binding mismatch', line)
            # TD calls a datapath max-delay check "setup". Shadowed/hold
            # sections have no slack; require the actual dominant8ns budget.
            assert re.search(r'constraint delay\s+8\.000\s+8\.000', t), ('No8ns budget evidence', path)
            assert 'Check Type          : setup' in t, path
            slack = re.findall(r'^Slack\s*:\s*([-\d.]+)ns', t, re.M)
            assert slack and min(map(float, slack)) >= 0, path
            fan = audit / f'gray_fanout_{direction}_{bit}.timing'
            assert f'{direction}_gray_sync1[{bit}]' in text(fan), fan
            files.extend([path, fan])
    for box in ['u_count_command', 'u_count_live_display']:
        for suffix in ['payload', 'request', 'acknowledge']:
            path = audit / f'{box}_{suffix}.timing'
            t = text(path)
            assert box + '/' in t, path
            slack = re.findall(r'^Slack\s*:\s*([-\d.]+)ns', t, re.M)
            assert slack and min(map(float, slack)) >= 0, path
            budget = (19 if suffix == 'acknowledge' else 9) if box == 'u_count_command' else (9 if suffix == 'acknowledge' else 19)
            constraints = re.findall(r'constraint delay\s+([\d.]+)\s+([\d.]+)', t)
            # Shared token aliases can be dominated by a stricter inherited
            # bound (e.g.8ns instead of9ns); never accept a larger budget.
            assert constraints and all(0 < float(a) == float(b) <= budget for a, b in constraints), ('Mailbox budget mismatch', path, constraints)
            files.append(path)
    switch_path = audit / 'sw3_sync.timing'
    switch_fanout = audit / 'sw3_sync_fanout.timing'
    sw = text(switch_path)
    fan = text(switch_fanout)
    assert 'sw_sync[0]' in sw and 'sw_sync[1]' in sw, 'SW3 input synchronizer not bound'
    count = re.search(r'SW3_SYNC FIRST_COUNT (\d+) SECOND_COUNT (\d+) ALL_COUNT (\d+)', bindings)
    assert count and int(count[1]) >= 1 and int(count[2]) >= 1 and int(count[3]) == int(count[1])+int(count[2]), 'Unbound SW3 alias'
    for report in [sw, fan]:
        sw_slack = re.findall(r'^Slack\s*:\s*([-\d.]+)ns', report, re.M)
        assert sw_slack and min(map(float, sw_slack)) >= 0, 'SW3 timed synchronizer path failed'
    destinations = set(re.findall(r'^End Point\s*:\s*(\S+)', sw, re.M))
    fanout_destinations = set(re.findall(r'^End Point\s*:\s*(\S+)', fan, re.M))
    assert destinations and destinations == fanout_destinations, ('SW3 first-stage fanout escapes second stage', destinations, fanout_destinations)
    assert sdc.count('set_false_path -from [get_ports {I_count_start_switch}]') == 1
    files.extend([switch_path, switch_fanout])
    coverage = text(audit / 'constraint_coverage.txt')
    for item in ['no clock', 'clock definition', 'invalid constraint', 'combinational loops',
                 'soft fifo timing exception constraints', 'no path constraints']:
        assert re.search(r'checking ' + re.escape(item) + r'\(0\)', coverage), ('New coverage failure', item)
    files.extend([audit / n for n in ['routed_summary.timing', 'exceptions.timing', 'constraint_coverage.txt', 'clocks.txt', 'bindings.txt']])
    result = {'status': 'PASS_ROUTED_BOTH_CORNERS_TNS0_CONSTRAINTS_GRAY_AND_NEW_CDC',
              'timing_ns': values, 'explicit_max_delays_matched': len(expected),
              'vendor_max_delays_matched': 2, 'max_delays_matched': len(observed),
              'physical_alias_continuations': len(aliases), 'max_delays_ignored': 0,
              'gray_bits_dominating': 20, 'new_mailbox_groups': 6,
              'evidence': {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
              'physical_count': 'HUMAN_BOARD_ACCEPTANCE_NOT_ASSERTED'}
    (audit / 'verification.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('project', type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.project.resolve()), indent=2))
