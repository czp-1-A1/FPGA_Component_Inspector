from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parent;repo=Path('D:/CodexWork/erole_fix_20261102')
names=subprocess.check_output(['git','ls-tree','-r','--name-only','HEAD','fpga/component_inspector'],cwd=repo,text=True).splitlines();assert len(names)==638
cat=subprocess.Popen(['git','cat-file','--batch'],cwd=repo,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
manifest={}
for name in names:
 cat.stdin.write(('HEAD:'+name+'\n').encode());cat.stdin.flush()
 header=cat.stdout.readline().decode().split();assert len(header)==3 and header[1]=='blob'
 blob=cat.stdout.read(int(header[2]));assert cat.stdout.read(1)==b'\n'
 manifest[name.removeprefix('fpga/component_inspector/')]=hashlib.sha256(blob).hexdigest()
cat.stdin.close();assert cat.wait()==0
(root/'baseline_inputs.json').write_text(json.dumps(manifest,indent=2)+'\n')
f=repo/'tests/pocket_row_roles';f.mkdir(exist_ok=True)
old=(repo/'tests/empty_only_stop/tb_empty_only_native.sv').read_text()
new=old.replace('tb_empty_only_native','tb_pocket_row_native').replace('isp_top #(', 'isp_top #(.POCKET_ROW_ROLES(1),',1)
(f/'tb_pocket_row_native.sv').write_text(new)
assert new.replace('tb_pocket_row_native','tb_empty_only_native').replace('isp_top #(.POCKET_ROW_ROLES(1),','isp_top #(')==old
(f/'derivation.json').write_text(json.dumps({'base':'tests/empty_only_stop/tb_empty_only_native.sv','base_sha256':hashlib.sha256(old.encode()).hexdigest(),'new_sha256':hashlib.sha256(new.encode()).hexdigest(),'only_changes':['module name','POCKET_ROW_ROLES=1'],'expectations_unchanged':True},indent=2)+'\n')
# Exact top parameter chain and unchanged stop policy must both be present.
hdl=repo/'fpga/component_inspector/user_source/hdl_source'
top=(hdl/'design_top_wrapper.v').read_text();isp=(hdl/'isp/isp_top.v').read_text()
assert 'EMPTY_ONLY_STOP=1,POCKET_ROW_ROLES=1' in top
assert '.EMPTY_ONLY_STOP(EMPTY_ONLY_STOP),.POCKET_ROW_ROLES(POCKET_ROW_ROLES)' in top
assert 'frame_shape_search #(.POCKET_ROW_ROLES(POCKET_ROW_ROLES),' in isp
assert '.EMPTY_ONLY_STOP(EMPTY_ONLY_STOP),' in isp
print('PASS 638 baseline blobs, exact unchanged native assertions and production role/stop parameter chain')
