"""Check all twenty actual Gray Q-to-first-stage wires, not packed-cell count.

TD get_regs collections may also select a companion FF in a dual-FF cell.
Every original budget and the twenty required signals remain mandatory.
"""
from pathlib import Path
import re,hashlib,json

def text(p):
    b=p.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig').replace('\r\n','\n')

def verify(project,stats):
    total,dominated,shadowed,ignored=stats
    assert total>=20 and dominated==total and shadowed==ignored==0,('Gray physical coverage',stats)
    context=text(project/'classified_audit/routed_summary.timing')
    assert 'Confidence          : Routed' in context and 'Check Corner        : Both (Slow and Fast)' in context
    folder=project/'gray_packing_audit';bindings=text(folder/'bindings.txt')
    assert re.search(r'^GRAY_COLLECTION SOURCES 20 DESTINATIONS 20$',bindings,re.M),'Gray logical collections must still be exactly20/20'
    evidence={};rows=[];source_qs=set();destinations=set()
    for direction in ['write','read']:
        for bit in range(10):
            line=next((x for x in bindings.splitlines() if x.startswith(f'GRAY_Q {direction} {bit} SOURCE ')),None)
            assert line is not None,('Missing Gray Q binding',direction,bit)
            match=re.fullmatch(r'GRAY_Q '+direction+' '+str(bit)+r' SOURCE \{([^}]+)\} THROUGH \{([^}]+)\} DESTINATION \{([^}]+)\}',line)
            assert match,('Malformed or multiple Gray bindings',line)
            src,qnet,dst=match.groups();allowed=[f'u_isp_top/continuous_processing$bridge/{direction}_gray[{bit}]']
            if bit==9:allowed.append(f'u_isp_top/continuous_processing$bridge/{direction}_bin[9]')
            assert src in allowed and qnet==src,('Unexpected logical/physical Q alias',line)
            assert dst==f'u_isp_top/continuous_processing$bridge/{direction}_gray_sync1[{bit}]',('Incorrect first-stage destination',line)
            source_qs.add(qnet);destinations.add(dst)
            p=folder/f'gray_q_{direction}_{bit}.timing';report=text(p)
            assert 'Top Model           : design_top_wrapper' in report,('Not final dual-corner Gray proof',p)
            assert 'Type           :     SMD' in report and 'Check Type          : setup' in report,('No dominant datapath check',p)
            budgets=re.findall(r'constraint delay\s+([\d.]+)\s+([\d.]+)',report)
            assert budgets and all(float(a)==float(b)==8.0 for a,b in budgets),('Gray budget must remain8ns',p,budgets)
            slacks=re.findall(r'^Slack\s*:\s*([-\d.]+)ns',report,re.M)
            assert slacks and min(map(float,slacks))>=0,('Negative or missing Gray slack',p)
            # The exact Q net must be a DATA net in the path, not just a name
            # appearing in the query header/clock route. Same for the actual
            # destination FF output. Direct async wires have one capture LUT2.
            assert re.search(r'\bnet:\s*'+re.escape(qnet)+r'(?:,|\s)',report),('Missing actual launch Q data net',p,qnet)
            assert re.search(r'\bnet:\s*'+re.escape(dst)+r'(?:,|\s)',report),('Missing actual first-stage capture net',p,dst)
            assert re.search(r'Logic Level\s*:\s*1\s*\( LUT2=1 \)',report),('Gray direct wire must not include a companion FF cone',p)
            rows.append({'direction':direction,'bit':bit,'source':src,'through':qnet,'destination':dst,'budget_ns':8.0,'minimum_slack_ns':min(map(float,slacks))})
            evidence[str(p.relative_to(project))]=hashlib.sha256(p.read_bytes()).hexdigest()
    assert len(rows)==len(source_qs)==len(destinations)==20,'Twenty distinct actual Gray wires required'
    evidence[str((folder/'bindings.txt').relative_to(project))]=hashlib.sha256((folder/'bindings.txt').read_bytes()).hexdigest()
    # Preserve the complete selected-cell report, including all conservative
    # additional paths. The original exceptions report still requires ALL
    # selected paths to be dominated, with zero shadowed or ignored paths.
    p=folder/'all_selected.timing';report=text(p)
    assert 'Top Model           : design_top_wrapper' in report
    assert re.search(r'constraint delay\s+8\.000\s+8\.000',report)
    evidence[str(p.relative_to(project))]=hashlib.sha256(p.read_bytes()).hexdigest()
    result={'status':'PASS_TWENTY_DISTINCT_ACTUAL_GRAY_Q_WIRES_8NS_AND_ALL_SELECTED_PATHS_DOMINATE','logical_sources':20,'logical_destinations':20,'required_gray_wires':20,'selected_physical_paths':total,'additional_conservative_physical_paths':total-20,'physical_paths_dominated':dominated,'physical_paths_shadowed':shadowed,'physical_paths_ignored':ignored,'wires':rows,'evidence':evidence,'note':'No constraints, thresholds, clock periods, seeds or routed hardware changed. Physical path cardinality may exceed logical wire count due dual-FF packing.'}
    return result
