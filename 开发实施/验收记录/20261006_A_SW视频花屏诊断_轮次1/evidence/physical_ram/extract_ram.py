from pathlib import Path
import re, json, hashlib

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
gate = root / 'tmp/modelsim_probe/sw_edge_gate_probe.v'
text = gate.read_text()
blocks=[]
for m in re.finditer(r'  PH1P_PHY_ERAM_V2 #\(',text):
    stop=text.index('));',m.start())+3
    b=text[m.start():stop]
    if r'\u_isp_top/u_roi_sobel_view/ramread' in b:
        blocks.append(b)
assert len(blocks)==12,len(blocks)
(out/'original_instances.v').write_text('\n'.join(blocks))
mapping = {
    r'\u_isp_top/u_roi_sobel_view/write_address':'write_address',
    r'\u_isp_top/u_roi_sobel_view/read_address':'read_address',
    r'\u_isp_top/u_roi_sobel_view/rgb':'rgb',
    r'\u_isp_top/u_demosaic/raw_matrix_3x3_buffer_d/zhenghe_d/blk_mem_gen_zhenghe_d1/ram_d32970204f32_Inst/clkb':'clk',
}
for i in range(4):
    mapping[rf'\u_isp_top/u_roi_sobel_view/line_bank[{i}]$memory_n']=f'bank_enable[{i}]'
    mapping[rf'\u_isp_top/u_roi_sobel_view/row_q[{i}]']=f'row_q[{i}]'
body='\n'.join(blocks)
for k,v in mapping.items():
    body=body.replace(k+' ',v+' ')
body=re.sub(r'\\u_isp_top/u_roi_sobel_view/(ramread\w+)\s+\(',lambda m:m[1]+' (',body)
opens=sorted(set(re.findall(r'\bopen_n\d+\b',body)))
left=re.findall(r'\\\S+',body)
assert not left,left[:5]
decl='\n'.join('wire '+v+';' for v in opens)
wrapper='''`timescale 1ns/1ps
module mapped_rgb_ram(input clk, input [3:0] bank_enable,
 input [7:0] write_address,read_address,input [95:0] rgb,
 output wire [95:0] row_q [0:3]);
'''+decl+'\n'+body+'\nendmodule\n'
(out/'mapped_rgb_ram.v').write_text(wrapper)
summary=[]
for b in blocks:
    name=re.search(r'\\u_isp_top/u_roi_sobel_view/(\S+)\s+\(',b)[1]
    params=dict(re.findall(r'\.(\w+)\(("[^"\n]+"|[\d]+)\)',b))
    connections=b[b.index('    \\u_isp_top'):]
    summary.append({'name':name,'mode':params['MODE'],'width_a':params['DATA_WIDTH_A'],'width_b':params['DATA_WIDTH_B'],'regmode_b':params['REGMODE_B'],'connections':connections})
(out/'extraction_manifest.json').write_text(json.dumps({'gate_sha256':hashlib.sha256(gate.read_bytes()).hexdigest(),'blocks':summary},indent=2))
for s in summary:
    print(s['name'],s['mode'],s['width_a'],s['width_b'],s['regmode_b'])
