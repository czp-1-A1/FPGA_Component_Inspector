from pathlib import Path
import json,hashlib,shutil,subprocess
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
build=root/'tmp/tracking_publish_diag_r2_td_20261011'
record=root/'开发实施/验收记录/20261011_B追踪黑屏排查_轮次2'
release=project/'release/tracking_publish_diag_d3_20261011'
guide=root/'开发实施/41_B黑屏D3发布诊断_上板说明.md'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
audit=load(build/'audit.json');assert audit['status']=='PASS_diagnostic_logic_and_build_only'
assert not release.exists() and not (record/'manifest.json').exists()
inputs=load(build/'inputs.json')
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path'])
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
branch=subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip()
assert head=='3be3967f2457622566fb20b7cef3aa5038e7d885' and branch=='lj4747-contest-work'
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
runs=build/'td_project/camera_to_dsi_display_Runs';bit=runs/'phy_1/camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256']
release.mkdir();shutil.copy2(bit,release/bit.name);shutil.copy2(build/'inputs.json',release/'build_inputs.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
identity=f"{bit.stat().st_size}字节，SHA-256 `{sha(bit)}`"
t=audit['timing'];a=audit['resources']
stats=f"Routed慢/快角setup+{t['setup_wns_ns']:.3f}ns、hold+{t['hold_wns_ns']:.3f}ns、TNS0；Slice{a['slice_used']}/{a['slice_total']}={a['slice_percent']:.2f}%，ERAM{a['eram_used']}、DSP{a['dsp_used']}；STA覆盖{t['sta_coverage_percent']:.2f}%"
metadata=dict(purpose='D3_read_only_publish_diagnostic_not_black_screen_fix',syn=str(runs/'syn_1'),phy=str(runs/'phy_1'),flow='D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl',tool='D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe',td_version='6.2.168116',source_commit=None,base_head=head,source_snapshot=record.relative_to(root).as_posix()+'/source_snapshot',simulation_root=build.relative_to(root).as_posix(),release=dict(path=(release/bit.name).relative_to(root).as_posix(),**audit['bit']),validation_record=record.with_suffix('.md').relative_to(root).as_posix(),fresh_tests=6,reused_unchanged_source_tests=28,onsite='PENDING')
guide.write_text(f'''# 黑屏D3发布条件诊断 — 上板说明

这版用于定位v2仍黑的原因，尚未修复帧尾短钟问题，也未上板验收。现有完整帧门槛及读写逻辑保持v2，增加只读诊断。

## 使用步骤

1. 下载 [D3镜像](../{metadata['release']['path']})。身份：{identity}。请使用release目录文件，不使用旧TD输出或v2镜像。
2. 复位、保持相机连接，静止等待5秒。先看顶部ANLOGIC上方是否出现 `D3 Pxx Wxxxxx`；这个标记用于确认新诊断程序已生效。
3. RAW或GRAY+EDGE均可。拍一张完整HDMI照片，保留D3/P/W、ER/LP/WS、FR/VF/OF/UF。先不改曝光/增益/白平衡、阈值和载带位置。
4. 相机区仍黑也可以读取P/W。只有画面恢复且VF不持续跟FR增长后，才继续慢速横移追踪试验。

## 如何读P/W

W是上一关闭采集帧提交MC端口的128位字数，显示十六进制。完整1024×600 RGB帧为115200字，即 `W1C200`。本轮TAIL=0仿真停止处写入114960字，即 `1C110`；现场数值是否相同须实测。

P是该帧期间各条件的sticky证据，不能解释为同一时刻都成立：

| 位 | 意义 |
|---|---|
| 7 | 该帧已发布 |
| 6 | 曾收到当前帧epoch的metadata |
| 5 | 曾收到ready且epoch匹配的metadata |
| 4 | 相机侧完整字数到达（done） |
| 3 | 图像完整性证明到达（good） |
| 2 | 该帧曾被标坏（bad） |
| 1 | 提交MC的字数达到115200 |
| 0 | 采集帧已打开 |

成功完整帧一般为 `PFB W1C200`。复位或尚未关闭首帧为 `P00 W00000`。

| 诊断组合 | 下一步排查方向 |
|---|---|
| W不足，done=0、good=0 | 原生帧/ISP流水线末尾未完成；重点查帧尾停钟和新FS抢占 |
| W不足，done=1、good=1 | 像素已齐但DDR尚未写完；查FIFO/DDR仲裁及回压 |
| W完整，done=1、good=1，metadata匹配未到 | metadata就绪/帧号归属 |
| bad=1 | 查导致拒绝的采集/配置/缓存异常 |
| P00长期不变但FR增长 | 处理后的帧开始没有抵达writer，或板上仍是旧镜像 |

各条件曾出现却未发布，还可能是metadata随后撤销或新帧抢占，不凭sticky位直接判发布门控错误。

## 软件验证及限制

六项受影响验证重新执行：publish_diag、tracking_osd、osd、frame_metadata、isp_metadata_stop、isp_writer_stop；另28项逐项确认全部编译输入和测试台未变而复用。新OSD逐像素验证13字符、完整115200字与114960字显示、显示帧内冻结。残帧仍拒绝，下一完整帧仍恢复。

{stats}。37条max_delay均匹配、ignored0；其中新增三条是D3的DDR→HDMI稳定邮箱预算。生产210输入仅video_in/top/OSD/SDC四文件变更；移除只读observer后video_in全文与v2相同。

TAIL=0原目标测试失败记录独立保留；现场CSI时钟尾部仍未测。实际ISP测试尚未包含top的image_correction一拍，仿真通过不替代实际视频/分类/追踪验收。原厂PLL反馈/I/O/未覆盖路径告警沿用旧版本，详见资源/时序记录。

未提交、未推送、未执行JTAG或Flash。原v2、下方v1及静态manual_wb_tuning_v1回退镜像保留。
''',encoding='utf-8')
(release/'README.md').write_text(f'''# D3发布条件诊断

camera_to_dsi_display.bit：{identity}。

用途：为v2仍黑提供上一采集帧P/W发布条件证据。只读诊断，不声称黑屏已修复。六项新测通过、28项编译输入未变复用；{stats}。

复位等待5秒，确认顶部 `D3 Pxx Wxxxxx`，拍完整HDMI照片。使用说明见开发实施/41_B黑屏D3发布诊断_上板说明.md。现场验收PENDING；无JTAG/Flash操作，未提交/推送。
''',encoding='utf-8')
p=record.with_suffix('.md');s=p.read_text(encoding='utf-8')
s=s.replace('## 本轮执行记录（待构建结束补全）','## 本轮执行记录')
s=s.replace('tracking_osd逐像素验证D3字符和帧内固定，原osd/frame_metadata/isp_metadata_stop/isp_writer_stop回归与TD综合/布局布线进行中。',f"tracking_osd逐像素验证D3字符和帧内固定，原osd/frame_metadata/isp_metadata_stop/isp_writer_stop五项回归PASS。共六项新测、28项编译源闭包未变复用；综合/布局布线PASS，{stats}。37条max_delay均匹配/ignored0，124条综合与10条物理告警内容与v2相同。")
s+=f"\n正式D3镜像：`{metadata['release']['path']}`，{identity}。详细输入/时序/测试见audit.json及manifest.json。\n"
p.write_text(s,encoding='utf-8')
p=root/'AGENTS.md';s=p.read_text(encoding='utf-8');s=s[:s.index('## 当前断点')]+f'''## 当前断点（2026-10-11，D3诊断版已发布，待现场P/W）

- **目标/断点**：v2现场仍黑（FR2441/VF2440、ER0/LP02E2/WS0、OF/UF0、CFG1/FPS26）。D3只读诊断提供上一帧发布旗标/MC字数，尚未修复/上板；记录{metadata['validation_record']}，说明41_B黑屏D3发布诊断_上板说明.md。
- **分支/基线**：{branch}，HEAD{head}，暂存空，旧WIP保留。210生产输入仅video_in/top/OSD/SDC变更；writer发布/捕获/FIFO原逻辑移除observer后与v2全文相同。冻结{build.relative_to(root).as_posix()}。
- **验证/证据**：六项新跑PASS（publish_diag、tracking_osd、osd、frame_metadata、isp_metadata_stop、isp_writer_stop）；28项编译源闭包未变复用。{stats}；37max_delay匹配/ignored0，124/10告警与v2相同。D3 SHA{sha(bit)}。旧TAIL=0补测失败：metadata已ready且epoch匹配，PACK115188/WR114960、good0/bad0；只证明遗漏更短尾部，现场根因未定。R1诊断测试误用旧capture_ok失败保留，R2检查当前published，RTL未改。
- **下一条操作**：人工下载D3正式release，复位等5秒，确认顶部D3并拍完整HDMI含P/W与FR/VF；W完整值1C200。根据done/good/metadata/写入计数定位实际阻塞；不猜SC500CS连续钟寄存器、不放宽残帧检查。真正尾部修复需双上下文及DDR排空/连续帧/有限回压证明。
- **进程/设备**：本轮综合/物理与回归进程已结束，三个只读代理审查完成；主线程唯一写入，无JTAG/Flash操作。板上实际SHA仍待人工确认。
- **提交/回退**：未提交未推送。v2/下方v1/上方动态版/静态manualWB及旧证据保留；D3用途仅诊断，不能称视频验收通过。
''';p.write_text(s,encoding='utf-8')
shutil.copy2(project/'td_project/current_codex_build.json',record/'current_build_before.json')
dump(project/'td_project/current_codex_build.json',metadata)
def copy(src,rel):
 dst=record/rel;assert not dst.exists(),rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for filename in ['inputs.json','simulation_inputs.json','stage_inputs.json','audit.json']:copy(build/filename,filename)
for stage in ['syn_1','phy_1']:
 for f in (runs/stage).iterdir():
  if f.is_file() and f.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:copy(f,Path('td_reports')/stage/f.name)
for e in load(build/'simulation_inputs.json'):copy(build/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
for e in audit['tests']:
 src=root/e['source']/'sim/modelsim_work'/e['name']
 for name in ['console.log','compile.log','transcript.log']:
  if (src/name).is_file():copy(src/name,Path('simulation/logs')/e['name']/name)
for f in (build/'sim').glob('*exit_code.txt'):copy(f,Path('simulation')/f.name)
copy(build/'sim/regression_console.log','simulation/regression_console.log')
tail=root/'tmp/tracking_black_round2_tail0_20261011'
for f in tail.iterdir():
 if f.is_file() and f.suffix in {'.log','.csv','.txt','.ini'}:copy(f,Path('v2_tail0_failure')/f.name)
failure=root/'tmp/tracking_publish_diag_r1_td_20261011'
for rel in ['inputs.json','simulation_inputs.json','sim/tb_publish_diag.v','sim/diagnostic_unit_console.log','sim/modelsim_work/publish_diag/compile.log','sim/modelsim_work/publish_diag/console.log','sim/modelsim_work/publish_diag/transcript.log']:
 if (failure/rel).is_file():copy(failure/rel,Path('fixture_failure_r1')/rel)
for name in ['video_in.v','design_top_wrapper.v','experiment_osd.v']:copy(root/'tmp/tracking_black_fix_r2_td_20261011/user_source/hdl_source'/name,Path('before')/name)
for script in ['freeze_tracking_diag_20261011.py','run_tracking_diag_build_20261011.ps1','audit_tracking_diag_20261011.py','audit_tracking_diag_before_counter_20261011.py','publish_tracking_diag_20261011.py','run_black_tail0_20261011.ps1']:copy(root/'tmp'/script,Path('scripts')/script)
copy(guide,'41_上板说明.md');copy(record.with_suffix('.md'),'record.md');copy(root/'AGENTS.md','AGENTS_checkpoint.md');copy(project/'td_project/current_codex_build.json','current_codex_build.json')
copies=[dict(path=f.relative_to(record).as_posix(),bytes=f.stat().st_size,sha256=sha(f)) for f in record.rglob('*') if f.is_file()]
dump(record/'manifest.json',dict(metadata=metadata,copies=copies))
dump(release/'manifest.json',dict(metadata=metadata,files=[dict(path=f.name,bytes=f.stat().st_size,sha256=sha(f)) for f in release.iterdir() if f.is_file()]))
print(json.dumps(dict(release=metadata['release'],record_copies=len(copies)),ensure_ascii=False))
