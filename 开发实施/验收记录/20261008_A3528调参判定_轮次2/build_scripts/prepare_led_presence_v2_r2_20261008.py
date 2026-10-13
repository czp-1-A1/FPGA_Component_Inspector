from pathlib import Path
import hashlib,json,shutil,re
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
prior=root/'tmp/led_presence_demo_v2_td_20261008'
build=root/'tmp/led_presence_demo_v2_r2_td_20261008'
before=root/'tmp/led_presence_demo_v2_r2_before_20261008'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert not build.exists() and not before.exists()
baseline=load(prior/'inputs.json')
for x in baseline:assert sha(project/x['path'])==x['sha256'],x['path']
before.mkdir()
for rel in ['user_source/hdl_source/design_top_wrapper.v','sim/tb_display_state.v','td_project/current_codex_build.json']:
    dest=before/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(project/rel,dest)
shutil.copy2(root/'AGENTS.md',before/'AGENTS.md')
top=project/'user_source/hdl_source/design_top_wrapper.v'
raw=top.read_bytes()
assert raw.count(b'localparam CLASS_CALIBRATED=1;')==1
top.write_bytes(raw.replace(b'localparam CLASS_CALIBRATED=1;',b"localparam CLASS_CALIBRATED=1'b1;"))
build.mkdir()
inputs=[]
for entry in baseline:
    src,dst=project/entry['path'],build/entry['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    inputs.append({'path':entry['path'],'bytes':dst.stat().st_size,'sha256':sha(dst)})
changed=[x['path'] for x,y in zip(inputs,baseline) if x['sha256']!=y['sha256']]
assert changed==['user_source/hdl_source/design_top_wrapper.v']
stages=[]
for stage in ['syn_1','phy_1']:
    rel=Path('td_project/camera_to_dsi_display_Runs')/stage
    dest=build/rel;dest.mkdir(parents=True)
    for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
        shutil.copy2(prior/rel/name,dest/name);stages.append({'path':(rel/name).as_posix(),'sha256':sha(dest/name)})
    files=re.findall(r'<File Path="([^"]+)"',(dest/'camera_to_dsi_display.prj').read_text(encoding='utf-8-sig'))
    assert len(files)==67 and all((dest/x).exists() for x in files)
sim=build/'sim';sim.mkdir()
for src in (project/'sim').iterdir():
    if src.is_file() and src.suffix.lower() in {'.v','.ps1','.py','.do','.md','.hex'}:shutil.copy2(src,sim/src.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
# Only the top-level constant width changed. The seven module tests do not
# compile design_top_wrapper; reuse their completed logs with source hashes.
tests=['classifier','display_state','controls','observation','stop_recovery','osd','roi_chain']
proof=[]
for entry in inputs:
    if entry['path']!='user_source/hdl_source/design_top_wrapper.v':
        assert sha(prior/entry['path'])==entry['sha256']
        proof.append({'path':entry['path'],'sha256':entry['sha256']})
for src in (prior/'sim').iterdir():
    if src.is_file() and src.suffix.lower() in {'.v','.ps1','.py','.do','.md','.hex'}:
        assert sha(src)==sha(sim/src.name)
for name in tests:
    old_log=prior/'sim/modelsim_work'/name
    dest=sim/'modelsim_work'/name;dest.mkdir(parents=True)
    for src in old_log.glob('*.log'):shutil.copy2(src,dest/src.name)
shutil.copy2(prior/'sim/suite_console.log',sim/'suite_console.log')
reuse={'origin':'tmp/led_presence_demo_v2_td_20261008','method':'Reuse seven completed module regressions after verifying every compiled production/test source is byte-identical. These tests do not compile design_top_wrapper. Rebuild the actual top and rerun extracted binding probe for the one-bit constant repair.','only_production_change':changed,'reused_tests':tests,'unchanged_production_inputs':proof,'testbench_hashes':[{'path':'sim/tb_'+x+'.v','sha256':sha(sim/('tb_'+x+'.v'))} for x in tests]}
dump(build/'simulation_reuse.json',reuse)
dump(build/'inputs.json',inputs);dump(build/'stage_inputs.json',stages)
dump(build/'preparation.json',{'input_count':len(inputs),'r1_changed':changed,'literal_repair':"CLASS_CALIBRATED=1'b1",'project_sources':67})
for base in ['prepare_binding_probe_v2_20261008.py','run_binding_probe_v2_20261008.ps1','freeze_led_presence_v2_20261008.py','audit_led_presence_v2_20261008.py']:
    s=(root/'tmp'/base).read_text(encoding='utf-8')
    s=s.replace('led_presence_demo_v2_td_20261008','led_presence_demo_v2_r2_td_20261008').replace('led_presence_demo_v2_before_20261008','led_presence_demo_v2_r2_before_20261008').replace('led_presence_demo_v2_20261008','led_presence_demo_v2_r2_20261008').replace('20261008_A3528调参判定_轮次1','20261008_A3528调参判定_轮次2')
    s=s.replace("'v1':root/'tmp/led_presence_demo_v2_r2_before_20261008/", "'v1':root/'tmp/led_presence_demo_v2_before_20261008/")
    s=s.replace("expressions['v1']['top_sha256']==sha(root/'tmp/led_presence_demo_v2_r2_before_20261008/", "expressions['v1']['top_sha256']==sha(root/'tmp/led_presence_demo_v2_before_20261008/")
    if base.startswith('freeze_'):
        s=s.replace("['binding_probe','binding_probe_preparation_failure']","['binding_probe']")
        s=s.replace("for name in ['inputs.json','stage_inputs.json','preparation.json']:","for name in ['inputs.json','stage_inputs.json','preparation.json','simulation_reuse.json']:")
        s=s.replace("'tests':test_results,","'tests':test_results,'simulation_reuse':load(build/'simulation_reuse.json'),")
        s=s.replace("['prepare_led_presence_v2_20261008.py','checkpoint_led_presence_v2_20261008.py','prepare_binding_probe_v2_20261008.py','run_binding_probe_v2_20261008.ps1','freeze_led_presence_v2_20261008.py']", "['prepare_led_presence_v2_r2_20261008.py','prepare_binding_probe_v2_r2_20261008.py','run_binding_probe_v2_r2_20261008.ps1','freeze_led_presence_v2_r2_20261008.py']")
        # Parse only the actual summary table, not repeated detailed entries.
        start=s.index('budgets=[]\n')
        end=s.index("tests=['classifier'",start)
        s=s[:start]+'''budgets=[]
table=read(phy/'camera_to_dsi_display_exception.timing').split('MCP/SMD Details')[0]
for m in re.finditer(r'^\\s*(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(set_max_delay .+)$',table,re.M):
    if '[get_regs {' in m[5]:
        budgets.append({'total':int(m[1]),'dominated':int(m[2]),'shadowed':int(m[3]),'ignored':int(m[4]),'constraint':m[5]})
assert len(budgets)==24 and all(x['total']>0 and x['ignored']==0 for x in budgets)
'''+s[end:]
        s=s.replace("'test_helper_repairs':['Initial expression extraction", "'test_helper_repairs':['R1 generated a 32-bit-to-1-bit calibration port warning; R2 uses an explicitly sized one-bit literal and rebuilds the top. R1 evidence preserved.','Initial expression extraction")
    if base.startswith('audit_'):
        s=s.replace('Inherited manifest parser retained 72 entries by also consuming detail repetitions with stale counters; these are not 72 distinct rules. This summary is limited to MCP/SMD Summary and is authoritative for rule counts/counters. Main frozen manifest and v1 evidence preserved.','R2 manifest parser uses only MCP/SMD Summary; 24 mailbox rows. The R1 inherited parser included detail repetitions; R1 evidence remains preserved.')
    out=base.replace('_v2_','_v2_r2_')
    (root/'tmp'/out).write_text(s,encoding='utf-8')
print(json.dumps({'build':str(build),'changed':changed,'reused_tests':tests}))
