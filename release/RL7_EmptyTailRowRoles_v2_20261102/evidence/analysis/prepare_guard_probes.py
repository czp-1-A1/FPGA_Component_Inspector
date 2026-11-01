from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parent;candidate=Path('D:/CodexWork/erole_fix_20261102/fpga/component_inspector')
for index,old_name,new_name in [(2,'frozen_r0','tb_tail_role_sweep'),(3,'frozen_r1','tb_tail_aperture_sweep')]:
 old=root/old_name;out=root/f'frozen_r{index}';out.mkdir(exist_ok=False)
 for p in old.glob('*.v'):
  changed=candidate/'user_source/hdl_source'/p.name
  assert changed.exists();shutil.copy2(changed,out/p.name)
 fixture=old/(new_name+'.sv');s=fixture.read_text();needle='frame_shape_search #('
 assert s.count(needle)==1;s=s.replace(needle,needle+'.POCKET_ROW_ROLES(1),')
 (out/fixture.name).write_text(s)
 inputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()}
 (out/'INPUT_SHA256.json').write_text(json.dumps(inputs,indent=2)+'\n')
 old_runner=(root/('run_probe.py' if index==2 else 'run_aperture_probe.py')).read_text()
 old_index=0 if index==2 else 1
 runner=old_runner.replace(f"src=root/'frozen_r{old_index}';out=root/'run_r{old_index}'",f"src=root/'frozen_r{index}';out=root/'run_r{index}'")
 (root/f'run_guard_probe_r{index}.py').write_text(runner)
print('Two candidate probe inputs frozen; original diagnostics unchanged')
