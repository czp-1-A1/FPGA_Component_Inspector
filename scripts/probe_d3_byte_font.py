"""Isolate an exact byte-wide font ERAM; no production files are edited.

The original 95 ASCII glyphs keep all 16 rows, and the seven Chinese glyphs
keep 24 rows of three bytes. 1520+504=2024 bytes fit one physical ERAM, with
simple address additions instead of bit-level glyph multiplication.
"""
from pathlib import Path
import argparse, hashlib, json, re, shutil

a=argparse.ArgumentParser()
a.add_argument('--base',type=Path,required=True)
a.add_argument('--out',type=Path,required=True)
x=a.parse_args()
assert not x.out.exists()
shutil.copytree(x.base,x.out/'project')
hdl=x.out/'project/user_source/hdl_source'
table=lambda n:{int(i):int(v,16) for i,v in re.findall(r"memory\[(\d+)\]=\d+'h([0-9a-fA-F]+)",(hdl/(n+'.v')).read_text())}
ascii=table('compact_ascii_rom');cjk=table('compact_cjk_rom')
assert len(ascii)==2048 and len(cjk)==256
assert all(not v or 32<=i//16<=126 for i,v in ascii.items())
assert all(not v or 1<=i//32<=7 and i%32<24 for i,v in cjk.items())
values=[0]*2048
for ac in range(32,127):
 for row in range(16):values[(ac-32)*16+row]=ascii[ac*16+row]
for cc in range(1,8):
 for row in range(24):
  for colbyte in range(3):values[1520+(cc-1)*72+row*3+colbyte]=(cjk[cc*32+row]>>(16-colbyte*8))&255
p=hdl/'compact_inspector_osd.v';before=hashlib.sha256(p.read_bytes()).hexdigest()
s=p.read_text();s=s[:s.index('module compact_shared_font_rom(')]
s+='''module compact_shared_font_rom(
 input wire clk,cjk,input wire [10:0] ascii_address,input wire [7:0] cjk_address,
 input wire [4:0] column,output wire pixel);
 wire [6:0] ac=ascii_address[10:4];wire [3:0] ar=ascii_address[3:0];
 wire [2:0] cc=cjk_address[7:5];wire [4:0] cr=cjk_address[4:0];
 wire av=ac>=32 && ac<=126 && column<8;
 wire cv=cc>=1 && cr<24 && column<24;
 wire [6:0] ascii_index=ac-7'd32;
 wire [2:0] chinese_index=cc-3'd1;
 wire [10:0] ai={ascii_index,ar};
 wire [10:0] char_offset={2'd0,chinese_index,6'd0}+{5'd0,chinese_index,3'd0};
 wire [10:0] row_offset={5'd0,cr,1'b0}+{6'd0,cr};
 wire [10:0] ci=11'd1520+char_offset+row_offset+{9'd0,column[4:3]};
 wire [13:0] address={cjk ? ci : ai,3'b000};
 wire [15:0] raw;reg valid_q;reg [2:0] column_q;
 always @(posedge clk)begin valid_q<=cjk ? cv : av;column_q<=column[2:0];end
 assign pixel=valid_q && raw[7-column_q];
 PH1P_PHY_ERAM_V2 #(
  .DATA_WIDTH_A("10"),.DATA_WIDTH_B("10"),.MODE("DP20K"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.GSR("DISABLE"),
  .CSA0("1"),.CSA1("1"),.CSA2("1"),.CSB0("0"),.CSB1("0"),.CSB2("0"),
'''
s+=',\n'.join("  .INIT_%02X(256'h%064x)"%(block,sum(values[block*32+byte]<<(byte*8) for byte in range(32))) for block in range(64))
s+='''
 ) font_bits(
  .dia(16'd0),.dia_extra(4'd0),.csa(3'b111),.addra(address),.ocea(1'b1),.clka(clk),.wea(1'b0),.orsta(1'b0),
  .dib(16'd0),.dib_extra(4'd0),.csb(3'b000),.addrb(14'd0),.oceb(1'b0),.clkb(clk),.web(1'b0),.orstb(1'b0),
  .doa(raw),.doa_extra(),.dob(),.dob_extra(),.ecc_sbiterr(),.ecc_dbiterr(),.ecc_sbiterrinj(1'b0),.ecc_dbiterrinj(1'b0),
  .fifoctrl_waddr(14'd0),.fifoctrl_raddr(14'd0),.fifoctrl_we(1'b0),.fifoctrl_re(1'b0),
  .addra_casin(14'd0),.addrb_casin(14'd0),.addra_casout(),.addrb_casout(),.pib_rst_redmeet_n(1'b1),.probe_redmeet_pa(),.probe_redmeet_pb());
endmodule
'''
p.write_bytes(s.encode())
(x.out/'PROVENANCE.json').write_text(json.dumps({'base':str(x.base),'production_modified':False,'source_before':before,'source_after':hashlib.sha256(p.read_bytes()).hexdigest(),'stored_bytes':2024,'ram_depth_bytes':2048,'address':'ASCII full16 rows; CJK full24 rows times3bytes; zero padding proved exact','scope':'All glyphs and one-clock font latency retained; physical vendor-model equivalence and actual synthesis required.'},indent=2)+'\n')
print(x.out)
