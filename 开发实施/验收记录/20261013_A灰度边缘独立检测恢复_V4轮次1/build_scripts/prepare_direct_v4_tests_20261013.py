from pathlib import Path
root=Path(__file__).resolve().parent.parent
sim=root/'fpga/component_inspector/sim'
read=lambda p:p.read_text(encoding='utf-8-sig')
source=read(sim/'tb_roi_chain.v')
source=source.replace('tb_roi_chain','tb_direct_isp').replace('isp_top dut(','isp_top #(.DIRECT_DETECTION(1)) dut(')
source=source.replace(".threshold(8'd110)",".threshold(8'd58)")
source=source.replace('raw={4{10\'((level+((b>=130) ? 50 : 0)+((row>=300) ? 30 : 0))*4)}};',
 'raw={4{10\'((level==180 || level==10 ? level : level+((b>=130) ? 50 : 0)+((row>=300) ? 30 : 0))*4)}};')
source=source.replace('reference_sum/6400>=110','reference_sum/6400>=58')
source=source.replace("expected_class_state=!expected_scene ? 2'd1 : !frame_mode[1] ? expected_gray_state : frame_mode[0] && expected_gray_state!=expected_edge_state ? 2'd1 : expected_edge_state;",
 "expected_class_state=frame_mode==2 ? expected_edge_state : expected_gray_state;")
start=source.index('initial begin\n ticks(16);rst=1;ticks(16);')
source=source[:start]+'''initial begin
 ticks(16);rst=1;ticks(16);
 frame(0,180); // Original demosaic line-span learning; no locator holes.
 request=18'd5;frame(0,180);expect_good;
 if(expected_scene || expected_gray_state!=2) $fatal(1,"bright control must bypass the old dark-strip gate");
 request=18'd10;frame(0,180);expect_good;
 if(expected_edge_state!=3 || class_state!=3) $fatal(1,"flat bright EDGE must be EMPTY independently of MEAN");
 request=18'd15;frame(0,180);expect_good;
 if(expected_gray_state!=2 || expected_edge_state!=3 || class_state!=2) $fatal(1,"combined view incorrectly fused conflicting tests");
 request=18'd16;frame(0,10);expect_good;
 if(class_state!=3) $fatal(1,"dark RAW control must be EMPTY");
 request=18'd21;frame(0,10);expect_good;
 request=18'd26;frame(0,0);expect_good;
 if(expected_gray_state!=3 || expected_edge_state!=2 || class_state!=2) $fatal(1,"low-MEAN strong-edge control not independent");
 request=18'd31;frame(0,0);expect_good;
 if(expected_gray_state!=3 || expected_edge_state!=2 || class_state!=3) $fatal(1,"combined view must keep brightness and display the separate edge result");
 frame(1,80);if(commits!=0 || sv || class_state!==1 || display_record[24]) $fatal(1,"short native row accepted");
 request=18'd37;frame(0,180);expect_good;
 request=18'd40;frame(3,180);
 if(sv || display_record[24] || observation_record[24]) $fatal(1,"mid-frame mode request accepted");
 frame(0,180);expect_good;
 request=18'd46;frame(4,0);
 if(sv || display_record[24] || observation_record[24] || dut.video_frame_bad || output_beat!=153600 || packed_beats!=115200)
  $fatal(1,"WB change retained old sample or interrupted full video");
 if(dut.wb_active!==32'h00004040)$fatal(1,"WB changed within native frame");
 frame(0,0);expect_good;
 if(dut.wb_active!==wb_request)$fatal(1,"WB request not applied on complete frame");
 $display("PASS direct ISP: actual RAW10/vendor RAM/Sobel/full 600 rows, independent pixel references, no hole or dark-strip prerequisite, both conflict directions, four views, short rejection, mode/WB cancellation and recovery");$finish;
end
initial begin #70000000;$fatal(1,"direct ISP watchdog");end
endmodule
'''
assert ".DIRECT_DETECTION(1)" in source and '>=110' not in source
(sim/'tb_direct_isp.v').write_text(source,encoding='utf-8')
# Test production's fixed-video metadata-disabled route with the original reader.
source=read(sim/'tb_multi_video.v').replace('tb_multi_video','tb_direct_video')
source=source.replace('[517:0]','[177:0]').replace('.META_WIDTH(518)','.META_WIDTH(178)')
source=source.replace('.METADATA(1)','.METADATA(0)')
source=source.replace('isp_top #(.MULTI_POCKETS(1),.TRACKING(1),.HOLE_Y(380),.LATE_HOLE(1))',
 'isp_top #(.DIRECT_DETECTION(1),.TRACKING(0),.MULTI_POCKETS(0))')
