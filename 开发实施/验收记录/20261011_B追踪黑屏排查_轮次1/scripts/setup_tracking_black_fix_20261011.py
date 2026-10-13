from pathlib import Path
import shutil, json, hashlib
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
src=root/'tmp/tracking_black_repro_r1_td_20261011/sim/tb_isp_writer_stop.v'
s=src.read_text(encoding='utf-8').replace('tb_isp_writer_stop','tb_isp_metadata_stop')
s=s.replace('integer native_tail=200,','integer native_tail=20,')
s=s.replace('.calibration_ok(1\'b0)', '.calibration_ok(1\'b1)')
s=s.replace('integer cycle=0,', 'integer early_metadata_frames=0; reg saw_early_metadata=0;\ninteger cycle=0,')
s=s.replace('  if(dut.awb_O_tuser)early_cycle=cycle;', '''  if(dut.awb_O_tuser)early_cycle=cycle;
  if(metadata_ready && !good && !bad && !saw_early_metadata) begin
   saw_early_metadata=1; early_metadata_frames=early_metadata_frames+1;
  end
  if(sv && !good) $fatal(1,"provisional ROI escaped complete-frame proof");
  if(vi.published && !good && !bad && !dut.u_roi_guard.reported)
   $fatal(1,"provisional metadata published unfinished pixels");''')
s=s.replace('  frame_no=frame_no+1;', '  saw_early_metadata=0; frame_no=frame_no+1;')
s=s.replace('if(nrows==600) begin fe=1;', 'if(nrows>=599) begin fe=1;')
s=s.replace('  if(nrows==600 && (packed_count', '''  if(nrows>=599 && !saw_early_metadata) $fatal(1,"features not finalized before FE");
  if(nrows==600 && (!metadata_ready || vi.metadata_receive[177:0]!==metadata))
   $fatal(1,"complete frame published mismatched metadata");
  if(nrows==599 && (good || capture_ok || sv || vi.published || !bad || metadata_ready))
   $fatal(1,"short final row/frame accepted early ROI metadata");
  if(nrows==600 && (packed_count''')
start=s.index(' prefix(4,selected_mode,0);',s.index('initial begin\n csv='))
end=s.index(' $fclose(csv);$finish;',start)
s=s[:start]+''' // ROI and hole rows are present, but the last image row is missing.
 prefix(599,selected_mode,-1);
 if(early_metadata_frames!=2) $fatal(1,"did not exercise pre-FE metadata in both full and bad frames");
 $display("PASS actual ISP metadata stop: real RAW10/ISP/178bit mailbox/writer, short20-cycle tail, full word/epoch proof, precomputed features never publish truncated frame");
'''+s[end:]
(project/'sim/tb_isp_metadata_stop.v').write_text(s,encoding='utf-8')
runner=project/'sim/run_modelsim.ps1'; r=runner.read_text(encoding='utf-8')
needle='        @{Name="isp_writer_stop";'
test='''        @{Name="isp_metadata_stop"; Pass="PASS actual ISP metadata stop:"; Sources=($ispSources + @("$hdl/observation_controls.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_isp_metadata_stop.v"))},
'''
assert 'Name="isp_metadata_stop"' not in r
r=r.replace(needle,test+needle).replace('"isp_writer_stop", "isp_tracking"','"isp_writer_stop", "isp_metadata_stop", "isp_tracking"')
runner.write_text(r,encoding='utf-8')
build=root/'tmp/tracking_black_fix_r1_td_20261011'; assert not build.exists()
prior=root/'tmp/tracking_late_r1_td_20261011'
inputs=json.loads((prior/'inputs.json').read_text(encoding='utf-8'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for e in inputs:
 src=project/e['path'];dst=build/e['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 e.update(sha256=sha(dst),bytes=dst.stat().st_size)
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:shutil.copy2(prior/rel/name,dst/name)
sim=build/'sim';sim.mkdir()
for p in (project/'sim').iterdir():
 if p.is_file() and p.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(p,sim/p.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
for name,data in [('inputs.json',inputs),('simulation_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for p in sim.rglob('*') if p.is_file()]),('stage_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for stage in ['syn_1','phy_1'] for p in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir() if p.is_file()])]:
 (build/name).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
p=root/'AGENTS.md'; a=p.read_text(encoding='utf-8'); a=a.replace('尚未证实。','已仿真复现：尾部20拍停CSI时完整115200字/帧证明均通过，但metadata仍pending/wait44，整帧不能发布；尾部200拍可通过。现场尾部时长未测。')
a=a.replace('尚未运行本轮测试；','复现19029退出0（长尾200）；短尾20361预期失败，许可环境初次失败退出4保留；')
a=a.replace('当前生产仍下方v1的210输入，未修改RTL。','当前仅isp_top.v修改：TRACKING时在ROI/孔扫描完成后的行提前完成特征，外部sample/class仍由完整帧证明控制；不改writer/DDR/帧完整性门槛。新增真实METADATA短尾/残帧回归。')
a=a.replace('运行tmp/tracking_black_repro_r1_td_20261011/sim/run_modelsim.ps1 -OnlyTests isp_writer_stop；检查metadata_ready、48拍等待、capture/epoch和原生CSI尾部停钟，再按复现修复并冻结测试构建。','在冻结tmp/tracking_black_fix_r1_td_20261011跑isp_metadata_stop及受影响ISP回归；通过后综合/布局布线及新目录发布。')
p.write_text(a,encoding='utf-8')
print(build)
