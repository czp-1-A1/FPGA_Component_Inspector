from pathlib import Path
r=Path(__file__).resolve().parent.parent
sim=r/'fpga/component_inspector/sim'
def write(p,s):p.write_text(s,encoding='utf-8')
s=(sim/'tb_frame_metadata.v').read_text()
s=s.replace('tb_frame_metadata','tb_multi_metadata').replace('[177:0]','[517:0]').replace('META_WIDTH(178)','META_WIDTH(518)')
s=s.replace('expected_metadata={id[7:0],138\'d0,id[31:0]};',"expected_metadata={id[31:0],id[31:0],id[31:0],id[31:0],id[31:0],id[31:0],id[31:0],id[31:0],id[31:0],id[31:0],id[19:0],id[7:0],138'd0,id[31:0]};")
s=s.replace('PASS frame metadata:', 'PASS multi metadata:')
write(sim/'tb_multi_metadata.v',s)
s=(sim/'tb_isp_tracking_late.v').read_text().replace('tb_isp_tracking_late','tb_isp_multi')
s=s.replace('[177:0] meta','[517:0] meta').replace('.TRACKING(1),','.MULTI_POCKETS(1),.TRACKING(1),')
s=s.replace('c=464+shift+96*h;', 'c=392+shift+96*h;')
s=s.replace('if(present && row>=256 && row<344 && x>=472+shift && x<552+shift) v=700;', '''for(h=-2;h<=2;h=h+1) begin
      c=392+shift+96*h+48;
      if((h%2)==0 && present && row>=264 && row<336 && x>=c-36 && x<c+36) v=(x/4+row/4)%2 ? 700 : 1000;
     end''')
# Four independent references use actual AWB pixels, not synthetic source brightness.
start=s.index('integer total=')
end=s.index('task ticks',start)
s=s[:start]+'''integer total[0:3],cnt[0:3],low[0:3],high[0:3],edge_n[0:3],edge_c[0:3],edge_s[0:3];
integer luma,px,py;
always @(posedge clk) if(rst) begin
 if(dut.awb_pixel_sof) for(integer p=0;p<4;p++) begin total[p]=0;cnt[p]=0;low[p]=255;high[p]=0;edge_n[p]=0;edge_c[p]=0;edge_s[p]=0;end
 if(dut.roi_accept) for(integer p=0;p<4;p++) for(integer k=0;k<4;k++) begin
  px=dut.pocket_x0[p*11+:11];py=dut.pocket_y0[p*10+:10];
  if(dut.pocket_mask[p] && dut.roi_x+k>=px && dut.roi_x+k<px+80 && dut.roi_y>=py && dut.roi_y<py+80) begin
   luma=(int'(dut.awb_O_tdata[95-k*24-:8])+2*int'(dut.awb_O_tdata[87-k*24-:8])+int'(dut.awb_O_tdata[79-k*24-:8]))/4;
   total[p]+=luma;cnt[p]++;if(luma<low[p]) low[p]=luma;if(luma>high[p]) high[p]=luma;
  end
 end
 if(dut.gradient_valid) for(integer p=0;p<4;p++) for(integer k=0;k<4;k++) begin
  px=dut.pocket_x0[p*11+:11];py=dut.pocket_y0[p*10+:10];
  if(dut.pocket_mask[p] && dut.gradient_neighborhood[k] && dut.gradient_x+k>=px && dut.gradient_x+k<px+80 && dut.gradient_y>=py && dut.gradient_y<py+80) begin
   edge_n[p]++;edge_s[p]+=dut.gradient_magnitudes[k*11+:11];if(dut.gradient_magnitudes[k*11+:11]>=80) edge_c[p]++;
  end
 end
end
''' +s[end:]
s=s.replace('if(!mready || !good || bad || !sv)','if(!mready || !good || bad)')
start=s.index('  if(cnt!=6400')
end=s.index('  end\n end\nendtask',start)
s=s[:start]+'''  for(integer p=0;p<4;p++) begin
   if(meta[178+p*85+63]!==expected_lock) $fatal(1,"actual ISP pocket validity frame=%0d bank=%0d got=%b diag=%h",frame_no,p,meta[178+p*85+63],meta[177:170]);
   if(expected_lock) begin
    if(cnt[p]!=6400 || meta[178+p*85+53+:8]!=total[p]/6400 || meta[178+p*85+45+:8]!=low[p] || meta[178+p*85+37+:8]!=high[p]) $fatal(1,"actual ISP independent bank features");
    if(mode>=2 && (edge_n[p]!=6400 || meta[178+p*85+24+:13]!=edge_c[p] || meta[178+p*85+:24]!=edge_s[p])) $fatal(1,"actual ISP edge bank features");
    if(mode<2 && meta[178+p*85+61+:2]!=(total[p]>=6400*58 ? 2 : 3)) $fatal(1,"actual ISP bank class");
   end else if(meta[178+p*85+61+:2]!=1) $fatal(1,"invalid actual ISP bank retained classification");
  end
  if(meta[178+:340]!==dut.pocket_records) $fatal(1,"multi metadata mixed epoch");
  $display("OBS actual multi frame=%0d mode=%0d move=%0d lock=%0d mask=%b verified=%b first_mean=%0d",frame_no,mode,move,expected_lock,dut.pocket_mask,dut.pocket_verified,mean);
''' +s[end:]
s=s.replace('PASS actual ISP tracking late:','PASS actual ISP multi:')
write(sim/'tb_isp_multi.v',s)
ps=sim/'run_modelsim.ps1';s=ps.read_text(encoding='utf-8-sig')
s=s.replace('"$hdl/tape_hole_tracker.v", "$hdl/roi_frame_guard.v"','"$hdl/tape_hole_tracker.v", "$hdl/multi_pocket_detector.v", "$hdl/roi_frame_guard.v"')
s=s.replace('    $tests = @(\n','''    $tests = @(
        @{Name="multi_pockets"; Pass="PASS multi pockets:"; Sources=@("$hdl/multi_pocket_detector.v", "$hdl/roi_sobel_view.v", "tb_multi_pockets.v")},
        @{Name="isp_multi"; Pass="PASS actual ISP multi:"; Sources=($ispSources + @("tb_isp_multi.v"))},
        @{Name="multi_osd"; Pass="PASS multi OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/experiment_osd.v", "tb_multi_osd.v")},
        @{Name="multi_metadata"; Pass="PASS multi metadata:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_multi_metadata.v")},
''')
s=s.replace('"isp_tracking_late")) {','"isp_tracking_late", "isp_multi")) {')
write(ps,s)
print('Prepared unit, actual ISP, wide metadata tests and runner')
