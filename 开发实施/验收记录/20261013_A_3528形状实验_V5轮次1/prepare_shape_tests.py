from pathlib import Path
root=Path('fpga/component_inspector');p=root/'user_source/hdl_source/isp/isp_top.v';s=p.read_text(encoding='utf-8');s=s.replace('((!calibration_ok || !legacy_valid || !shape_valid)', '((raw_start || sample_cancel || !calibration_ok || !legacy_valid || !shape_valid)');p.write_text(s,encoding='utf-8')
p=root/'sim/tb_direct_isp.v';s=p.read_text(encoding='utf-8');s=s.replace('tb_direct_isp','tb_shape_isp').replace('#(.DIRECT_DETECTION(1))','#(.DIRECT_DETECTION(1),.SHAPE_MODEL(1))')
s=s.replace('integer xx,yy;', '''integer xx,yy,ref_fg,ref_x0,ref_y0,ref_x1,ref_y1,ref_w,ref_h;
function integer stimulus(input integer pattern,px,py);
 integer dx,dy;begin
 dx=px-512;dy=py-300;stimulus=30;
 case(pattern)
  0:if(px>=478 && px<546 && py>=273 && py<327)stimulus=180;
  1:if(dx*dx+dy*dy<=100)stimulus=150;
  2:if(dx*dx+dy*dy<=256)stimulus=150;
  3:stimulus=240;
  4:stimulus=30;
 endcase
 end
endfunction''')
s=s.replace('beat=0;reference_count=0;', 'ref_fg=0;ref_x0=999;ref_y0=999;ref_x1=-1;ref_y1=-1;beat=0;reference_count=0;')
s=s.replace('reference_sum=reference_sum+gray;', '''if(gray>=100)begin
     ref_fg++;if(xx+k<ref_x0)ref_x0=xx+k;if(xx+k>ref_x1)ref_x1=xx+k;if(yy<ref_y0)ref_y0=yy;if(yy>ref_y1)ref_y1=yy;
    end
    reference_sum=reference_sum+gray;''')
