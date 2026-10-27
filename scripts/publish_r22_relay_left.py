"""Versioned V2 delivery, guarded by frozen source, actual tests and routed STA."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess,zipfile
from publish_r22_relay import sha,load,write,copy

def main():
 a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);args=a.parse_args()
 repo=Path(__file__).resolve().parents[1];project=repo/'fpga/component_inspector';work=args.work.resolve()
 physical=load(work/'physical_verification.json')
 assert physical['status'].startswith('PASS_R22_RELAY_') and 'left refill' in physical['layout']
 assert physical['timing_ns']['SWNS']>=0 and physical['timing_ns']['HWNS']>=0
 assert physical['max_delays_matched']==49 and physical['max_delays_ignored']==0
 source=load(work/'frozen_inputs.json')
 for rel,d in source.items():assert sha(project/rel)==sha(work/'project'/rel)==d,rel
 frozen_count=len(source)
 source['sim/tb_relay_left_native.sv']=sha(project/'sim/tb_relay_left_native.sv')
 names=['classified_counter','result_recorder_pipeline','local_pipeline','simple_recovery_0','simple_recovery_1',
  'simple_recovery_2','simple_recovery_3','simple_recovery_4','switch_recorder_controls','recovery_protection',
  'simple_recovery_ui','text_plane_prefetch','edge_raw_mode1']
 sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',(project/'sim/run_modelsim.ps1').read_text(encoding='utf8')))
 legacy=[]
 for name in names:
  folder=project/'sim/modelsim_work'/name;cl=(folder/'compile.log').read_text(encoding='utf-8-sig');co=(folder/'console.log').read_text(encoding='utf-8-sig')
  assert sentinels[name] in co and not re.search(r'\*\*\s+(?:Fatal|Error):|Errors:\s*[1-9]',cl+co),name
  assert re.search(r'Errors:\s*0,\s*Warnings:',co),name
  compiled={};variant=None
  for line in cl.splitlines():
   if 'vlog ' in line and '-work' in line:
    for token in line.split():
     token=token.strip('"')
     if token.endswith(('.v','.sv')):
      p=(project/'sim'/token).resolve();rel=p.relative_to(project).as_posix()
      assert rel in source and sha(p)==source[rel],(name,rel)
      if name=='edge_raw_mode1' and rel=='user_source/hdl_source/isp/isp_top.v':
       # A late addition affects only the baseline's disabled generate branch.
       # Preserve historical compiled bytes rather than relabeling them final.
       historical=Path('E:/2026FPGA/.codex_tmp/r22_relay_left_build_r2_20261027/project')/rel
       start=' if(AUTO_RELAY && RELAY_LEFT_LAYOUT)begin : left_station';end=' end else if(AUTO_RELAY)begin : automatic_relay'
       def inactive_removed(s):return s[:s.index(start)]+s[s.index(end):]
       assert inactive_removed(historical.read_text(encoding='utf8'))==inactive_removed(p.read_text(encoding='utf8'))
       assert '.AUTO_RELAY(' not in (project/'sim/local_edge/tb_edge_raw_mode1.v').read_text()
       variant={'path':str(historical),'compiled_isp_sha256':sha(historical),'final_isp_sha256':source[rel],'equivalence':'only disabled AUTO_RELAY && RELAY_LEFT_LAYOUT generate branch differs; baseline bench AUTO_RELAY=0'}
       compiled[rel]=sha(historical)
      else:compiled[rel]=source[rel]
  assert compiled,name
  legacy.append({'name':name,'status':'PASS','inputs':compiled,'historical_inactive_branch_variant':variant,'compile_sha256':sha(folder/'compile.log'),'console_sha256':sha(folder/'console.log')})
 groups=[Path('E:/2026FPGA/.codex_tmp/r22_relay_left_signature_r2_20261027'),Path('E:/2026FPGA/.codex_tmp/r22_relay_left_support_r1_20261027')]
 new=[]
 for folder in groups:
  proof=load(folder/'verification.json');assert proof['status']=='PASS'
  for rel,d in proof['inputs'].items():assert source[rel]==d,(folder,rel)
  for test in proof['tests']:
   log=folder/(test['name']+'.log');assert sha(log)==test['sha256'] and 'PASS ' in log.read_text()
   new.append(test)
 assert len(new)==9 and len({t['name'] for t in new})==9
 assert 'tb_relay_left_rgb' in {t['name'] for t in new} and 'tb_relay_left_real_second' in {t['name'] for t in new}
 native_folder=Path('E:/2026FPGA/.codex_tmp/r22_relay_left_native_r1_20261027');native=load(native_folder/'verification.json');assert native['status']=='PASS'
 for rel,d in native['inputs'].items():assert source[rel]==d,('final native',rel)
 assert sha(native_folder/'console.log')==native['console_sha256']
 new.append({'name':native['name'],'console_sha256':native['console_sha256']})
 protected=Path('E:/2026FPGA/BIT_FLASH/LATEST_READONLY.bit');protected_sha='30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f'
 assert sha(protected)==protected_sha
 original=repo/'releases/r22_20261027/PocketCount_SW3_LocalEdge_r22_20261027.bit'
 assert sha(original)=='a07bd753296d320c495f234669477563f1f34cdc60af87089575b3bc1bad4df2'
 name='R22_RelayAuto_Left_V2_20261027';release=repo/'releases/r22_relay_left_v2_20261027';assert not release.exists()
 release.mkdir(parents=True)
 for rel in source:copy(project/rel,release/'project'/rel)
 write(release/'SOURCE_SHA256.json',source)
 copy(repo/'releases/r22_20261027/frozen_inputs.json',release/'baseline/r22_frozen_inputs.json');copy(original,release/'baseline'/original.name)
 for script in ['build_r22_relay.py','relay_left_checks.py','relay_left_native_check.py','audit_r22_relay.py','publish_r22_relay.py','publish_r22_relay_left.py']:
  copy(repo/'scripts'/script,release/'scripts'/script)
 copy(repo/'docs/R22_RELAY_LEFT_V2_FIELD_GUIDE.md',release/'FIELD_GUIDE.md')
 copy(repo/'docs/R22_RELAY_LEFT_V2_FIELD_FEEDBACK.json',release/'V1_FIELD_FEEDBACK.json')
 for p in work.iterdir():
  if p.is_file() and p.suffix in ['.json','.py','.tcl','.log']:copy(p,release/'build'/p.name)
 for stage in ['syn_1','phy_1']:
  for p in (work/'runs'/stage).iterdir():
   if p.is_file() and (p.suffix in ['.log','.cfg','.tcl','.prj','.rpt','.area','.timing','.db'] or p.name=='constraint_coverage.txt'):
    copy(p,release/'build/runs'/stage/p.name)
 for directory in ['classified_audit','gray_packing_audit']:
  for p in (work/'project'/directory).iterdir():
   if p.is_file():copy(p,release/'build'/directory/p.name)
 for row in legacy:
  for n in ['compile.log','console.log']:copy(project/'sim/modelsim_work'/row['name']/n,release/'tests/legacy'/row['name']/n)
  if row['historical_inactive_branch_variant']:copy(Path(row['historical_inactive_branch_variant']['path']),release/'tests/legacy'/row['name']/'compiled_isp_top.v')
 for folder in groups:
  for p in folder.iterdir():
   if p.is_file() and p.suffix in ['.json','.log','.png']:copy(p,release/'tests'/folder.name/p.name)
  for p in (folder/'inputs').iterdir():copy(p,release/'tests'/folder.name/'inputs'/p.name)
 for p in native_folder.iterdir():
  if p.is_file() and p.suffix in ['.json','.log']:copy(p,release/'tests/native_left'/p.name)
 for p in (native_folder/'inputs').rglob('*'):
  if p.is_file():copy(p,release/'tests/native_left/inputs'/p.relative_to(native_folder/'inputs'))
 verification={'status':'PASS_23_ACTUAL_TESTS_AND_ROUTED_AUDIT','legacy':legacy,'new':new,'physical':physical,
  'source_count':len(source),'frozen_build_source_count':frozen_count,'hardware_dependencies':len(load(work/'hardware_inputs.json')),
  'scope':'new layout closed-loop processing RGB202 frames; V2 default100MHz100000000-cycle hold; original nativeRAW MODE1 compatibility; final production flags nativeRAW12 frames LEFT four known crossings / two EMPTY queued / >150ms pre-arrival wait',
  'physical_accuracy_verified':False,'physical_hold_verified':False,'board_operated':False}
 write(release/'VERIFICATION.json',verification)
 bit=work/'runs/phy_1/camera_to_dsi_display.bit';copy(bit,release/(name+'.bit'))
 receipt={'version':name,'feature_branch':'codex/r22-relay-left-v2','base_commit':'a1cceaa9b5a37ff31b7f84a77c00042b027208d0',
  'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'pushed':False,
  'bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,'td_version':'V6.2.168116','place_seed':2,
  'resources':physical['resources'],'slice_percent':physical['slice_percent'],'timing_ns':physical['timing_ns'],
  'gpio':'right J2 pin1 / V2 / LVCMOS33 / drive4 / pulldown; board5V /3.3V HIGH; no LEDs',
  'parameters':{'direction':'LEFT','count_line':640,'station_line':256,'target_x':160,'advance_px':16,'tolerance_px':8,
   'hold_ms':1000,'queue':32,'arrival_ms':15000,'position_stale_ms':150,'require_clear_startup':True,'ordered_kind_signature':True},
  'source_manifest_sha256':sha(release/'SOURCE_SHA256.json'),'verification_sha256':sha(release/'VERIFICATION.json'),
  'physical_calibration':'PENDING','board_5v_load_regression':'PENDING','board_programmed_by_assistant':False}
 write(release/'RELEASE.json',receipt)
 (release/'README.md').write_text('''# R22 右计数、左补件 V2 联调交付

先读 FIELD_GUIDE.md；当前 RUN 必须从计数线左侧及补件区无未编号料段的状态开始，人工设置屏幕右向左。继电器及其他引脚沿用V1。参数为处理图像像素，尚未实板标定±1mm。本版不驱动吸嘴。

23项实际软件测试及最终布线数值证据在 VERIFICATION.json。新布局停车闭环为完整1280×720处理RGB像素；最终生产分支另实跑12帧原生RAW10 MODE1，4个已知P/E编号、2个空穴队列、到站前超过150ms继续送料，含原始解码/DDR及精确显示像素核对。这组RAW没有运动至停车线，不称作原生RAW停车闭环或实板验收。原基线RAW编译时ISP尚未加入类别核对，差异仅位于关闭的AUTO_RELAY分支，保留了历史编译源，另有最终开启分支的新RAW测试。左右类别顺序不一致停止；连续同类穴位完全漏检不能单靠计数在数学上排除，需已知料序验收。

从新的短英文目录重建，不在冻结包内运行或覆盖：

```
python scripts/build_r22_relay.py --left-v2 --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/R22_Left_rebuild --td E:/TD
python scripts/relay_left_checks.py --source project --out E:/2026FPGA/R22_Left_sim --only tb_relay_left_faults tb_relay_left_transport tb_relay_left_rgb tb_relay_left_real_second tb_relay_left_pixels tb_relay_left_osd
python scripts/relay_left_native_check.py --source project --out E:/2026FPGA/R22_Left_native
python scripts/audit_r22_relay.py --left-v2 --work E:/2026FPGA/R22_Left_rebuild
```

工程project/含628项构建冻结源和1项后加的原生RAW测试台，共629项；后加测试台不改变构建硬件源。原R22回退bit在baseline/。build/为本机实际构建DB/日志/脚本历史，不直接用其历史绝对路径替代上述重建命令。原相机/计数/显示回归入口为project/sim/run_modelsim.ps1，按本机路径传-ModelSimBin和-TdSimRoot。PAYLOAD_SHA256.json绑定全部归档载荷。
''',encoding='utf8')
 payload={p.relative_to(release).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in release.rglob('*') if p.is_file()};write(release/'PAYLOAD_SHA256.json',payload)
 archive=release.with_suffix('.zip');assert not archive.exists()
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in release.rglob('*'):
   if p.is_file():z.write(p,p.relative_to(release).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for rel,row in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==row['sha256'],rel
 flash=Path('E:/2026FPGA/BIT_FLASH');dst=flash/(name+'.bit');assert not dst.exists();copy(release/dst.name,dst)
 copy(release/'FIELD_GUIDE.md',flash/(name+'_说明.md'))
 write(flash/(name+'_RELEASE.json'),{**receipt,'release_directory':str(release),'archive':str(archive),'archive_sha256':sha(archive)})
 assert sha(protected)==protected_sha
 delivery={'status':'DELIVERED_FOR_HUMAN_CALIBRATION','release':str(release),'archive':str(archive),'archive_sha256':sha(archive),'flash_copy':str(dst),'bit_sha256':sha(bit),'payload_count':len(payload)}
 write(repo/'docs/R22_RELAY_LEFT_V2_DELIVERY.json',delivery);print(json.dumps(delivery,indent=2),flush=True)
if __name__=='__main__':main()
