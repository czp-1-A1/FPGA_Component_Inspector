"""Package the reviewed diagnostic candidate, preserving all failed rounds."""
from pathlib import Path
import json,hashlib,shutil,zipfile,re,subprocess

engine=Path(__file__).resolve().parents[1];repo=engine.parents[1];outer=repo.parent
out=engine/'release/native_1080p30/stage2_base_20261008'
build=outer/'native_1080p30_r4_20261007'
final=outer/'native_1080p30_r8_20261008'
r2=outer/'native_1080p30_r2_20261007';r5=outer/'native_1080p30_r5_20261008'
r6=outer/'native_1080p30_r6_20261008';r7=outer/'native_1080p30_r7_20261008'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def metadata(root):return json.loads((root/'freeze.json').read_text())
def console(root,test):return root/'sim/modelsim_work'/test/'console.log'
legacy=['isp_writer_stop','sobel_tail','sobel_view','observation','stop_recovery','display_state','controls','cdc','monitor','csi_monitor','i2c','osd','pack_boundary','pixel_interface','roi_guard','roi_core','classifier','roi_chain']
tests={test:r6 if test in legacy[-4:] else r2 for test in legacy}
tests.update(fhd_csi=r2,fhd_reader=r2,fhd_isp=final,fhd_osd=r5,fhd_mc=r7,native_pll=r7,fhd_faults=r6)
for name,root in tests.items():
    log=console(root,name).read_text(errors='replace')
    assert 'PASS' in log and not re.search(r'(?m)^#\s*\*\* (Fatal|Error):',log),(name,root)
build_inputs={e['path']:e for e in metadata(build)['inputs']}
final_inputs={e['path']:e for e in metadata(final)['inputs']}
rtl_inputs=[p for p in build_inputs if p.startswith(('user_source/','td_project/'))]
for rel in rtl_inputs:
    assert build_inputs[rel]['sha256']==final_inputs[rel]['sha256'],rel
    assert sha(engine/rel)==build_inputs[rel]['sha256'],rel
# Older frozen regression rounds use identical core HDL. Only the dedicated
# HDMI PLL changed after r2; its integer implementation was tested in r7.
# Verify the complete HDL set (not merely the selected modules), and each TB.
test_sources=[]
for name,root in tests.items():
    inputs={e['path']:e for e in metadata(root)['inputs']}
    checked=[]
    for rel in rtl_inputs:
        if not rel.startswith('user_source/'):continue
        if rel.endswith('/native_hdmi_pll.v') and name!='native_pll':continue
        assert inputs[rel]['sha256']==final_inputs[rel]['sha256'],(name,rel)
        checked.append(rel)
    tb='sim/tb_'+name+'.v'
    assert inputs[tb]['sha256']==final_inputs[tb]['sha256'],(name,tb)
    test_sources.append(dict(name=name,freeze=str(root),testbench_sha256=inputs[tb]['sha256'],
                             identical_hdl_inputs=len(checked),
                             untested_in_this_case='native_hdmi_pll.v' if name!='native_pll' else None))
