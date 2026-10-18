from pathlib import Path
import hashlib,json,re,shutil
from PIL import Image,ImageDraw,ImageFont
r=Path.cwd();p=r/'fpga/component_inspector';base=p/'handoff/threshold180_20261018';rd=r/'tmp/small_dual_edit_20261018';s=rd/'source_snapshot'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
rd.mkdir(exist_ok=False)
for n in ['source_snapshot','scripts']:shutil.copytree(base/n,rd/n)
# Latest live production must agree with the selected delivered hardware.
bm=json.loads((s/'inputs.json').read_text('utf-8'))
for n,h in bm.items():
 if n.startswith('user_source/'):assert sha(p/n)==h,n
live_before={n:sha(p/n) for n in bm if (p/n).exists() and n.startswith(('user_source/','sim/'))}
q=s/'user_source/hdl_source/inspection_region_config.v';t=q.read_text('utf-8')
t=t.replace('parameter WIDTH=1280,HEIGHT=720,','parameter WIDTH=1280,HEIGHT=720,COMPACT=0,')
t=t.replace('parameter X00=WIDTH*5/16,X01=WIDTH*11/16,Y00=HEIGHT/3,Y01=HEIGHT*5/9,','parameter X00=COMPACT ? WIDTH/2-80 : WIDTH*5/16,X01=COMPACT ? WIDTH/2+80 : WIDTH*11/16,\n Y00=COMPACT ? HEIGHT/2-112 : HEIGHT/3,Y01=COMPACT ? HEIGHT/2-8 : HEIGHT*5/9,')
t=t.replace('parameter X10=WIDTH*5/16,X11=WIDTH*11/16,Y10=HEIGHT*3/5,Y11=HEIGHT*5/6,','parameter X10=COMPACT ? WIDTH/2-80 : WIDTH*5/16,X11=COMPACT ? WIDTH/2+80 : WIDTH*11/16,\n Y10=COMPACT ? HEIGHT/2+8 : HEIGHT*3/5,Y11=COMPACT ? HEIGHT/2+112 : HEIGHT*5/6,')
q.write_text(t,encoding='utf-8')
q=s/'user_source/hdl_source/frame_shape_search.v';t=q.read_text('utf-8')
t=t.replace('parameter WIDTH=1024,HEIGHT=600,REGIONS=0,','parameter WIDTH=1024,HEIGHT=600,REGIONS=0,LANE_SINGLE=0,')
t=t.replace('parameter SMALL_Y0=HEIGHT/3-16,SMALL_Y1=HEIGHT*5/6+16,','parameter SMALL_Y0=LANE_SINGLE ? HEIGHT/2-176 : HEIGHT/3-16,SMALL_Y1=LANE_SINGLE ? HEIGHT/2+176 : HEIGHT*5/6+16,')
t=t.replace('cfg(region_bounds,region_models,region_recipes,region_supported);','cfg(region_bounds,region_models,region_recipes,region_supported);').replace('inspection_region_config #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) cfg','inspection_region_config #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.COMPACT(LANE_SINGLE)) cfg')
t=t.replace('localparam SLOTS=REGIONS ? 4 : 2;','localparam SLOTS=REGIONS && !LANE_SINGLE ? 4 : 2;')
t=t.replace("wire [1:0] bank0=candidate_region ? 2'd2 : 2'd0,bank1=bank0+1'b1;","wire [1:0] bank0=REGIONS && LANE_SINGLE ? {1'b0,candidate_region} : candidate_region ? 2'd2 : 2'd0;\nwire [1:0] bank1=REGIONS && LANE_SINGLE ? bank0 : bank0+1'b1;")
t=t.replace("ref_index[1] ? region_recipes","(LANE_SINGLE ? ref_index[0] : ref_index[1]) ? region_recipes")
t=t.replace('generate if(REGIONS)begin\n assign sorted1=', 'generate if(REGIONS && !LANE_SINGLE)begin\n assign sorted1=')
t=t.replace('wire [75:0] primary_record=!REGIONS ?', 'wire [75:0] primary_record=REGIONS && LANE_SINGLE ? (records[75] ? records[75:0] : records[151:76]) : !REGIONS ?')
t=t.replace('if(found_bank[bank0])begin','if(!(REGIONS && LANE_SINGLE) && found_bank[bank0])begin')
t=t.replace('end else if(before_second)begin','end else if(!(REGIONS && LANE_SINGLE) && before_second)begin')
t=t.replace('bi/2==candidate_region &&','(LANE_SINGLE ? bi : bi/2)==candidate_region &&')
t=t.replace("objects<=(!REGIONS && !legacy_pair_selected) ?", "objects<=REGIONS && LANE_SINGLE ? records : (!REGIONS && !legacy_pair_selected) ?")
t=t.replace('region_objects<={sorted1,sorted0};',"region_objects<=REGIONS && LANE_SINGLE ? {76'd0,records[151:76],76'd0,records[75:0]} : {sorted1,sorted0};")
q.write_text(t,encoding='utf-8')
q=s/'user_source/hdl_source/isp/isp_top.v';t=q.read_text('utf-8');assert t.count('frame_shape_search #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.REGIONS(REGIONS))')==1
t=t.replace('frame_shape_search #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.REGIONS(REGIONS))','frame_shape_search #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.REGIONS(REGIONS),.LANE_SINGLE(REGIONS))');q.write_text(t,encoding='utf-8')
# Keep legacy non-region modes byte-for-byte below a production-only wrapper.
# Old functionality is a constant-eliminated branch, not a runtime debug page.
q=s/'user_source/hdl_source/experiment_osd.v';old=q.read_text('utf-8');header=old[:old.index('localparam [199:0] calibration_text')]
params=re.findall(r'\b([A-Z][A-Z0-9_]*)\s*=',header[:header.index(')(')])
ports=re.sub(r'\[[^\]]+\]','',header[header.index(')(')+2:header.index(');')]);ports=re.sub(r'\b(input|output|wire|reg)\b','',ports);ports=[x.strip() for x in ports.split(',')];assert all(re.fullmatch(r'\w+',x) for x in ports)
wrapper=header.replace('parameter WIDTH=1024','parameter COMPACT_UI=1,WIDTH=1024').replace('output reg','output wire')
wrapper+='generate if(REGIONS && FRAME_OBJECTS && COMPACT_UI)begin : compact_ui\n compact_lane_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ENABLE(ENABLE)) ui(\n'
subset=['clk','rst_n','vs','hs','de','rgb','exposure','gain','fps','view_mode','roi_valid','cfg_done','frame_objects','out_vs','out_hs','out_de','out_rgb']
wrapper+=','.join('.'+n+'('+n+')' for n in subset)+',\n .error(|lane_errors || |format_errors || |i2c_errors || |gaps || |overflow_frames || |lost_frames || |underflow_frames));\n'
wrapper+='end else begin : legacy_ui\n experiment_osd_legacy #('+','.join('.'+n+'('+n+')' for n in params)+') ui(\n'+','.join('.'+n+'('+n+')' for n in ports)+');\nend endgenerate\nendmodule\n\n'
q.write_text(wrapper+old.replace('module experiment_osd #(','module experiment_osd_legacy #(',1),encoding='utf-8')
# Crop the CJK atlas to9 glyphs plus blank, using the original stroke bitmaps
# where available. Two additional operator words use the same installed font.
meta=json.loads((s/'sim/osd_assets/manifest.json').read_text('utf-8'));oldrows=[int(x,16) for x in (s/'sim/osd_assets/osd_cjk_rom.hex').read_text().split()]
chars='有件空穴待检测复核';rows=[0]*512
for i,ch in enumerate(chars,1):
 if ch in meta['cjk_glyph_ids']:
  k=meta['cjk_glyph_ids'][ch];rows[i*32:(i+1)*32]=oldrows[k*32:(k+1)*32]
 else:
  im=Image.new('L',(24,24));d=ImageDraw.Draw(im);font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',23);b=d.textbbox((0,0),ch,font=font)
  d.text(((24-(b[2]-b[0]))//2-b[0],(24-(b[3]-b[1]))//2-b[1]),ch,font=font,fill=255)
  for y in range(24):rows[i*32+y]=sum((im.getpixel((x,y))>=100)<<(23-x) for x in range(24))
(s/'sim/osd_assets/compact_cjk.hex').write_text(''.join(f'{v:06x}\n' for v in rows),encoding='ascii')
rtl=(r/'tmp/compact_lane_osd.v.txt').read_text('utf-8')
rtl=rtl.replace('// CJK_INIT', '\n'.join(f" cjk_memory[{i}]=24'h{v:06x};" for i,v in enumerate(rows)))
with q.open('a',encoding='utf-8') as f:f.write('\n'+rtl)
# Legacy multi-card oracle remains available; the new production UI has its
# own independent, full-raster fixture and is tested separately.
q=s/'sim/tb_regions_osd.v';t=q.read_text('utf-8').replace('experiment_osd #(', 'experiment_osd #(.COMPACT_UI(0),',1);q.write_text(t,encoding='utf-8')
baseline=dict(base_bit_sha256='21dc549f9f50bba288b4da197333364c1be128dbd7b2234139c632d99e8531f0',base_source_manifest_sha256=sha(base/'source_snapshot/inputs.json'),base_resources=json.loads((base/'handoff.json').read_text('utf-8'))['resources'],live_before=live_before,scope='Two horizontal carrier lanes, centered160x104 windows, one current target per lane, compact operator UI, same thresholds/4 views/ISP/video/CDC/SDC. No claim full physical coverage or all flipped states solved.',motion='Nearest-center frame-local selection; fixed lane identity, no multi-target display ID permutation. Not an encoder-backed persistent identity or event counter.',source_changes_pending_freeze=True)
(rd/'baseline.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('EDIT sources prepared; not frozen, built or integrated',rd)
