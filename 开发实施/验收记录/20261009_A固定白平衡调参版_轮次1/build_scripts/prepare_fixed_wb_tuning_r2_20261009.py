from pathlib import Path
import hashlib, json, shutil, re

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
first = root / 'tmp/fixed_wb_tuning_td_20261009'
build = root / 'tmp/fixed_wb_tuning_r2_td_20261009'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
dump = lambda p, d: p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
assert not build.exists()
baseline = json.loads((first / 'inputs.json').read_text(encoding='utf-8-sig'))
for e in baseline:
    assert sha(first / e['path']) == e['sha256'] == sha(project / e['path']), e['path']

p = project / 'user_source/hdl_source/awb.v'
raw = p.read_bytes()
start = raw.index(b'    reg  [19:0]   in_r_r1;')
end = raw.index(b'\r\n\r\n    ////', start)
old_block = raw[start:end]
automatic = old_block[old_block.index(b'    always @'):]
automatic = automatic.replace(b'        // Fixed gains retain the existing pixel/sync pipeline.\r\n', b'')
automatic = automatic.replace(b'if(!I_rst_n || I_tuser || FIXED_GAIN)', b'if(!I_rst_n || I_tuser)')
automatic = automatic.replace(b"FIXED_GAIN ? FIXED_R_GAIN : 20'h10000", b"20'h10000")
automatic = automatic.replace(b"FIXED_GAIN ? FIXED_B_GAIN : 20'h10000", b"20'h10000")
automatic = automatic.replace(b'in_r_r1', b'red_gain').replace(b'in_b_r1', b'blue_gain')
automatic = b'\r\n'.join(b'        ' + line.rstrip() if line else line for line in automatic.split(b'\r\n'))
new_block = b'''    wire [19:0] in_r_r1;
    wire [19:0] in_b_r1;
    // Select constant gains without a clocked constant-assignment process.
    // The original pixel/sync pipeline and automatic path are retained.
    generate
        if(FIXED_GAIN)begin : fixed_gain
            assign in_r_r1 = FIXED_R_GAIN;
            assign in_b_r1 = FIXED_B_GAIN;
        end
        else begin : automatic_gain
            reg [19:0] red_gain;
            reg [19:0] blue_gain;
            assign in_r_r1 = red_gain;
            assign in_b_r1 = blue_gain;
''' + automatic + b'''        end
    endgenerate
'''
new_block = new_block.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
p.write_bytes(raw[:start] + new_block + raw[end:])

inputs = []
for e in baseline:
    src, dst = project / e['path'], build / e['path']
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    inputs.append(dict(path=e['path'], bytes=dst.stat().st_size, sha256=sha(dst)))
changed = [e['path'] for e, b in zip(inputs, baseline) if e['sha256'] != b['sha256']]
assert changed == ['user_source/hdl_source/awb.v']
stages = []
for stage in ['syn_1', 'phy_1']:
    rel = Path('td_project/camera_to_dsi_display_Runs') / stage
    dst = build / rel
    dst.mkdir(parents=True)
    for name in ['settings.cfg', 'build.tcl', 'camera_to_dsi_display.prj']:
        shutil.copy2(first / rel / name, dst / name)
        stages.append(dict(path=(rel / name).as_posix(), sha256=sha(dst / name)))
    paths = re.findall(r'<File Path="([^"]+)"', (dst / 'camera_to_dsi_display.prj').read_text(encoding='utf-8-sig'))
    assert len(paths) == 69 and all((dst / path).is_file() for path in paths)
sim = build / 'sim'
sim.mkdir()
for src in (project / 'sim').iterdir():
    if src.is_file() and src.suffix in {'.v', '.py', '.ps1', '.md', '.do'}:
        shutil.copy2(src, sim / src.name)
shutil.copytree(project / 'sim/osd_assets', sim / 'osd_assets')
dump(build / 'inputs.json', inputs)
dump(build / 'stage_inputs.json', stages)
dump(build / 'preparation.json', dict(baseline='presence_modes_v3_20261008', inputs=209, project_sources=69,
     changed_production_inputs=['user_source/hdl_source/awb.v', 'user_source/hdl_source/isp/isp_top.v'],
     r2_changes_from_attempt1=changed, fixed_red_blue_gain=1.0, optical_thresholds_unvalidated=True,
     reason='Attempt1 synthesis introduced two HDL-7238 critical warnings on constant clocked gain assignments; use elaboration-time constant nets and preserve original automatic path.',
     relevant_retests=['fixed_wb', 'pixel_interface', 'isp_writer_stop', 'roi_chain'],
     attempt1_preserved=first.name))
print('PASS R2 isolated 209 inputs / 69 sources; AWB constant nets replace warned clocked assignments')
