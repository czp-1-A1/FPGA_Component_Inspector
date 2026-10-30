"""Create an isolated, lossless label-renderer sharing experiment.

Never edits the production tree. The reference is the exact original source;
only the choice of the winning overlapping label precedes character rendering.
"""
from pathlib import Path
import hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[1]
BASE=Path('E:/2026FPGA/.codex_tmp/d3_rank_storage_source_r16_20261030/project')
OUT=Path('E:/2026FPGA/.codex_tmp/d3_osd_share_source_r18_20261030')
assert not OUT.exists()
shutil.copytree(BASE,OUT/'project')
p=OUT/'project/user_source/hdl_source/compact_inspector_osd.v'
raw=p.read_bytes();s=raw.decode().replace('\r\n','\n')
reference=ROOT/'tests/dual_stop_d3/r11_reference_compact_inspector_osd.sv'
assert not reference.exists()
reference.write_bytes(s.replace('module compact_inspector_osd #','module r11_reference_compact_inspector_osd #',1).encode())
s=s.replace('reg prefix;integer t;','reg prefix;integer t;reg label_hit;reg [1:0] label_slot;')
s=s.replace('glyph_cell=0;prefix=0;repair_border=0;','glyph_cell=0;prefix=0;repair_border=0;label_hit=0;label_slot=0;')
start=s.index('  for(t=0;t<4;t=t+1)begin\n   ob=obs[t*76+:76];id=0;id_bcd=0;')
end=s.index('\n end\n if(AUTO_RELAY)begin',start)
s=s[:start]+'''  // Bounds retain the original four parallel hit tests and last-hit priority.
  // Only the winning label needs glyph/decimal/colour formatting on this pixel.
  for(t=0;t<4;t=t+1)begin
   ob=obs[t*76+:76];id=0;
   if(page_s && (DUAL_REGION_COUNT || t/2==record[57]))
    id=DUAL_REGION_COUNT && t>=2 ? record2[94+t*9+:9] : record[94+t*9+:9];
   if(ready && ob[75] && (!page_s || eligible_s && (DUAL_REGION_COUNT || t/2==record[57])))begin
    if(((x==ob[41:31] || x==ob[30:20]) && y>=ob[19:10] && y<=ob[9:0]) ||
      ((y==ob[19:10] || y==ob[9:0]) && x>=ob[41:31] && x<=ob[30:20]))guide=1;
    prefix=page_s && (DUAL_REGION_COUNT && t>=2 ? show2 : show) && id!=0;
    lx=ob[41:31]>WIDTH-112 ? WIDTH-112 : ob[41:31];
    ly=t%2==0 ? (ob[19:10]>=108 ? ob[19:10]-28 : 80) : (ob[9:0]<HEIGHT-124 ? ob[9:0]+4 : HEIGHT-120);
    rx=lx+(prefix ? 112 : 72);
    if(x>=lx && x<rx && y>=ly && y<ly+24)begin label_hit=1;label_slot=t;end
   end
  end
  if(label_hit)begin
   case(label_slot)
    0:begin ob=obs[75:0];id=record[94+:9];id_bcd=label_bcd0;end
    1:begin ob=obs[151:76];id=record[103+:9];id_bcd=label_bcd1;end
    2:begin ob=obs[227:152];id=DUAL_REGION_COUNT ? record2[112+:9] : record[112+:9];id_bcd=label_bcd2;end
    3:begin ob=obs[303:228];id=DUAL_REGION_COUNT ? record2[121+:9] : record[121+:9];id_bcd=label_bcd3;end
   endcase
   if(!DUAL_REGION_COUNT)id_bcd=label_slot[0] ? label_bcd1 : label_bcd0;
   prefix=page_s && (DUAL_REGION_COUNT && label_slot[1] ? show2 : show) && id!=0;
   lx=ob[41:31]>WIDTH-112 ? WIDTH-112 : ob[41:31];
   ly=!label_slot[0] ? (ob[19:10]>=108 ? ob[19:10]-28 : 80) : (ob[9:0]<HEIGHT-124 ? ob[9:0]+4 : HEIGHT-120);
   panel=1;row=y-ly;glyph_cell=(x-lx)>>3;col=(x-lx)&7;
   if(prefix && glyph_cell<4)code=glyph_cell==0 ? (frame_gap!=0 && id>=frame_gap ? "R" : "N") : "0"+((id_bcd>>((3-glyph_cell)*4))&4'hf);
   else if(prefix && glyph_cell==4)code=32;
   else code=class_char(ob[74:73],ob[74:73]==2 && ob[72:69]!=0,prefix ? glyph_cell-5 : glyph_cell);
   if(code[7])col={code[5:4],3'd0}+((x-lx)&7);
   ink=ob[74:73]==3 ? 24'hffe080 : ob[74:73]==2 && ob[72:69]==0 ? 24'h70ffdd : 24'hffb070;
  end''' +s[end:]
p.write_bytes(s.encode())
sha=lambda b:hashlib.sha256(b).hexdigest()
(OUT/'PROVENANCE.json').write_text(json.dumps({'production_modified':False,'base':str(BASE),'osd_before':sha(raw),'osd_after':sha(p.read_bytes()),'reference_normalized':sha(reference.read_bytes()),'scope':'Share only winning label formatting; no removed text, snapshots, bbox, IDs, diagnostics, fonts or output clocks.'},indent=2)+'\n')
print(OUT)
