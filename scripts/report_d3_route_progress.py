"""Read first SIGNAL reroute progress; never include clock-only iterations."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re

p = argparse.ArgumentParser()
p.add_argument('--work', type=Path, required=True)
a = p.parse_args()
text = (a.work / 'runs/phy_1/console.log').read_text(errors='replace')
marker = 'Stage 2.5.1.4 | Rip-up And ReRoute'
rows = []
if marker in text:
    block = text.split(marker, 1)[1].split('End Stage 2.5.1.4', 1)[0]
    pattern = r'Iter (\d+): len = ([\d.e+]+), over cnt = (\d+)\([^)]*\), over = (\d+), worst = (\d+), crit = (\d+), time\(s\) = ([\d.]+)'
    for match in re.finditer(pattern, block):
        rows.append(dict(zip(['iteration', 'wire_length', 'over_count', 'over', 'worst', 'crit', 'seconds'],
                             [int(match[1]), float(match[2]), int(match[3]), int(match[4]), int(match[5]), int(match[6]), float(match[7])])) )
    assert [row['iteration'] for row in rows] == list(range(1, len(rows) + 1))
bad = len(rows) >= 4 and all(new['over'] > old['over'] and new['wire_length'] > old['wire_length'] for old, new in zip(rows[-4:-1], rows[-3:]))
result = {'status': 'READ_ONLY_FIRST_SIGNAL_ROUTE_PROGRESS_NOT_SIGNOFF',
          'timestamp': datetime.datetime.now().astimezone().isoformat(), 'iterations': rows,
          'clock_iterations_excluded': True, 'three_consecutive_over_and_wire_regressions': bad,
          'best_over': min((row['over'] for row in rows), default=None),
          'signal_legal_seen': any(row['over'] == 0 for row in rows),
          'console_sha256': hashlib.sha256((a.work / 'runs/phy_1/console.log').read_bytes()).hexdigest(),
          'process_stopped_by_this_script': False, 'final_route_or_timing_accepted': False}
(a.work / 'ROUTE_PROGRESS.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'iterations': len(rows), 'latest': rows[-1] if rows else None,
                  'best_over': result['best_over'], 'stop_for_three_regressions': bad,
                  'signal_legal_seen': result['signal_legal_seen']}))