source=source.replace('for(integer p=0;p<4;p++)','for(integer p=0;p<1;p++)')
source=source.replace('px=dut.pocket_x0[p*11+:11];py=dut.pocket_y0[p*10+:10];','px=472;py=260;')
source=source.replace('dut.pocket_mask[p] && ','')
start=source.index('  if(!cap || !writer.published || writer.writer_epoch!=frame_no')
end=source.index('\n  end\n end\nendtask',start)
source=source[:start]+'''  if(!cap || !writer.published || writer.writer_epoch!=frame_no || completed_meta!==178'd0)
   $fatal(1,"fixed direct video did not publish a full frame without metadata");
  if(!good || bad || !sv || !obs[24] || obs[114:83]!==32'h00006464 || obs[45:28]!==request)
   $fatal(1,"direct frame observation incomplete or wrong epoch");
  if(cnt[0]!=6400 || obs[23:16]!=total[0]/6400 || obs[15:8]!=low[0] || obs[7:0]!=high[0])
   $fatal(1,"direct frame independent luma reference");
  if(mode>=2 && (edge_n[0]!=6400 || obs[58:46]!=edge_c[0] || obs[82:59]!=edge_s[0]))
   $fatal(1,"direct frame independent edge reference");
  if(obs[26:25]!=(mode==2 ? (edge_c[0]>=96 && edge_s[0]>=32768 ? 2 : edge_c[0]<=48 && edge_s[0]<=16384 ? 3 : 1) : (total[0]/6400>=58 ? 2 : 3)))
   $fatal(1,"direct video mode selection");
  $display("OBS direct video frame=%0d view=%0d mean=%0d EC=%0d GS=%0d class=%0d",frame_no,mode,mean,edge_c[0],edge_s[0],obs[26:25]);
'''+source[end:]
source=source.replace('holes=have_holes','holes=0')
source=source.replace('if((h%2)==0 && present && row>=324 && row<396 && x>=c-36 && x<c+36)',
 'if(present && row>=264 && row<336 && x>=476 && x<548)')
source=source.replace('PASS multi video:', 'PASS direct video:').replace('518-bit metadata','fixed sample metadata-disabled writer')
(sim/'tb_direct_video.v').write_text(source,encoding='utf-8')
# Register only new test names; compatibility tests keep their old defaults.
runner=read(sim/'run_modelsim.ps1')
entries='''        @{Name="direct_modes"; Pass="PASS direct modes:"; Sources=@("$hdl/roi_mode_classifier.v", "tb_direct_modes.v")},
        @{Name="direct_isp"; Pass="PASS direct ISP:"; Sources=($ispSources + @("tb_direct_isp.v"))},
        @{Name="direct_video"; Pass="PASS direct video:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_direct_video.v"))},
        @{Name="direct_osd"; Pass="PASS direct OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/experiment_osd.v", "tb_direct_osd.v")},
'''
assert 'Name="direct_isp"' not in runner
runner=runner.replace('    $tests = @(\n','    $tests = @(\n'+entries,1)
runner=runner.replace('"multi_first_invalid"))','"multi_first_invalid", "direct_isp", "direct_video"))')
(sim/'run_modelsim.ps1').write_text(runner,encoding='utf-8-sig')
print('Prepared isolated direct ISP/video fixture references and runner entries')
