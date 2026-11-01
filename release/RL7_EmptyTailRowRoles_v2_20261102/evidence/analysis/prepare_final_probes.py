from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parent;repo=Path('D:/CodexWork/erole_fix_20261102');candidate=repo/'fpga/component_inspector/user_source/hdl_source'
assert json.loads((root/'refinement_status.json').read_text())['status']=='PROMOTED_REFINEMENT_REQUIRES_FRESH_NATIVE_AND_ROUTING'
for index,old_i,bench,runner in [(4,0,'tb_tail_role_sweep','run_probe.py'),(5,1,'tb_tail_aperture_sweep','run_aperture_probe.py')]:
 out=root/f'frozen_r{index}';out.mkdir(exist_ok=False)
 for p in (root/f'frozen_r{old_i}').glob('*.v'):shutil.copy2(candidate/p.name,out/p.name)
 s=(root/f'frozen_r{old_i}'/(bench+'.sv')).read_bytes()
 needle=b'frame_shape_search #(';assert s.count(needle)==1;s=s.replace(needle,needle+b'.POCKET_ROW_ROLES(1),')
 (out/(bench+'.sv')).write_bytes(s)
 hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()}
 (out/'INPUT_SHA256.json').write_text(json.dumps(hashes,indent=2)+'\n')
 r=(root/runner).read_text().replace(f"src=root/'frozen_r{old_i}';out=root/'run_r{old_i}'",f"src=root/'frozen_r{index}';out=root/'run_r{index}'")
 (root/f'run_final_probe_r{index}.py').write_text(r)
print('Final refined production82 diagnostics frozen with exactly original stimuli')