a=s.index('   raw={4{10\'(');b=s.index('rv=1;ready=',a)
s=s[:a]+"   for(integer lane_raw=0;lane_raw<4;lane_raw++) raw[39-lane_raw*10-:10]=10'(4*stimulus(level,b*4+lane_raw,row));"+s[b:]
s=s.replace('task expect_good;begin','task expect_good(input integer truth);begin')
a=s.index('expected_gray_state=');b=s.index('if(display_record',a)
s=s[:a]+'''ref_w=ref_fg==0 ? 0 : ref_x1-ref_x0+1;ref_h=ref_fg==0 ? 0 : ref_y1-ref_y0+1;
if(!dut.shape_valid || dut.shape_foreground!=ref_fg || dut.shape_width!=ref_w || dut.shape_height!=ref_h)
 $fatal(1,"native shape metrics mismatch FG=%0d/%0d W=%0d/%0d H=%0d/%0d",dut.shape_foreground,ref_fg,dut.shape_width,ref_w,dut.shape_height,ref_h);
if(dut.scene_ok!==expected_scene || class_state!==truth) $fatal(1,"native model classification truth=%0d actual=%0d FG=%0d W=%0d H=%0d scene=%b",truth,class_state,ref_fg,ref_w,ref_h,expected_scene);
'''+s[b:]
a=s.index('if(observation_record!==');b=s.index(' $display("OBS actual Sobel',a)
s=s[:a]+'''if(observation_record!=={wb_request,2'b0,13'(ref_fg),7'(ref_w),7'(ref_h),8'd100,request,display_record}) $fatal(1,"shape atomic feature/tag publication");
'''+s[b:]
a=s.index('initial begin\n ticks(16)');s=s[:a]+'''initial begin
 ticks(16);rst=1;ticks(16);
 frame(0,3); // Demosaic learning frame.
 for(integer m=0;m<4;m++)begin
  request=request+4;request[1:0]=m;
  frame(0,0);expect_good(2);
  frame(0,1);expect_good(3);
  frame(0,2);expect_good(0);
  frame(0,3);expect_good(0);
  frame(0,4);expect_good(1);
 end
 frame(1,0);if(sv || observation_record[24])$fatal(1,"short frame accepted");
 frame(0,0);expect_good(2);
 frame(3,0);if(sv || observation_record[24])$fatal(1,"mode change accepted");
 frame(0,0);expect_good(2);
 frame(4,0);if(sv || observation_record[24] || output_beat!=153600 || packed_beats!=115200)$fatal(1,"WB cancellation damaged video");
 frame(0,0);expect_good(2);
 $display("PASS shape ISP: native RAW10/vendor RAM, 4 views x 5 truths, independent native FG/bbox and Sobel pixels, atomic snapshot, short/mode/WB cancellation/recovery");$finish;
end
initial begin #140000000;$fatal(1,"shape ISP watchdog");end
endmodule
''';(root/'sim/tb_shape_isp.v').write_text(s,encoding='utf-8')
# video clone: no result classification assertion is made by original writer/reader test
s=(root/'sim/tb_direct_video.v').read_text(encoding='utf-8').replace('tb_direct_video','tb_shape_video').replace('PASS direct video:','PASS shape video:').replace('.DIRECT_DETECTION(1)', '.DIRECT_DETECTION(1),.SHAPE_MODEL(1)');(root/'sim/tb_shape_video.v').write_text(s,encoding='utf-8')
# Shape OSD full-raster test adapted for new semantic labels; all geometry/sync retained.
s=(root/'sim/tb_direct_osd.v').read_text(encoding='utf-8').replace('tb_direct_osd','tb_shape_osd').replace('.DIRECT_DETECTION(1)', '.DIRECT_DETECTION(1),.SHAPE_MODEL(1)').replace('FIXED EXP V4 ','SHAPE EXP V5 ').replace('D5 PFB W1C200','D6 PFB W1C200')
s=s.replace('reg checking=0,gray_row;', 'reg checking=0,gray_row;reg [71:0] status_text;')
s=s.replace('if(px<512 || (!gray_row && expected_mode<2)) begin','if(px<512 || !gray_row || (gray_row && gstate<2 && valid_expected)) begin')
s=s.replace('"GRAY " : "EDGE "','"MODEL" : "EDGE "')
s=s.replace('else begin case((px-512)/8) 0:glyph="O";1,2:glyph="F";default:glyph=" ";endcase end', '''else if(gray_row)begin status_text=gstate==0 ? "NO TARGET" : "UNCERTAIN";glyph=status_text[71-((px-512)/8)*8-:8];end
    else begin case((px-512)/8) 0:glyph="O";1:glyph=expected_mode>=2 ? "N" : "F";2:glyph=expected_mode>=2 ? " " : "F";default:glyph=" ";endcase end''')
s=s.replace('reg checking=0,','reg valid_expected;reg checking=0,').replace('expected_mode=m;gstate=', 'valid_expected=v;expected_mode=m;gstate=')
s=s.replace('raster(2,1,40,96,32768,2,3,2);','raster(2,1,40,96,32768,0,0,2);').replace('raster(3,1,120,0,0,2,2,3);','raster(3,1,120,0,0,1,1,3);').replace('raster(3,1,40,96,32768,3,3,2);','raster(3,1,40,96,32768,3,3,2);')
s=s.replace('PASS direct OSD:', 'PASS shape OSD:').replace('FIXED V4/D5','SHAPE V5/D6')
(root/'sim/tb_shape_osd.v').write_text(s,encoding='utf-8')
r=root/'sim/run_modelsim.ps1';s=r.read_text(encoding='utf-8-sig');s=s.replace('    $tests = @(\n','''    $tests = @(
        @{Name="shape_model"; Pass="PASS shape model:"; Sources=@("$hdl/roi_shape_model.v", "tb_shape_model.v")},
        @{Name="shape_isp"; Pass="PASS shape ISP:"; Sources=($ispSources + @("tb_shape_isp.v"))},
''')
for old,new in [('direct_video','shape_video'),('direct_osd','shape_osd')]:
 line=next(l for l in s.splitlines() if '@{Name="'+old+'"' in l);s=s.replace(line,line+'\n'+line.replace(old,new).replace('PASS direct ','PASS shape '))
r.write_text(s,encoding='utf-8-sig')
print('Added 4 shape test benches')
