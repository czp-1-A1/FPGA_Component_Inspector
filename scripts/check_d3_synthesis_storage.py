"""Check actual synthesized font bits and the two independently addressed ID ERAMs."""
from pathlib import Path
import argparse,hashlib,json,re

a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);x=a.parse_args()
w=x.work.resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
net=w/'d3_camera_gate.v';s=net.read_text()
source=w/'project/user_source/hdl_source/compact_inspector_osd.v'
rom=source.read_text().split('module compact_shared_font_rom(',1)[1]
cells=list(re.finditer(r'PH1P_PHY_ERAM_V2 #\((.*?)\)\s+(\\\S+)\s+\((.*?)\);([^\n]*)',s,re.S))
font=[m for m in cells if m[2].endswith('/font_bits')];assert len(font)==1
init=lambda text:{int(k,16):int(v,16 if base=='h' else 2) for k,base,v in re.findall(r"\.INIT_([0-9A-F]{2})\(256'([hb])([0-9a-fA-F]+)\)",text)}
assert len(init(rom))==64 and init(rom)==init(font[0][1])
db=w/'runs/syn_1/camera_to_dsi_display_gate.db'
receipt={'status':'PASS_ACTUAL_SYNTHESIS_FONT_INITIALIZATION','source_sha256':sha(source),'gate_database_sha256':sha(db),'netlist_sha256':sha(net),'init_blocks_exact':64,'cell':font[0][2]}
(w/'FONT_SYNTHESIS_PROOF.json').write_text(json.dumps(receipt,indent=2)+'\n')
tables=[m for m in cells if '/observe_counter$counter/' in m[2]]
assert len(tables)==2
ids=[]
for lane,m in enumerate(sorted(tables,key=lambda m:m[2])):
    root='u_isp_top/classified_counting$dual_regions$pipeline/regions['+str(lane)+']$pipeline/'
    assert root in m[2]
    assert '.addra({\\'+root+"observe_counter$counter/empty_total ,5'b11111})" in m[3]
    assert '.addrb({\\'+root+"empty_address ,5'b11111})" in m[3]
    assert m[1].count('.DATA_WIDTH_A("40")')==m[1].count('.DATA_WIDTH_B("40")')==1
    ids.append({'lane':lane,'cell':m[2],'write_count_address_bits':9,'independent_read_address_bits':9})
receipt={'status':'PASS_ACTUAL_SYNTHESIS_TWO_INDEPENDENT_ID_ERAMS','gate_database_sha256':sha(db),'netlist_sha256':sha(net),'cells':ids,'scope':'Mapping/width/address independence proof; source read-port and counter behavior proven separately by simulation. No post-route or board acceptance.'}
(w/'ID_RAM_SYNTHESIS_PROOF.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PASS actual SYN font64 INIT blocks and two independent 9-bit-address ID ERAMs')
