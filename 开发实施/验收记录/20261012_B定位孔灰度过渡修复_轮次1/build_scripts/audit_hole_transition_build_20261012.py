from pathlib import Path

# Run the same immutable-source and physical-report assertions as publication,
# without claiming that the still-running regression has completed.
script=Path(__file__).with_name('finish_hole_transition_20261012.py').read_text(encoding='utf-8')
prefix=script.split('unit_runs=',1)[0]
physical='runs='+script.split('\nruns=',1)[1].split('\nbit=phy/',1)[0]
exec(prefix+physical)
result=dict(status='PASS_source_and_physical_build_regression_pending',
            timing=metrics,resources=resources,warnings=warnings,max_delays_matched=len(newdelays))
dump(build/'physical_audit_pending_regression.json',result)
print(json.dumps(result,ensure_ascii=False))
