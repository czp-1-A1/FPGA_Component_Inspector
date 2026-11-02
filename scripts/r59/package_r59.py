"""Package only source/Git/software/final-routed accepted R59; fresh-restore all payloads."""
from pathlib import Path
import argparse,difflib,hashlib,json,re,shutil,subprocess,zipfile
ROOT=Path('D:/FpgaWork/r59_four_view_20261102');SRC=ROOT/'fpga/component_inspector';H=Path('D:/FpgaWork/r59_field_20261102');OLD=Path('D:/FpgaWork/r58_field_20261102');DOWNLOAD=Path('D:/fpga_download')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def main():
 a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);args=a.parse_args();w=args.work
 physical=load(w/'physical_verification.json');soft=load(H/'R59_SOFTWARE_VERIFICATION.json');syn=load(w/'R59_SYNTHESIS_PROOF.json');manifest=load(w/'frozen_inputs.json');git=load(H/'R59_GIT_SOURCE_AUDIT.json')
 assert physical['status'].startswith('PASS_R59_FOUR_VIEWS_BUZZER_LATENCY_ROUTED_44_ACTIVE')
 assert physical['max_delays_matched']==44 and physical['max_delays_ignored']==0 and physical['gray_bits_dominating']==84
 instrument=physical['latency_buzzer_routed_proof'];assert instrument['time_gray_bits']==64 and instrument['first_stage_fanouts_checked']==64 and instrument['four_view_switch_stages_and_fanouts']==2
 assert syn['eram_cells']==107 and syn['rgb_background_cells']==5 and syn['full_rgb_input_bits']==96 and syn['font_init_blocks_exact']==64
 assert soft['actual_tests'] in [29,30] and soft['unbound_historical_pass_reused']==0 and soft['SDC_and_ADC_byte_exact_R58']
 timing=physical['timing_ns'];assert timing['SWNS']>=0 and timing['HWNS']>=0 and timing['STNS']==timing['HTNS']==0
 assert len(manifest)==705 and sha(w/'frozen_inputs.json')==soft['source_manifest_sha256']==syn['source_manifest_sha256']==git['source_manifest_sha256']
 assert git['status']=='PASS_R59_GIT_705_SOURCE_BLOBS_MATCH_FROZEN' and git['commit']==subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 for name,d in manifest.items():assert sha(SRC/name)==sha(w/'project'/name)==d,name
 bit=w/'runs/phy_1/camera_to_dsi_display.bit';digest=sha(bit);assert physical['bit_sha256']==digest
 prefix='R59_FourViews_Buzzer_Latency_20261102_'+digest[:8]
 build_names=['build_result.json','synthesis_result.json','PLACEMENT_RESULT.json','R59_PLACEMENT_GATE.json','baseline_delta.json','frozen_inputs.json','hardware_inputs.json','ESSENTIAL_UI_PROOF.json','R59_SYNTHESIS_PROOF.json','R59_INSTRUMENT_PHYSICAL_PROOF.json','physical_verification.json','d3_camera_gate.v','verify_relay_physical.py','classified_audit_routed.tcl','classified_audit_gray_packing.tcl','classified_audit_routed.tcl.log','classified_audit_gray_packing.tcl.log','instrument_audit.tcl','instrument_audit.log','STAGE_PLACE.json','STAGE_ROUTE.json','RUN_STATE_PLACE.json','RUN_STATE_ROUTE.json']
 selected=['R59_SOFTWARE_VERIFICATION.json','R59_UI_PIXEL_VERIFICATION.json','R59_GIT_SOURCE_AUDIT.json','R59_SELECTION.json','R59_FINAL_ROUTED_PATHS.json','verify_r59_software.py','audit_r59_physical.py','audit_r59_instruments.py','verify_d3_essential_sdc.py','export_and_check_r59_synthesis.py','run_r59_staged_physical.py','inspect_r59_placement.py','run_r59_sim.py','run_native_local.py','check_r59_ui_pixels.py','tb_r58_ui.sv','tb_r58_frame_latency_chain.sv','tb_r59_four_modes_native.sv','tb_sobel_view_r59.sv','tb_sobel_tail_r59.sv','tb_r59_latency_char_equivalence.sv','CANDIDATE_CHAR_SCOPE.json','SYNTHESIS_AREA_COMPARISON.json']
 for name in build_names:assert (w/name).is_file(),name
 for name in selected:assert (H/name).is_file(),name
 assert (H/'R59_DESIGN_AND_HANDOFF.md').is_file()
 release=H/'releases'/prefix;assert not release.exists();payload=release/'payload';payload.mkdir(parents=True)
 def copy(source,name):
  dst=payload/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dst)
 for name in manifest:copy(SRC/name,'project/'+name)
 copy(ROOT/'docs/R58_BASELINE_SHA256.json','R58_BASELINE_SHA256.json');copy(w/'frozen_inputs.json','R59_FROZEN_INPUTS.json')
 for folder in ['scripts','tests/dual_stop_d3','tests/r59_four_views']:
  for file in (ROOT/folder).rglob('*'):
   if file.is_file() and '__pycache__' not in file.parts:copy(file,file.relative_to(ROOT).as_posix())
 copy(bit,prefix+'.bit');copy(H/'R59_UI_Actual_Simulation.png','R59_UI_Actual_Simulation.png')
 copy(H/'R59_DESIGN_AND_HANDOFF.md','docs/R59_DESIGN_AND_HANDOFF.md');copy(OLD/'R58_DESIGN_AND_HANDOFF.md','docs/R58_DESIGN_AND_HANDOFF.md')
 for name in selected:copy(H/name,'validation/r59/'+name)
 for name in ['R58_SOFTWARE_VERIFICATION.json','R58_PRODUCTION_ALARM_WIRING_PROOF.json','R58_TIME_CAPTURE_SOURCE_REVIEW.json','R58_ROUTED_REPORT_FORM_NOTES.json','REFERENCE_VERIFICATION.json','HANDOFF_INVENTORY.json']:
  copy(OLD/name,'validation/r58/'+name)
 for group in soft['groups']:
  folder=Path(group['folder']);kind='r59' if folder.parent==H else 'r58'
  for file in folder.rglob('*'):
   if file.is_file() and file.suffix.lower() in {'.log','.json','.v','.sv','.hex','.py'} and not any(n in file.parts for n in ['work','anlogic_sim']):
    if re.fullmatch(r'(?:essential_ui|dual_ui|frame)_\d+\.hex',file.name):continue
    copy(file,'validation/'+kind+'/executions/'+folder.name+'/'+file.relative_to(folder).as_posix())
 for name in ['tb_r58_latency_leaf.sv','tb_r58_latency_expiry.sv','tb_r58_buzzer.sv','tb_r58_buzzer_real.sv','tb_r58_alarm_buzzer_collision.sv','tb_r58_production_alarm.sv','tb_r58_old_wiring_negative.sv','tb_r58_dense_native.sv','run_r58_sim.py']:
  copy(OLD/name,'validation/r58/'+name)
 for file in (OLD/'r58_old_wiring_negative_b').rglob('*'):
  if file.is_file() and file.suffix in {'.log','.json','.v','.sv','.py'} and not any(n in file.parts for n in ['work','anlogic_sim']):copy(file,'validation/r58/expected_negative/'+file.relative_to(OLD/'r58_old_wiring_negative_b').as_posix())
 copy(Path('D:/FpgaWork/r28_field_20261102/r57_font_reference.json'),'validation/r59/r57_font_reference.json')
 for file in (OLD/'reference/HANDOFF/Buzzer_Latency_Port_20261102').rglob('*'):
  if file.is_file():copy(file,'reference/Buzzer_Latency_Port_20261102/'+file.relative_to(OLD/'reference/HANDOFF/Buzzer_Latency_Port_20261102').as_posix())
 copy(Path('D:/FpgaWork/dual_roi_r57_20261102/project/td_project/camera_to_dsi_display.sdc'),'reference/R57_camera_to_dsi_display.sdc')
 for name in build_names:copy(w/name,'build/'+name)
 for file in w.glob('export_r*_synthesis.*'):copy(file,'build/'+file.name)
 for stage in ['syn_1','phy_1']:
  for file in (w/'runs'/stage).iterdir():
   if file.is_file() and file.suffix.lower() in {'.log','.rpt','.area','.timing','.cfg','.tcl','.prj','.txt'}:copy(file,'build/runs/'+stage+'/'+file.name)
 for folder in ['classified_audit','gray_packing_audit','instrument_audit']:
  for file in (w/'project'/folder).rglob('*'):
   if file.is_file():copy(file,'build/'+folder+'/'+file.relative_to(w/'project'/folder).as_posix())
 for label,build in [('A',Path('D:/FpgaWork/r59_build_a_20261102')),('B',Path('D:/FpgaWork/r59_build_b_20261102'))]:
  for name in ['PLACEMENT_RESULT.json','R59_PLACEMENT_GATE.json','R59_SYNTHESIS_PROOF.json','synthesis_result.json','frozen_inputs.json','STAGE_PLACE.json','CONTROLLED_PLACEMENT_COMPARISON.json']:
   if (build/name).is_file():copy(build/name,'comparison/'+label+'/'+name)
  if (build/'runs/syn_1/camera_to_dsi_display_gate.area').is_file():copy(build/'runs/syn_1/camera_to_dsi_display_gate.area','comparison/'+label+'/actual_synthesis.area')
  for name in ['placed_intermediate.area','placement_diagnostic.timing']:
   if (build/'runs/phy_1'/name).is_file():copy(build/'runs/phy_1'/name,'comparison/'+label+'/'+name)
 copy(H/'R59_A_compact_inspector_osd.v','comparison/A_compact_inspector_osd.v')
 for name in ['R59_A_SOFTWARE_VERIFICATION.json','CANDIDATE_CHAR_SCOPE.json','SYNTHESIS_AREA_COMPARISON.json']:
  copy(H/name,'comparison/'+name)
 base=Path('D:/FpgaWork/dual_roi_r58_20261102/project');patch=[]
 for name in soft['changed_files']:
  patch.extend(difflib.unified_diff((base/name).read_text().splitlines(keepends=True),(SRC/name).read_text().splitlines(keepends=True),fromfile='a/'+name,tofile='b/'+name))
 (payload/'R58_to_R59.patch').write_text(''.join(patch),encoding='utf8')
 resources=physical['resources'];count=soft['actual_tests']
 text=f"""# R59 四模式双列检测、蜂鸣器与真实延迟（待实板验收）

本地分支 `r59-four-view-resource-20261102`，源码提交 `{git['commit']}`。基于已验收 R58，完整接线、修改范围、测量定义及资源对照见 [交接说明](docs/R59_DESIGN_AND_HANDOFF.md)。

SW2/SW1：00 RAW原色、01 灰度、10 原色叠加橙色边缘、11 灰度叠加橙色边缘；稳定20ms后整组切换。SW3和K1～K4保持R58操作。双列独立编号/统计/空穴号与停车保持；C12低有效蜂鸣器在任一列五连空穴报警后2kHz响200ms/停300ms，板载SW5须接通；清零/新RUN解除报警。

右上角蓝色LAT/LAG、粉色SRC及16×32字号保留。LAT是同一采集帧RAW SOF至OSD后HDMI首有效像素的帧龄，0.1ms显示；重复帧重新计时，无效/未来/过期标签显示横线。它包含SOF之后的读出、ISP、帧缓存等待和扫描，不包含此前曝光、HDMI后端及面板响应。SRC是独立视频来源号，不是穴位编号。预览来自实际RTL仿真。

最终资源：Slice {resources['slice']}/21216（{resources['slice']/21216*100:.2f}%）、ERAM107/108（99.07%，余1块）、DSP31/40、PLL5/6。最终Routed/Both：setup {timing['SWNS']:+.3f}ns、hold {timing['HWNS']:+.3f}ns、双TNS0。107ERAM包含完整96位RGB缓存、4灰度行、原字库/两列ID/队列，不减少精度或缓存深度。

最终源码对应{count}项验证：按实际编译输入SHA保留未变结果，重跑受影响UI及真实帧链；没有使用不对应当前输入的历史PASS。包含四种视图的完整1920×1080 RAW双列密集场景、所有像素四模式核对、13次真实DDR/FIFO/相位/OSD及独立首像素计时、560640界面RGB和112个第二列字形行、原计数/停车/五连报警/回绕/旧界面回归。44有效最大延迟、精确9移除显示路径、84Gray位及两级、邮箱、四键、电机、双报警、C12及SW1/SW2实际物理阶段/扇出审核通过。比较数据见comparison，Placed不能代替最终Routed。

烧录唯一文件 `{prefix}.bit`，SHA-256 `{digest}`；屏幕应显示INSPECT D3 R59。接线及实板步骤见交接说明。本任务没有操作板卡、电机或继电器，实际声音、光学识别和停车精度仍HUMAN_PENDING；本版尚未上传GitHub。

项目入口 `project/td_project/camera_to_dsi_display.al`。从解包根目录重新构建（需要本机工具/许可证）：

```powershell
python scripts/build_r22_relay.py --source project --baseline-manifest R58_BASELINE_SHA256.json --baseline-label 2943c65c --keys-v3 --seed 4 --synthesis-strategy Default --physical-strategy Default --stage-timeout 7200 --td <TD安装根> --work D:/FpgaWork/R59_rebuild
```

实际验证夹具、输入和日志在validation；物理/综合网表在build。辅助检查脚本保存了本次真实机器路径，移机运行需调整路径/许可证；新的构建必须重新验收，不能复用本包物理PASS。参考HANDOFF内容仅作参考，不覆盖生产工程。
"""
 (payload/'README.md').write_text(text,encoding='utf8')
 summary={'status':'PASS_R59_FOUR_VIEWS_SOFTWARE_AND_ROUTED_HUMAN_PENDING','version':prefix,'git_commit':git['commit'],'bit':prefix+'.bit','bit_sha256':digest,'source_files':705,'source_manifest_sha256':sha(w/'frozen_inputs.json'),'changed_files_from_R58':soft['changed_files'],'exact_input_tests':count,'timing_ns':timing,'resources':resources,'board_acceptance':'HUMAN_PENDING','hardware_operated':False,'github_uploaded':False}
 (payload/'RELEASE.json').write_text(json.dumps(summary,indent=2)+'\n')
 checks={file.relative_to(payload).as_posix():{'bytes':file.stat().st_size,'sha256':sha(file)} for file in sorted(payload.rglob('*')) if file.is_file()};(payload/'PAYLOAD_SHA256.json').write_text(json.dumps(checks,indent=2)+'\n')
 archive=release/(prefix+'_source_and_evidence.zip')
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
  for file in sorted(payload.rglob('*')):
   if file.is_file():z.write(file,file.relative_to(payload).as_posix())
 restored=release/'fresh_restore';restored.mkdir()
 with zipfile.ZipFile(archive) as z:assert z.testzip() is None;z.extractall(restored)
 for name,e in checks.items():assert sha(restored/name)==e['sha256'] and (restored/name).stat().st_size==e['bytes'],name
 for name,d in manifest.items():assert sha(restored/'project'/name)==d,name
 assert [file.name for file in restored.rglob('*.bit')]==[prefix+'.bit'] and sha(restored/(prefix+'.bit'))==digest
 receipt={'status':'PASS_R59_FRESH_RESTORE_ALL_PAYLOADS_705_SOURCE_AND_UNIQUE_ACCEPTED_BIT','payloads':len(checks),'zip':archive.name,'zip_bytes':archive.stat().st_size,'zip_sha256':sha(archive),'bit':prefix+'.bit','bit_sha256':digest,'source_manifest_sha256':sha(w/'frozen_inputs.json'),'git_commit':git['commit'],'exact_input_tests':count,'physical_status':physical['status'],'board_acceptance':'HUMAN_PENDING'}
 (release/'PACKAGE_VERIFICATION.json').write_text(json.dumps(receipt,indent=2)+'\n')
 for file in [archive,payload/(prefix+'.bit')]:
  dst=DOWNLOAD/file.name;assert not dst.exists();shutil.copy2(file,dst);assert sha(dst)==sha(file)
 (DOWNLOAD/(prefix+'_verification.json')).write_text(json.dumps(receipt,indent=2)+'\n');(DOWNLOAD/(prefix+'_SHA256.txt')).write_text(digest+'  '+prefix+'.bit\n'+sha(archive)+'  '+archive.name+'\n')
 shutil.copy2(payload/'README.md',DOWNLOAD/(prefix+'_说明.md'));shutil.copy2(payload/'R59_UI_Actual_Simulation.png',DOWNLOAD/(prefix+'_界面预览.png'))
 (H/'R59_DELIVERY.json').write_text(json.dumps(summary,indent=2)+'\n');(H/'R59_DELIVERY.md').write_text(text,encoding='utf8');print(json.dumps(receipt,indent=2),flush=True)
if __name__=='__main__':main()
