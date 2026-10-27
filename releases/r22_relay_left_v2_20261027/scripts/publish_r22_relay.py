"""Publish only after real regression + routed audits; never touches a board."""
from pathlib import Path
import argparse,difflib,hashlib,json,re,shutil,subprocess,zipfile

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,value):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def copy(src,dst):dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst);assert sha(src)==sha(dst)

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--work',type=Path,required=True);args=ap.parse_args()
 repo=Path(__file__).resolve().parents[1];project=repo/'fpga/component_inspector';work=args.work.resolve()
 physical=load(work/'physical_verification.json');assert physical['status'].startswith('PASS_R22_RELAY_')
 assert physical['timing_ns']['SWNS']>=0 and physical['timing_ns']['HWNS']>=0
 assert physical['max_delays_matched']==49 and physical['max_delays_ignored']==0
 frozen=load(work/'frozen_inputs.json')
 for rel,digest in frozen.items():assert sha(project/rel)==sha(work/'project'/rel)==digest,rel
 source=dict(frozen)
 for rel in ['sim/tb_relay_real_second.sv','sim/tb_relay_osd.sv','sim/tb_relay_queue.sv']:source[rel]=sha(project/rel)
 tests=['classified_counter','result_recorder_pipeline','local_pipeline','simple_recovery_0','simple_recovery_1',
  'simple_recovery_2','simple_recovery_3','simple_recovery_4','switch_recorder_controls','recovery_protection',
  'simple_recovery_ui','text_plane_prefetch','edge_raw_mode1','edge_raw_mode2','edge_raw_mode3']
 sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',(project/'sim/run_modelsim.ps1').read_text()))
 regressions=[]
 for name in tests:
  folder=project/'sim/modelsim_work'/name
  compile_log=(folder/'compile.log').read_text(encoding='utf-8-sig');console=(folder/'console.log').read_text(encoding='utf-8-sig')
  assert sentinels[name] in console and re.search(r'Errors:\s*0,\s*Warnings:',console),(name,'missing completion')
  assert not re.search(r'\*\*\s+(Fatal|Error):|Errors:\s*[1-9]',compile_log+console),name
  compiled={}
  for line in compile_log.splitlines():
   if 'vlog ' in line and '-work' in line:
    for token in line.split():
     token=token.strip('"')
     if token.endswith(('.v','.sv')):
      p=(project/'sim'/token).resolve();rel=p.relative_to(project).as_posix()
      assert rel in source and sha(p)==source[rel],(name,rel)
      compiled[rel]=source[rel]
  assert compiled,(name,'no compiled identities')
  regressions.append({'name':name,'status':'PASS','inputs':compiled,'compile_sha256':sha(folder/'compile.log'),'console_sha256':sha(folder/'console.log')})
 unit=Path('E:/2026FPGA/.codex_tmp/r22_relay_unit_r5_20261027');unit_proof=load(unit/'verification.json')
 assert unit_proof['status'].startswith('PASS_ACTUAL_RELAY_AND_') and len(unit_proof['tests'])==3
 for rel,digest in unit_proof['inputs'].items():assert source[rel]==digest,rel
 extra=[('relay_osd',Path('E:/2026FPGA/.codex_tmp/r22_relay_osd_r1_20261027'),'PASS relay OSD:'),
        ('relay_queue',Path('E:/2026FPGA/.codex_tmp/r22_relay_queue_r1_20261027'),'PASS relay queue:')]
 for name,folder,sentinel in extra:
  text=(folder/'console.log').read_text(encoding='utf-8-sig')
  assert sentinel in text and not re.search(r'\*\* (Fatal|Error):|Errors:\s*[1-9]',text),name
  for p in folder.glob('*'):
   if p.suffix in ['.v','.sv']:
    rel=('sim/' if p.suffix=='.sv' else 'user_source/hdl_source/')+p.name
    assert source[rel]==sha(p),(name,rel)
 original_bit=repo/'releases/r22_20261027/PocketCount_SW3_LocalEdge_r22_20261027.bit'
 assert sha(original_bit)=='a07bd753296d320c495f234669477563f1f34cdc60af87089575b3bc1bad4df2'
 protected=Path('E:/2026FPGA/BIT_FLASH/LATEST_READONLY.bit')
 assert sha(protected)=='30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f'
 name='R22_RelayAuto_V1_20261027';release=repo/'releases/r22_relay_auto_20261027';assert not release.exists(),'Refuse to overwrite release'
 release.mkdir(parents=True)
 for rel in source:copy(project/rel,release/'project'/rel)
 write(release/'SOURCE_SHA256.json',source)
 copy(repo/'releases/r22_20261027/frozen_inputs.json',release/'baseline/r22_frozen_inputs.json')
 copy(repo/'docs/R22_HANDOFF.md',release/'baseline/R22_HANDOFF.md')
 copy(original_bit,release/'baseline'/original_bit.name)
 for script in ['build_r22_relay.py','relay_r22_checks.py','audit_r22_relay.py','publish_r22_relay.py']:
  copy(repo/'scripts'/script,release/'scripts'/script)
 copy(repo/'docs/R22_RELAY_AUTO_FIELD_GUIDE.md',release/'FIELD_GUIDE.md')
 for p in work.glob('*.json'):copy(p,release/'build'/p.name)
 copy(work/'build_recipe.py',release/'build/build_recipe.py')
 for p in work.glob('*.tcl*'):copy(p,release/'build'/p.name)
 copy(work/'verify_relay_physical.py',release/'build/verify_relay_physical.py')
 for stage in ['syn_1','phy_1']:
  folder=work/'runs'/stage
  for p in folder.iterdir():
   if p.is_file() and (p.suffix in ['.log','.cfg','.tcl','.prj','.rpt','.area','.timing','.db'] or p.name=='constraint_coverage.txt'):
    copy(p,release/'build/runs'/stage/p.name)
 for directory in ['classified_audit','gray_packing_audit']:
  for p in (work/'project'/directory).iterdir():
   if p.is_file():copy(p,release/'build'/directory/p.name)
 for row in regressions:
  for n in ['compile.log','console.log']:
   copy(project/'sim/modelsim_work'/row['name']/n,release/'tests/legacy'/row['name']/n)
 for p in unit.iterdir():
  if p.is_file() and p.suffix in ['.log','.json']:copy(p,release/'tests/relay'/p.name)
 for p in (unit/'inputs').iterdir():copy(p,release/'tests/relay/inputs'/p.name)
 for key,folder,_ in extra:
  for p in folder.iterdir():
   if p.is_file() and p.suffix in ['.log','.json','.v','.sv','.png']:copy(p,release/'tests'/key/p.name)
 verification={'status':'PASS_R22_RELAY_20_ACTUAL_TESTS_ROUTED_AND_IO_AUDIT','legacy_tests':regressions,
  'new_tests':unit_proof['tests']+[{'name':n,'console_sha256':sha(p/'console.log')} for n,p,_ in extra],
  'frozen_build_source_count':len(frozen),'full_source_count':len(source),'hardware_dependencies':len(load(work/'hardware_inputs.json')),
  'physical_audit':physical,'user_5v_source':'development board','automatic_stop_enabled':True,
  'physical_position_accuracy_verified':False,'physical_hold_verified':False,'board_operated':False}
 write(release/'VERIFICATION.json',verification)
 bit=work/'runs/phy_1/camera_to_dsi_display.bit';copy(bit,release/(name+'.bit'))
 receipt={'version':name,'base_branch':'r22-local-edge-20261027','base_commit':subprocess.check_output(['git','rev-parse','origin/r22-local-edge-20261027'],cwd=repo,text=True).strip(),
  'feature_branch':'codex/r22-relay-v1','bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,
  'td_version':'V6.2.168116','place_seed':2,'resources':physical['resources'],'slice_percent':physical['slice_percent'],
  'slice_delta_vs_r22':physical['slice_delta_vs_r22'],'timing_ns':physical['timing_ns'],
  'gpio':'right J2 pin1 / V2 / LVCMOS33 / drive4 / pulldown','diagnostic_led_ports':0,
  'initial_parameters':{'target_x':760,'advance_px':24,'position_tolerance_px':8,'hold_ms':1000,'queue_depth':8},
  'source_manifest_sha256':sha(release/'SOURCE_SHA256.json'),'verification_sha256':sha(release/'VERIFICATION.json'),
  'board_programmed_by_assistant':False,'physical_calibration':'PENDING','board_5v_load_regression':'PENDING'}
 write(release/'RELEASE.json',receipt)
 (release/'README.md').write_text('''# R22自动空穴停车联调版

识别基线a1cceaa，分支codex/r22-relay-v1；新版本见RELEASE.json，先读FIELD_GUIDE.md。
20项软件测试实际执行、完整双角布线和49条延迟约束/20条Gray/9组邮箱审计通过；毫米定位和板载5V负载仍待人工实测。8个EMPTY队列，向右，实测位置确认后保持1秒，故障保持停止。没有吸嘴动作或补件成功判定。

烧录根目录R22_RelayAuto_V1_20261027.bit。baseline/保留原R22回退bit。project/为完整源及测试；SOURCE_SHA256.json绑定每个文件。build/为历史真实构建DB/配置/报告，不是现场实测证据；历史绝对Path不直接作为跨机重建入口。

在新的全英文短目录重建，不覆盖发布包或旧工程：

```
python scripts/build_r22_relay.py --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/R22_Relay_rebuild --td E:/TD
python scripts/relay_r22_checks.py --source project --out E:/2026FPGA/R22_Relay_sim --modelsim E:/Modelsim/win64
```

原R22回归入口project/sim/run_modelsim.ps1，传入-ModelSimBin及-TdSimRoot。真实生产1秒测试使用100MHz默认参数；编号流水线集成用缩短保持参数以检查身份/队列时序，不把缩短参数测试当真实1秒。UI与队列的独立测试台在project/sim，原始编译命令、日志和字节身份在tests/；原R22的144项历史验证没有作为本候选重跑数重复计入。
''',encoding='utf8')
 payload={p.relative_to(release).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in release.rglob('*') if p.is_file()}
 write(release/'PAYLOAD_SHA256.json',payload)
 archive=release.with_suffix('.zip');assert not archive.exists()
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in release.rglob('*'):
   if p.is_file():z.write(p,p.relative_to(release).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for rel,row in payload.items():
   data=z.read(rel);assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256'],rel
 flash=Path('E:/2026FPGA/BIT_FLASH')
 for src in [release/(name+'.bit'),original_bit]:
  dst=flash/src.name
  if dst.exists():assert sha(dst)==sha(src),('Different same-name bit exists',dst)
  else:copy(src,dst)
 copy(release/'FIELD_GUIDE.md',flash/(name+'_说明.md'))
 write(flash/(name+'_RELEASE.json'),{**receipt,'release_directory':str(release),'archive':str(archive),'archive_sha256':sha(archive),'flash_copy':str(flash/(name+'.bit'))})
 assert sha(protected)=='30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f'
 write(repo/'docs/R22_RELAY_AUTO_DELIVERY.json',{'status':'DELIVERED_FOR_HUMAN_CALIBRATION','release':str(release),'archive':str(archive),'archive_sha256':sha(archive),'flash_copy':str(flash/(name+'.bit')),'bit_sha256':sha(bit),'payload_count':len(payload)})
 print(json.dumps({'release':str(release),'archive':str(archive),'archive_sha256':sha(archive),'bit_sha256':sha(bit),'flash_copy':str(flash/(name+'.bit')),'payload_count':len(payload)},indent=2),flush=True)
if __name__=='__main__':main()
