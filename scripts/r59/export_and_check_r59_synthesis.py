from pathlib import Path
import hashlib,json,os,re,subprocess,sys

w=Path('D:/FpgaWork/r59_build_b_20261102');root=Path('D:/FpgaWork/r59_field_20261102')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
db=w/'runs/syn_1/camera_to_dsi_display_gate.db';net=w/'d3_camera_gate.v'
check_only='--check-only' in sys.argv
assert db.exists() and (not net.exists() or check_only)
before=sha(db);tcl=w/'export_r59_synthesis.tcl'
tcl.write_text('''if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd {WORK/runs/syn_1}
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_gate.db
write_verilog {WORK/d3_camera_gate.v}
} reason]} {puts stderr $reason; exit 1}
exit 0
'''.replace('WORK',w.as_posix()),encoding='utf8')
env=os.environ.copy();env['TEMP']=env['TMP']=str(w/'temp')
if not check_only:
 with (w/'export_r59_synthesis.log').open('w',encoding='utf8') as log:
  r=subprocess.run(['D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe'],input='source {'+tcl.as_posix()+'}\n',text=True,cwd=w,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
 assert r.returncode==0
else:
 log=(w/'export_r59_synthesis.log').read_text(encoding='utf8')
 assert 'write_verilog' in log and not re.search(r'(?mi)^\s*(?:ERROR|\w+-\d+\s*:\s*Error)',log)
assert net.exists() and sha(db)==before
s=net.read_text(encoding='utf8')
cells=list(re.finditer(r'PH1P_PHY_ERAM_V2 #\((.*?)\)\s+(\\\S+)\s+\((.*?)\);([^\n]*)',s,re.S))
font=[m for m in cells if m[2].endswith('/font_bits')]
queue=[m for m in cells if 'local_shape_detection$detector/q_write_addr' in m[3] and 'local_shape_detection$detector/q_read' in m[3]]
ids=[m for m in cells if '/observe_counter$counter/' in m[2]]
sobel=[m for m in cells if '/u_roi_sobel_view/' in m[2]]
gray=[m for m in sobel if re.search(r'line_bank\[\d\]\$memory_n',m[3])]
color=[m for m in sobel if 'color_cache$rgb_memory_n' in m[3]]
print(json.dumps({'eram':len(cells),'font':[m[2] for m in font],'queue':[m[2] for m in queue],'ids':[m[2] for m in ids],'sobel':[m[2] for m in sobel]},indent=2),flush=True)
assert len(cells)==107 and len(font)==1 and len(queue)==2 and len(ids)==2 and len(gray)==4 and len(color)==5
assert any('q_data [20]' in m[3] and 'popped_y [8]' in m[3] for m in queue)
assert len(color)==5
rgb_bits=set()
for m in color:
 assert m[1].count('.DATA_WIDTH_A("20")')==m[1].count('.DATA_WIDTH_B("20")')==1
 for hi,lo in re.findall(r'color_cache\$rgb_memory_b \[(\d+)(?::(\d+))?\]',m[3]):
  rgb_bits.update(range(int(lo or hi),int(hi)+1))
assert rgb_bits==set(range(96)),rgb_bits
assert {int(re.search(r'line_bank\[(\d)\]\$memory_n',m[3])[1]) for m in gray}==set(range(4))
init=lambda text:{int(k,16):int(v,16 if base=='h' else 2) for k,base,v in re.findall(r"\.INIT_([0-9A-F]{2})\(256'([hb])([0-9a-fA-F]+)\)",text)}
expected=json.loads((Path('D:/FpgaWork/r28_field_20261102/r57_font_reference.json')).read_text(encoding='utf8'))['font_bytes']
expected={i:int.from_bytes(bytes(expected[i*32:(i+1)*32]),'little') for i in range(64)}
assert init(font[0][1])==expected
for lane,m in enumerate(sorted(ids,key=lambda m:m[2])):
 prefix='u_isp_top/classified_counting$dual_regions$pipeline/regions['+str(lane)+']$pipeline/'
 assert prefix in m[2]
 assert '.addra({\\'+prefix+"observe_counter$counter/empty_total ,5'b11111})" in m[3]
 assert '.addrb({\\'+prefix+"empty_address ,5'b11111})" in m[3]
 assert m[1].count('.DATA_WIDTH_A("40")')==m[1].count('.DATA_WIDTH_B("40")')==1
assert all(m[1].count('.DATA_WIDTH_A("40")')==m[1].count('.DATA_WIDTH_B("40")')==1 for m in gray)
result={'status':'PASS_R59_ACTUAL_SYNTHESIS_SMALL_FONT_ID_QUEUE_AND_GRAY_BANKS',
 'gate_database_sha256':before,'netlist_sha256':sha(net),'source_manifest_sha256':sha(w/'frozen_inputs.json'),
 'eram_cells':len(cells),'font_cells':len(font),'font_init_blocks_exact':64,'queue_cells':len(queue),
 'independent_id_cells':len(ids),'sobel_gray_cells':len(gray),'rgb_background_cells':len(color),'full_rgb_input_bits':len(rgb_bits),
 'font_cell':font[0][2],'queue_cell_names':[m[2] for m in queue],
 'scope':'Actual new SYN netlist mapping and initialization; not physical timing or board acceptance'}
(w/'R59_SYNTHESIS_PROOF.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print('PASS actual R59 synthesized 16x16 font, two ID RAMs, widened word queue and preserved gray banks',flush=True)