assert not out.exists(),'Never overwrite a frozen release'
out.mkdir(parents=True)
phy=build/'td_project/camera_to_dsi_display_Runs/phy_1'
bit=phy/'camera_to_dsi_display.bit';shutil.copy2(bit,out/bit.name)
shutil.copy2(engine/'release/edge_tail_fix_20261007/camera_to_dsi_display.bit',out/'rollback.bit')
assert sha(out/'rollback.bit')==metadata(final)['rollback_sha256']
shutil.copy2(final/'freeze.json',out/'input_snapshot.json')
shutil.copy2(build/'freeze.json',out/'td_build_snapshot.json')
shutil.copy2(engine/'tools/native_toolchain.json',out/'toolchain.json')
shutil.copytree(engine/'vendor_reference/sc500_1080p',out/'source_audit')
with zipfile.ZipFile(out/'input_snapshot.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(final/'freeze.json','freeze.json')
    for entry in metadata(final)['inputs']:
        src=final/entry['path'];assert sha(src)==entry['sha256'];z.write(src,entry['path'])
reports=out/'reports';reports.mkdir()
for run in ['syn_1','phy_1']:
    source=build/'td_project/camera_to_dsi_display_Runs'/run
    dest=reports/run;dest.mkdir()
    for path in source.iterdir():
        if path.suffix in ['.timing','.area','.qor','.rpt','.cfg','.prj','.tcl'] or path.name in ['console.log','constraint_coverage.txt','flow.status']:
            shutil.copy2(path,dest/path.name)
results=[]
for name,root in tests.items():
    dest=out/'tests'/name;dest.mkdir(parents=True)
    for logname in ['console.log','compile.log','transcript.log']:
        shutil.copy2(console(root,name).parent/logname,dest/logname)
    results.append(dict(name=name,status='PASS',freeze=str(root),console_sha256=sha(dest/'console.log')))
(out/'tests/results.json').write_text(json.dumps(results,indent=2)+'\n')
(out/'tests/source_identity.json').write_text(json.dumps(test_sources,indent=2)+'\n')
failures=[('r1_fhd_csi',outer/'native_1080p30_r1_20261007','fhd_csi'),
          ('r1_fhd_isp',outer/'native_1080p30_r1_20261007','fhd_isp'),
          ('r2_roi_guard',r2,'roi_guard'),
          ('r3_fractional_pll',outer/'native_pll_probe_r3_20261007','native_pll'),
          ('r4_pll_cli_option',build,'native_pll'),('r5_mc_timeout',r5,'fhd_mc')]
for label,root,name in failures:
    dest=out/'failures'/label;dest.mkdir(parents=True)
    shutil.copy2(root/'freeze.json',dest/'freeze.json')
    delta=[]
    for entry in metadata(root)['inputs']:
        rel=entry['path']
        if rel not in final_inputs or entry['sha256']!=final_inputs[rel]['sha256']:
            source=root/rel;assert sha(source)==entry['sha256'],(label,rel)
            target=dest/'source_delta'/rel;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,target);delta.append(rel)
    (dest/'source_delta.json').write_text(json.dumps(delta,indent=2)+'\n')
    for logname in ['console.log','compile.log']:
        log=console(root,name).parent/logname
        if log.exists():shutil.copy2(log,dest/logname)
        else:(dest/'missing_log.txt').write_text(str(log))
# Keep first synthesis failures, including the missing HDMI clock connection.
src=outer/'native_1080p30_r1_20261007/td_project/camera_to_dsi_display_Runs/syn_1'
dest=out/'failures/r1_synthesis';dest.mkdir()
for filename in ['console.log','constraint_coverage.txt','camera_to_dsi_display_gate.timing']:
    shutil.copy2(src/filename,dest/filename)
bitsha=sha(bit)
summary=dict(status='DIAGNOSTIC_CANDIDATE_NOT_ACCEPTED',stage=2,enable_edge=0,
 branch='lj4747-contest-work',base_commit='3be3967f2457622566fb20b7cef3aa5038e7d885',source_identity='input_snapshot.json SHA-256 manifest; working changes not committed',
 bit_sha256=bitsha,bit_bytes=bit.stat().st_size,td='6.2.178840',modelsim='SE-64 10.5 (2016-02-13)',
 routed_setup_wns_ns=0.143,routed_hold_wns_ns=0.020,setup_tns_ns=0,hold_tns_ns=0,setup_violated_endpoints=0,hold_violated_endpoints=0,
 sta_coverage_percent=95.31,all_paths_timing_accepted=False,resources=dict(slices=14911,slice_capacity=21216,eram=45,eram_capacity=108,dsp=8,dsp_capacity=40,pll=5,pll_capacity=6),
 clock_model_measurement_mhz=dict(pixel=74.250000,serial=371.250001,ratio=5.000000),
 tests_passed=len(results),tests_failed_final=0,tests_not_run=['FHD independent numerical RAW-to-demosaic/AWB reference','FHD EDGE/composite integration and four-mode round trips (stage 3 gated)','physical DDR write/read/stress','all physical acceptance'],
 open_constraints=dict(no_input_delay=39,no_output_delay=63,partial_input_delay=1,dummy_nodes=2,shadowed_groups=5,invalid_constraints=0,no_clock=0,pll_mismatch=0),
 burn='manual only; no board/JTAG actions performed',rollback_sha256=metadata(final)['rollback_sha256'])
(out/'release.json').write_text(json.dumps(summary,indent=2)+'\n')
(out/'SHA256SUMS.txt').write_text(''.join(sha(p)+'  '+p.relative_to(out).as_posix()+'\n' for p in sorted(out.rglob('*')) if p.is_file()),encoding='ascii')
print(json.dumps(summary,indent=2))
