from pathlib import Path
import hashlib, json, shutil, subprocess, re

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
prior = root / 'tmp/presence_modes_v3_td_20261008'
before = root / 'tmp/fixed_wb_tuning_before_20261009'
build = root / 'tmp/fixed_wb_tuning_td_20261009'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
dump = lambda p, d: p.write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
baseline = json.loads((prior/'inputs.json').read_text(encoding='utf-8-sig'))
assert not before.exists() and not build.exists()
assert subprocess.check_output(['git','rev-parse','HEAD'], cwd=root, text=True).strip() == '3be3967f2457622566fb20b7cef3aa5038e7d885'
for e in baseline:
    assert sha(project/e['path']) == e['sha256'], e['path']
    dest = before/e['path']; dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(project/e['path'], dest)
for relative in ['sim', 'td_project/current_codex_build.json']:
    source = project/relative
    if source.is_dir():
        dest = before/relative; dest.mkdir()
        for p in source.iterdir():
            if p.is_file() and p.suffix in {'.v','.py','.ps1','.md','.do'}: shutil.copy2(p,dest/p.name)
        shutil.copytree(source/'osd_assets',dest/'osd_assets')
    else: shutil.copy2(source,before/relative)
for relative in ['AGENTS.md','开发实施/00_分阶段开发与逐级验证路线.md','开发实施/33_A3528成像冻结与物料配方实施方案.md']:
    dest=before/'documents'/relative; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(root/relative,dest)
dump(before/'inputs.json',baseline)

# Patch ASCII bytes only; preserve legacy source comments and CRLF exactly.
p=project/'user_source/hdl_source/awb.v'; raw=p.read_bytes()
old=b'    parameter IMG_WIDTH  = 1920\r\n'
new=b'    parameter IMG_WIDTH  = 1920,\r\n    parameter FIXED_GAIN = 0,\r\n    parameter [19:0] FIXED_R_GAIN = 20\'h10000,\r\n    parameter [19:0] FIXED_B_GAIN = 20\'h10000\r\n'
assert raw.count(old)==1; raw=raw.replace(old,new)
old=b'        if(!I_rst_n || I_tuser)begin\r\n            in_r_r1 <= 20\'h10000;\r\n            in_b_r1 <= 20\'h10000;\r\n'
new=b'        // Fixed gains retain the existing pixel/sync pipeline.\r\n        if(!I_rst_n || I_tuser || FIXED_GAIN)begin\r\n            in_r_r1 <= FIXED_GAIN ? FIXED_R_GAIN : 20\'h10000;\r\n            in_b_r1 <= FIXED_GAIN ? FIXED_B_GAIN : 20\'h10000;\r\n'
assert raw.count(old)==1; p.write_bytes(raw.replace(old,new))
p=project/'user_source/hdl_source/isp/isp_top.v'; raw=p.read_bytes()
old=b'    .IMG_WIDTH (1024)\r\n'
new=b'    .IMG_WIDTH (1024),\r\n    .FIXED_GAIN(1) // Unity-gain imaging trial; optical thresholds need remeasurement.\r\n'
assert raw.count(old)==1; p.write_bytes(raw.replace(old,new))
print('PASS before snapshot and minimal fixed-gain RTL patch:', len(baseline), 'production inputs')
