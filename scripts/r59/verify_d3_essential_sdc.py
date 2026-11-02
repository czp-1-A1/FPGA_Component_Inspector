"""Account for exactly nine constraints of removed display-only mailboxes.

Original R57 commands are preserved; R59 adds four bounded instrumentation paths.
All remaining explicit/vendor bounds must still be audited after full routing.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re

REMOVED=('u_overflow_display','u_publish_display','u_wb_process')
normalize=lambda s:re.sub(r'\s+',' ',s.strip())


def removed_ui_bounds(sdc):
    commands=[normalize(s) for s in sdc.splitlines() if s.strip().startswith('set_max_delay')]
    assert len(commands)==len(set(commands))==51
    removed=[s for s in commands if any('{'+name+'/' in s for name in REMOVED)]
    assert len(removed)==9
    for name in REMOVED:
        rows=[s for s in removed if '{'+name+'/' in s]
        assert len(rows)==3
        for pair in [('payload*','D_data*'),('req','req_sync[0]'),('ack','ack_sync[0]')]:
            assert sum('{'+name+'/'+pair[0]+'}' in s and '{'+name+'/'+pair[1]+'}' in s for s in rows)==1
    return removed


def verify_coverage(coverage,sdc):
    removed=removed_ui_bounds(sdc)
    assert re.search(r'checking invalid constraint\(9\)',coverage)
    block=coverage.split('4. checking invalid constraints. (HIGH)',1)[1].split('5. checking PLL/buffer clocks.',1)[0]
    observed=[normalize(s) for s in re.findall(r'\.sdc\(\d+\):\s*(set_max_delay[^\r\n]+)',block)]
    assert len(observed)==9 and set(observed)==set(removed),('Unexpected invalid constraint',observed)
    for item in ['no clock','clock definition','combinational loops','soft fifo timing exception constraints','no path constraints']:
        assert re.search(r'checking '+re.escape(item)+r'\(0\)',coverage),item
    return removed


def main():
    p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--coverage',type=Path,required=True);a=p.parse_args()
    sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
    proof=json.loads((a.work/'ESSENTIAL_UI_PROOF.json').read_text());reference=Path(proof['reference'])
    rel='project/td_project/camera_to_dsi_display.sdc';assert (a.work/rel).read_text().startswith((reference/rel).read_text())
    removed=verify_coverage(a.coverage.read_text(),(a.work/rel).read_text())
    result={'status':'PASS_R59_ORIGINAL_SDC_PLUS_INSTRUMENT_BOUNDS_EXACT_NINE_REMOVED_UI_ONLY',
            'sdc_sha256':sha(a.work/rel),'coverage_sha256':sha(a.coverage),'coverage_file':str(a.coverage.resolve()),
            'explicit_declared':51,'compiled_out_display_only':9,'retained_explicit':42,
            'inherited_vendor_expected':2,'retained_total_expected':44,'original_total_accounted':49,'new_instrument_bounds':4,
            'removed_mailboxes':list(REMOVED),'compiled_out_commands':removed,
            'remaining_constraints_relaxed':False,'routed_acceptance':False}
    (a.work/'ESSENTIAL_SDC_PROOF.json').write_text(json.dumps(result,indent=2)+'\n')
    print('PASS R59 original commands plus4 instrument bounds; exact9 removed UI accounted;42 explicit+2 vendor require routing audit')


if __name__=='__main__':main()
