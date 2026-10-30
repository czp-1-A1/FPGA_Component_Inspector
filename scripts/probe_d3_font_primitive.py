"""Use the documented physical one-bit ERAM for the exact packed font.

Isolated experiment only. All 16,384 initialization bits are embedded as
primitive parameters; no external initialization file, omitted glyph or cycle.
"""
from pathlib import Path
import re,hashlib,json,shutil
base=Path('D:/CodexWork/D3_Math_Source_R32_20261030/project')
out=Path('D:/CodexWork/D3_Font_Primitive_Source_R33_20261030');assert not out.exists();shutil.copytree(base,out/'project')
packed=Path('E:/2026FPGA/.codex_tmp/d3_bram_font_source_r24_20261030/project/user_source/hdl_source/compact_inspector_osd.v').read_text()
values={int(i):int(v) for i,v in re.findall(r"memory\[(\d+)\]=1'b([01]);",packed)};assert len(values)==16384
main=packed[:packed.index('// Exact immutable font bits')]
font=packed[packed.index('module compact_shared_font_rom('):packed.index(' initial begin',packed.index('module compact_shared_font_rom('))]
font=font.replace('output reg pixel','output wire pixel').replace(' (* rom_style="bram" *) reg memory[0:16383];\n','')
font+=''' wire [15:0] raw;reg valid_q;
 always @(posedge clk)valid_q<=cjk ? cv : av;
 assign pixel=valid_q && raw[0];
 PH1P_PHY_ERAM_V2 #(
  .DATA_WIDTH_A("1"),.DATA_WIDTH_B("1"),.MODE("DP20K"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.GSR("DISABLE"),
  .CSA0("1"),.CSA1("1"),.CSA2("1"),.CSB0("0"),.CSB1("0"),.CSB2("0"),
'''
font+=',\n'.join("  .INIT_%02X(256'h%064x)"%(block,sum(values[block*256+bit]<<bit for bit in range(256))) for block in range(64))
font+='''
 ) font_bits(
  .dia(16'd0),.dia_extra(4'd0),.csa(3'b111),.addra(address),.ocea(1'b1),.clka(clk),.wea(1'b0),.orsta(1'b0),
  .dib(16'd0),.dib_extra(4'd0),.csb(3'b000),.addrb(14'd0),.oceb(1'b0),.clkb(clk),.web(1'b0),.orstb(1'b0),
  .doa(raw),.doa_extra(),.dob(),.dob_extra(),.ecc_sbiterr(),.ecc_dbiterr(),.ecc_sbiterrinj(1'b0),.ecc_dbiterrinj(1'b0),
  .fifoctrl_waddr(14'd0),.fifoctrl_raddr(14'd0),.fifoctrl_we(1'b0),.fifoctrl_re(1'b0),
  .addra_casin(14'd0),.addrb_casin(14'd0),.addra_casout(),.addrb_casout(),.pib_rst_redmeet_n(1'b1),.probe_redmeet_pa(),.probe_redmeet_pb());
endmodule
'''
p=out/'project/user_source/hdl_source/compact_inspector_osd.v';p.write_bytes((main+font).encode())
(out/'PROVENANCE.json').write_text(json.dumps({'base':str(base),'production_modified':False,'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'init_bits':16384,'original_packed_font_source':str(Path('E:/2026FPGA/.codex_tmp/d3_bram_font_source_r24_20261030/project/user_source/hdl_source/compact_inspector_osd.v')),'scope':'Physical PH1P one-bit ERAM; must pass original fonts/all pixels before any use.'},indent=2)+'\n')
print(out)
