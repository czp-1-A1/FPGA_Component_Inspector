from pathlib import Path
root=Path(__file__).resolve().parent.parent;sim=root/'fpga/component_inspector/sim'
read=lambda p:p.read_text(encoding='utf-8-sig')
for name in ['tb_isp_multi.v','tb_multi_writer.v','tb_multi_video.v']:
 p=sim/name;s=read(p)
 s=s.replace('row>=364 && row<397','row>=264 && row<297')
 s=s.replace('392+shift+96*h','456+shift+96*h')
 s=s.replace('if(x>=c-16 && x<c+16) v=800;', 'if((x-c)*(x-c)+(row-280)*(row-280)<=256) v=800;')
 s=s.replace('456+shift+96*h+48','456+shift+96*h-32')
 s=s.replace('row>=264 && row<336','row>=324 && row<396')
 s=s.replace('meta[114:0]!==obs', "meta[114:0]!=={dut.wb_frame_request,obs[82:46],dut.observation_tag,obs[27:0]}")
 s=s.replace('current-frame lower-hole verification','current-frame upper-hole verification')
 p.write_text(s,encoding='utf-8')
p=sim/'tb_multi_pockets.v';s=read(p)
s=s.replace('cy=380','cy=280').replace('cc=200+move','cc=264+move').replace('px=cc+8','px=cc-72')
s=s.replace('yy>=cy-116 && yy<cy-44','yy>=cy+44 && yy<cy+116')
s=s.replace('#(.X0(96),.X1(928)) sobel','#(.X0(96),.X1(928),.Y1(464)) sobel')
s=s.replace(',380,',',280,').replace(',396,',',296,').replace(',364,',',264,')
p.write_text(s,encoding='utf-8')
p=sim/'tb_multi_osd.v';p.write_text(read(p).replace('AUTO4 EXP V2','AUTO4 EXP V3'),encoding='utf-8')

# Keep the original failing assertion and add positive acquisition requirements.
s=read(root/'tmp/multi_geometry_repro_r1_20261013/sim/tb_geometry_polarity.v')
s=s.replace('integer wrong=0;', 'integer wrong=0,valid_parts=0;')
s=s.replace('if(wrong) $fatal', '''if(records[63]) valid_parts++;
 if(records[148]) valid_parts++;
 if(records[233]) valid_parts++;
 if(records[318]) valid_parts++;
 if(valid_parts<2) $fatal(1,"upper-hole geometry failed to acquire real lower pockets");
 if(wrong) $fatal''')
(sim/'tb_geometry_polarity.v').write_text(s,encoding='utf-8')

# Cold-start first pocket has a white reference strip, so it is invalid; other
# pockets still provide their own valid results and current frame tags.
s=read(sim/'tb_isp_multi.v').replace('module tb_isp_multi;','module tb_multi_first_invalid;')
s=s.replace('     raw[39-l*10-:10]=v;', '     if(row>=320 && row<400 && x>=176 && x<192) v=800;\n     raw[39-l*10-:10]=v;')
s=s.replace('meta[178+p*85+63]!==expected_lock','meta[178+p*85+63]!==((p==0) ? 0 : expected_lock)')
s=s.replace('  if(meta[178+:340]!==dut.pocket_records)', '  if(expected_lock && meta[114:83]!==dut.wb_frame_request) $fatal(1,"first invalid pocket hid valid banks behind PARAM CHANGED");\n  if(meta[178+:340]!==dut.pocket_records)')
start=s.index('initial begin\n ticks(8)');end=s.index('initial begin #100000000',start)
s=s[:start]+'''initial begin
 ticks(8);rst=1;ticks(20);
 frame(0,1,1,0,1);frame(0,1,1,0,1);frame(0,1,1,1,1);
 if(meta[241] || !meta[326] || !meta[411] || !meta[496]) $fatal(1,"first-pocket invalidity was not isolated");
 if(meta[114:83]!==32'h00004040 || meta[45:28]!==request) $fatal(1,"frame tags missing without first-pocket statistics");
 $display("PASS multi first invalid: cold first pocket rejected, three other pockets remain valid, coherent frame tags independent of sample history");$finish;
end
'''+s[end:]
(sim/'tb_multi_first_invalid.v').write_text(s,encoding='utf-8')

# Upper-band rectangles imitate a pitched row, but constant-width vertical
# profiles are not valid circular-hole chords.
s=read(sim/'tb_geometry_polarity.v').replace('module tb_geometry_polarity;','module tb_rectangular_anchors;')
s=s.replace('if((xx-c)*(xx-c)+(yy-300)*(yy-300)<=24*24) value=200;', 'if(xx>=c-24 && xx<c+24 && yy>=272 && yy<320) value=200;')
start=s.index('integer wrong=0');end=s.index('initial begin #10000000',start)
s=s[:start]+'''initial begin
 ticks(8);rst=1;frame();frame();
 if(verified || records[63] || records[148] || records[233] || records[318])
  $fatal(1,"pitched bright rectangles acquired as sprocket holes");
 $display("PASS rectangular anchors: pitched upper-band rectangular bright bodies never acquire hole-derived classifications");$finish;
end
'''+s[end:]
(sim/'tb_rectangular_anchors.v').write_text(s,encoding='utf-8')

p=sim/'run_modelsim.ps1';s=read(p)
entries='''
        @{Name="geometry_polarity"; Pass="PASS geometry polarity:"; Sources=@("$hdl/multi_pocket_detector.v", "tb_geometry_polarity.v")},
        @{Name="rectangular_anchors"; Pass="PASS rectangular anchors:"; Sources=@("$hdl/multi_pocket_detector.v", "tb_rectangular_anchors.v")},
        @{Name="multi_first_invalid"; Pass="PASS multi first invalid:"; Sources=($ispSources + @("tb_multi_first_invalid.v"))},'''
assert 'Name="geometry_polarity"' not in s
s=s.replace('    $tests = @(', '    $tests = @('+entries,1)
s=s.replace('"isp_multi", "multi_writer", "multi_video"','"isp_multi", "multi_writer", "multi_video", "multi_first_invalid"')
p.write_text(s,encoding='utf-8-sig')
print('Prepared upper-hole geometry, circle/rectangle counterexamples, full ISP writer and first-invalid metadata fixtures')
