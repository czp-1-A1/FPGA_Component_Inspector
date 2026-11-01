"""Apply two display-only transforms to the exact backed-up Demo V1."""
from pathlib import Path
import hashlib, json, re

repo=Path(__file__).resolve().parents[1]
src=repo/'fpga/component_inspector';hdl=src/'user_source/hdl_source'
fixtures=repo/'tests/ui_opt_v2';fixtures.mkdir(exist_ok=True)
assert not any(fixtures.iterdir()),'Refuse to overwrite fixtures'
base=json.loads((repo/'releases/rl7_demo_buzzer_latency_v1_20261101/SOURCE_SHA256.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in base.items():assert sha(src/n)==h,n
old=(hdl/'compact_inspector_osd.v').read_bytes();s=old.decode()
nl='\r\n' if '\r\n' in s else '\n'
def rep(a,b):
 global s
 a=a.replace('\n',nl);b=b.replace('\n',nl)
 assert s.count(a)==1,a
 s=s.replace(a,b)
rep('reg prefix;integer t;','''reg prefix;integer t;
// Four hit tests retain last-hit priority; decode the selected label once.
reg label_hit,label_prefix,label_review;reg [1:0] label_kind;
reg [8:0] label_id;reg [19:0] label_digits;
reg [10:0] label_x;reg [9:0] label_y;''')
rep(' ob=0;id=0;id_bcd=0;lx=0;rx=0;ly=0;glyph_cell=0;prefix=0;',
''' ob=0;id=0;id_bcd=0;lx=0;rx=0;ly=0;glyph_cell=0;prefix=0;
 label_hit=0;label_prefix=0;label_review=0;label_kind=0;
 label_id=0;label_digits=0;label_x=0;label_y=0;''')
rep('''     panel=1;row=y-ly;glyph_cell=(x-lx)>>3;col=(x-lx)&7;
     if(prefix && glyph_cell<4)code=glyph_cell==0 ? (frame_gap!=0 && id>=frame_gap ? "R" : "N") : "0"+((id_bcd>>((3-glyph_cell)*4))&4'hf);
     else if(prefix && glyph_cell==4)code=32;
     else code=class_char(ob[74:73],ob[74:73]==2 && ob[72:69]!=0,prefix ? glyph_cell-5 : glyph_cell);
     if(code[7])col={code[5:4],3'd0}+((x-lx)&7);
     ink=ob[74:73]==3 ? 24'hffe080 : ob[74:73]==2 && ob[72:69]==0 ? 24'h70ffdd : 24'hffb070;''',
'''     label_hit=1;label_prefix=prefix;label_kind=ob[74:73];
     label_review=ob[74:73]==2 && ob[72:69]!=0;
     label_id=id;label_digits=id_bcd;label_x=lx;label_y=ly;''')
rep('''   end
  end
 end
end
reg [10:0] ascii_address;''','''   end
   if(label_hit)begin
    panel=1;row=y-label_y;glyph_cell=(x-label_x)>>3;col=(x-label_x)&7;
    if(label_prefix && glyph_cell<4)code=glyph_cell==0 ? (frame_gap!=0 && label_id>=frame_gap ? "R" : "N") : "0"+((label_digits>>((3-glyph_cell)*4))&4'hf);
    else if(label_prefix && glyph_cell==4)code=32;
    else code=class_char(label_kind,label_review,label_prefix ? glyph_cell-5 : glyph_cell);
    if(code[7])col={code[5:4],3'd0}+((x-label_x)&7);
    ink=label_kind==3 ? 24'hffe080 : label_kind==2 && !label_review ? 24'h70ffdd : 24'hffb070;
   end
  end
 end
end
reg [10:0] ascii_address;''')
label_only=s
rep('''compact_ascii_rom ascii_font(clk,ascii_address,ascii_bits);
compact_cjk_rom cjk_font(clk,cjk_address,cjk_bits);
osd_logo_rom anlogic_logo(clk,logo_address,logo_pixel);
reg [1:0] vp,hp,dp,pp,lp,cp;''','''reg [1:0] vp,hp,dp,pp,lp,cp;
generate if(DEMO_UI)begin : shared_font
 rl7_shared_font_rom font(clk,ascii_address,cjk_address,cp[0],ascii_bits,cjk_bits);
end else begin : legacy_fonts
 compact_ascii_rom ascii_font(clk,ascii_address,ascii_bits);
 compact_cjk_rom cjk_font(clk,cjk_address,cjk_bits);
end endgenerate
osd_logo_rom anlogic_logo(clk,logo_address,logo_pixel);''')
def memory(name,size):
 data={int(a):int(b,16) for a,b in re.findall(r"memory\[(\d+)\]\s*=\s*\d+'h([0-9a-fA-F]+)",(hdl/name).read_text())}
 assert len(data)==size
 return data
a=memory('compact_ascii_rom.v',2048);c=memory('compact_cjk_rom.v',256)
# Keep ALL printable ASCII, including lower-case characters absent from the
# learning pack's smaller alphabet. Only physically blank rows are elided.
assert all(v==0 for address,v in a.items() if address//16<32 or address//16>126 or address%16 in [0,15])
assert all(v==0 for address,v in c.items() if address//32==0 or address%32>=24)
words=[0]*512
for char in range(32,127):
 for row in range(1,15):
  linear=(char-32)*14+row-1
  words[linear//4]|=a[char*16+row]<<(linear%4*8)
for glyph in range(1,8):
 for row in range(24):words[336+(glyph-1)*24+row]=c[glyph*32+row]
assert not any(words[504:]) and not any(words[333:336])
font='''// Original Demo V1 glyphs: all95 printable ASCII and seven Chinese glyphs.
// ASCII rows0/15 and CJK rows24..31 are exactly zero in the original tables.
// All original input addresses retain their original glyph-row value.
module rl7_shared_font_rom(input wire clk,input wire [10:0] ascii_address,
 input wire [7:0] cjk_address,input wire cjk_mode,
 output wire [7:0] ascii_bits,output wire [23:0] cjk_bits);
reg [31:0] memory[0:511];reg [31:0] q;reg [1:0] lane,lane_next;
reg [6:0] character;reg [10:0] linear;reg [4:0] glyph3;
reg [8:0] read_address;
always @*begin
 character=0;linear=0;lane_next=0;read_address=511;
 glyph3={1'b0,cjk_address[7:5],1'b0}+{2'b0,cjk_address[7:5]};
 if(ascii_address[10:4]>=32 && ascii_address[10:4]<=126 &&
    ascii_address[3:0]>=1 && ascii_address[3:0]<=14)begin
  character=ascii_address[10:4]-32;
  linear=({4'd0,character}<<3)+({4'd0,character}<<2)+({4'd0,character}<<1)+{7'd0,ascii_address[3:0]}-11'd1;
  read_address=linear[10:2];lane_next=linear[1:0];
 end
 if(cjk_mode)begin
  lane_next=0;read_address=511;
  if(cjk_address[7:5]!=0 && cjk_address[4:0]<24)
   read_address=9'd312+{1'b0,glyph3,3'b000}+{4'd0,cjk_address[4:0]};
 end
end
initial begin
'''+''.join(f" memory[{i}]=32'h{v:08x};\n" for i,v in enumerate(words))+'''end
always @(posedge clk)begin q<=memory[read_address];lane<=lane_next;end
assign ascii_bits=q[lane*8+:8];assign cjk_bits=q[23:0];
endmodule
'''
al=src/'td_project/camera_to_dsi_display.al';atext=al.read_bytes().decode()
anl='\r\n' if '\r\n' in atext else '\n'
needle=next(x for x in atext.splitlines() if 'Path="../user_source/hdl_source/compact_cjk_rom.v"' in x)
assert atext.count(needle)==1
atext=atext.replace(needle,needle+anl+needle.replace('compact_cjk_rom.v','rl7_shared_font_rom.v'))
(fixtures/'compact_inspector_osd_v1_ref.v').write_bytes(old.replace(b'module compact_inspector_osd #',b'module compact_inspector_osd_v1_ref #',1))
(fixtures/'compact_inspector_osd_label_only.v').write_bytes(label_only.replace('module compact_inspector_osd #','module compact_inspector_osd_label_only #',1).encode())
(hdl/'compact_inspector_osd.v').write_bytes(s.encode());(hdl/'rl7_shared_font_rom.v').write_bytes(font.encode());al.write_bytes(atext.encode())
proof={'base_commit':'137c159f9efe77d163d90752f0cb1dd3d2b124a9','baseline_source_files':637,
 'changed_existing':['td_project/camera_to_dsi_display.al','user_source/hdl_source/compact_inspector_osd.v'],
 'new_files':['user_source/hdl_source/rl7_shared_font_rom.v'],
 'glyph_sources':{n:sha(hdl/n) for n in ['compact_ascii_rom.v','compact_cjk_rom.v']},
 'ascii_characters':95,'ascii_stored_rows_per_char':14,'ascii_words':333,
 'cjk_glyphs':7,'cjk_stored_rows_per_glyph':24,'cjk_words':168,'cjk_base':336,
 'total_rom_words':512,'zero_fallback_word':511,'old_v1_osd_sha256':hashlib.sha256(old).hexdigest(),
 'class_counter_motor_buzzer_latency_camera_adc_sdc_unchanged':True}
for n,h in base.items():
 if n not in proof['changed_existing']:assert sha(src/n)==h,n
(repo/'docs/RL7_UIOPT_V2_SCOPE.json').write_text(json.dumps(proof,indent=2)+'\n')
print('Applied two display-only transforms; other635 source files byte-identical; full ASCII/CJK retained')
