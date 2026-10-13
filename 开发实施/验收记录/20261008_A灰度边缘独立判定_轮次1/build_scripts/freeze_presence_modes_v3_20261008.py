from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, shutil, subprocess

root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
build=root/'tmp/presence_modes_v3_td_20261008'
retry=root/'tmp/presence_modes_v3_sim_r2_20261008'
record_name='20261008_A灰度边缘独立判定_轮次1'
record=root/'开发实施/验收记录'/record_name
release=project/'release/presence_modes_v3_20261008'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:p.read_text(encoding='utf-8-sig')
load=lambda p:json.loads(read(p))
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
audit=load(build/'audit.json')
assert audit['status']=='PASS_logic_and_build_only' and len(audit['tests'])==8
inputs=load(build/'inputs.json')
assert len(inputs)==209
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path'])
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
branch=subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip()
assert head=='3be3967f2457622566fb20b7cef3aa5038e7d885' and branch=='lj4747-contest-work'
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
assert not record.exists() and not release.exists() and not record.with_suffix('.md').exists()
syn=build/'td_project/camera_to_dsi_display_Runs/syn_1'
phy=syn.parent/'phy_1'
bit=phy/'camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256']
rollback=project/'release/led_presence_demo_v2_r2_20261008/camera_to_dsi_display.bit'
assert sha(rollback)=='c70ad59e63051e71c3ba0d73c4fd7a3ab4f0b38b495d9e43f496f0aa0e057ae9'
record.mkdir();release.mkdir()
copies=[]
def copy(src,rel):
    dest=record/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
    assert sha(dest)==sha(src)
    copies.append({'path':dest.relative_to(record).as_posix(),'bytes':dest.stat().st_size,'sha256':sha(dest)})
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for name in ['inputs.json','stage_inputs.json','preparation.json','audit.json','prior_evidence_check.json']:
    copy(build/name,name)
for stage in [syn,phy]:
    for p in stage.iterdir():
        if p.is_file() and p.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:
            copy(p,Path('td_reports')/stage.name/p.name)
for p in (build/'sim').iterdir():
    if p.is_file() and p.suffix.lower() in {'.v','.ps1','.py','.do','.md','.log','.hex','.png'}:
        copy(p,Path('simulation/attempt1')/p.name)
for p in (build/'sim/osd_assets').rglob('*'):
    if p.is_file():copy(p,Path('simulation/attempt1/osd_assets')/p.relative_to(build/'sim/osd_assets'))
for name in [e['name'] for e in audit['tests']]:
    for p in (build/'sim/modelsim_work'/name).glob('*.log'):
        copy(p,Path('simulation/attempt1/model_logs')/name/p.name)
for name in ['retry.json','inputs.json']:copy(retry/name,Path('simulation/retry')/name)
for p in (retry/'sim').iterdir():
    if p.is_file() and p.suffix.lower() in {'.v','.ps1','.log'}:
        copy(p,Path('simulation/retry')/p.name)
for p in (retry/'sim/modelsim_work/roi_chain').glob('*.log'):
    copy(p,Path('simulation/retry/model_logs/roi_chain')/p.name)
before=root/'tmp/presence_modes_v3_before_20261008'
for p in before.rglob('*'):
    if p.is_file():copy(p,Path('before')/p.relative_to(before))
for name in ['prepare_presence_modes_v3_20261008.py','freeze_presence_modes_v3_inputs_20261008.py','audit_presence_modes_v3_20261008.py','freeze_presence_modes_v3_20261008.py','verify_presence_modes_v3_20261008.py']:
    copy(root/'tmp'/name,Path('build_scripts')/name)
for p in (root/'tmp/presence_modes_v3_design_review_20261008').rglob('*'):
    if p.is_file():copy(p,Path('readonly_review')/p.relative_to(root/'tmp/presence_modes_v3_design_review_20261008'))
shutil.copy2(bit,release/bit.name)
shutil.copy2(build/'inputs.json',release/'build_inputs.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
metadata={'syn':str(syn),'phy':str(phy),'flow':'D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl','tool':'D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe','td_version':'6.2.168116','source_commit':None,'base_head':head,'source_snapshot':record.relative_to(root).as_posix()+'/source_snapshot','release':{'path':(release/bit.name).relative_to(root).as_posix(),**audit['bit']},'validation_record':record.with_suffix('.md').relative_to(root).as_posix()}
dump(project/'td_project/current_codex_build.json',metadata)
guide=f'''# 灰度与边缘独立判定第三版试用

烧录本目录 `camera_to_dsi_display.bit`。它来自未提交的209输入冻结快照，TD 6.2.168116；SHA-256：`{sha(bit)}`。

| SW1 | SW2 | 模式 | 判定依据 |
|---|---|---|---|
| 下 | 下 | RAW | 3528亮度粗略规则 |
| 上 | 下 | GRAY | MEAN≥58有件，否则空穴 |
| 下 | 上 | EDGE | EC/GS独立判定，MEAN不决定类别 |
| 上 | 上 | GRAY+EDGE | 两者一致才判，冲突/不确定待检测 |

先使用黑色载带，约130 mm；将青框对准单穴，包含需要检测的器件/引脚。青框左右紧邻16像素宽的区域要落在黑带上，避免定位孔。明显离带、边缘落在不确定区、联合冲突显示“待检测”；采样有效仍可保留统计。曝光、增益按键可继续调整，调整后等待新完整样本。

EDGE试验门限：EC≥96且GS≥32768有件；EC≤48且GS≤16384空穴；其他待检测。左右参考条各收满1280像素且至少960像素灰度≤100。EC/GS页脚显示十六进制，T80仍是逐像素边缘门限。

八项仿真分别PASS，ROI首次50ms超时日志保留，只将测试时限改70ms后重测PASS。TD两阶段退出0；routed慢/快角setup+0.470ns、hold+0.020ns、TNS0、违例终点0；Slice78.25%、ERAM48、DSP8。STA覆盖94.56%，原PLL/I/O/例外限制保留，未新增警告。

这是黑带试验版；边缘和暗条门限未经有件/空穴配对标定。黑背景、定位孔或错位仍可能误判，过高曝光/增益可导致待检测；透明带尚未支持。没有上板/冷启动或准确率验收，显示“最近采样”而非当前DDR帧绑定。

建议先测3528：同一单穴位置分别有件、空穴，在GRAY与EDGE记录结果；保持一个模式时检查画面连续更新。随后再试黑带黑件。回退用 `../led_presence_demo_v2_r2_20261008/camera_to_dsi_display.bit`，SHA `c70ad59e63051e71c3ba0d73c4fd7a3ab4f0b38b495d9e43f496f0aa0e057ae9`。

详细规则见 `开发实施/32_A灰度与边缘独立判定_第三版说明.md`，完整证据见 `{metadata['validation_record']}`。本轮未提交、未推送。
'''
(release/'README.md').write_text(guide,encoding='utf-8')
doc=root/'开发实施/32_A灰度与边缘独立判定_第三版说明.md'
old_end='镜像路径、SHA、实际仿真和TD布局布线结果以本轮冻结验收记录为准；尚未完成前不得把本说明当作验证通过。'
new_end=f"本轮八项仿真分别PASS，TD两阶段完成；setup+0.470ns/hold+0.020ns、TNS0/违例终点0，Slice78.25%、ERAM48/DSP8，STA覆盖94.56%，原覆盖限制保留。ROI链首次50ms超时后仅扩大时限为70ms，保留失败/重测两组冻结日志。镜像为 `{metadata['release']['path']}`，SHA `{sha(bit)}`；完整证据见 `{metadata['validation_record']}`。"
assert old_end in read(doc)
doc.write_text(read(doc).replace(old_end,new_end),encoding='utf-8')
report=f'''# 灰度与边缘独立判定 — 轮次1

本轮结果：逻辑与物理构建验证通过，实物准确率/冷启动待用户验收。用户已确认实现；没有烧录板卡、改动用户TD GUI或自动提交推送。

基线分支`{branch}`，HEAD`{head}`，未提交209生产输入快照。对v2 R2七项生产变化；保留视频/DDR/Sobel像素流水、引脚/SDC、PPC4/单穴80×80和最近采样接口。新增EC/GS按模式判定、左右暗条门控、完整WAIT显示修正、待检测字形；参见32说明及source_snapshot。

八项ModelSim2019.2原厂RAM验证：presence_modes、display_state、observation、stop_recovery、classifier、osd、isp_writer_stop在首次冻结运行PASS；roi_chain首次因增加3个整帧超过旧50ms watchdog失败，已至frame10通过低MEAN EDGE有件。只扩大仿真上限为70ms，209输入完全不变、功能断言不变，在第二冻结目录重跑12帧PASS。不得称首次整套测试通过或八项在同一运行中通过。

新测试独立核对EC/GS高低边界、GRAY/EDGE/联合决策、黑带暗条覆盖与缺像素、有效WAIT原子CDC、亮背景/单侧离带，以及定位孔仍可通过的反例；全链比较真实AWB四像素/行与帧边界/Sobel/打包/模式标签。低灰度frame10 EDGE有件、frame11 GRAY空穴、frame12联合待检测。OSD614400像素参考和有效待检测预览通过。

TD6.2.168116综合/物理进程均退出0，bitgen结束标记完整。慢/快角Routed setup+0.470ns、hold+0.020ns；setup/hold TNS0、违例端点0。Slice16601/21216=78.25%，LUT6=14135、REG17562、ERAM48、DSP8；对R2增量+80/+82/+69/0/0。STA覆盖94.56%，不是100%；31条max_delay均匹配/ignored0，shadow及PLL/I/O覆盖类别与R2一致，原限制未消除。综合124/物理10条警告标准化比较无新增或移除，独立只读审查一致。

新镜像`{metadata['release']['path']}`，1789539字节，SHA `{sha(bit)}`。v2 R2回退镜像SHA未变。release包含README/SHA256/build_inputs/manifest；证据目录含209源码、TD报告、首次失败和重测日志、测试源码/runner、之前快照、审查与校验。

使用约130mm，青框手动对准黑带单穴及器件特征；左右条落黑带，避免定位孔。本版EC48/96、GS16384/32768、暗条灰度100/75%为试验值，没有配对标定。黑桌面、孔与错位可能误判，高曝光增益可能待检测；透明带不支持。调曝光增益不再固定2244/48使能，但准确率不保证不变。

下一步由用户对同一位置有件/空穴测试并发照片：先3528的GRAY和EDGE，再试黑件；记录画面/模式恢复与对应EC/GS/MEAN。新阈值或算法再由用户确认。阶段A尚未全部验收。
'''
record.with_suffix('.md').write_text(report,encoding='utf-8')
agents=root/'AGENTS.md';prefix=read(agents).split('## 当前断点')[0]
checkpoint=f'''## 当前断点（2026-10-08，第三版已生成，待上板）

- **目标与断点**：用户确认后完成灰度/边缘独立判定。RAW/GRAY保留亮度，EDGE用EC/GS，联合一致才判、冲突待检测；左右暗条过滤明显离带。完整WAIT不再误显示未标定，已生成独立试用镜像。
- **分支/代码基线**：{branch}，HEAD{head}，未提交209输入快照。对v2 R2生产变化7项：新roi_mode_classifier/roi_tape_guard，isp_top/roi_display_state/experiment_osd/osd_cjk_rom/项目.al；其他202生产输入字节保持。测试/字模生成器与32说明随证据保存。
- **交付与证据**：{metadata['release']['path']}，1789539字节，SHA {sha(bit)}；README/SHA256/build_inputs/manifest齐备。{metadata['validation_record']}和同名目录冻结源码、报告、日志与前快照。current_codex_build已指新ASCII构建及未提交快照。
- **验证**：ModelSim原厂RAM八项分别PASS。首次七项通过；roi_chain追加3帧超过50ms watchdog的失败保留，仅测试时限改70ms后新冻结重跑12帧PASS。209生产输入不变，断言不变。EDGE低MEAN有件、GRAY空穴、联合冲突WAIT真实ISP证据；完整WAIT/CDC与OSD全像素测试通过。tmp/presence_modes_v3_td_20261008及tmp/presence_modes_v3_sim_r2_20261008不可边测边改。
- **资源时序**：TD6.2.168116综合/物理退出0、bitgen完成；Routed慢/快角setup+0.470ns/hold+0.020ns、TNS0/违例终点0；Slice16601/21216=78.25%，LUT6=14135、REG17562、ERAM48、DSP8。相对R2+80Slice/+82LUT6/+69REG，ERAM/DSP不变。STA94.56%，原PLL/I/O/例外覆盖类别保留；31条max_delay匹配/ignored0，警告无新增，独立只读审计一致。
- **限制**：黑带试验版，透明带不支持；EC低48/高96、GS低16384/高32768，左右16×80各75%灰度≤100，非配对标定。黑背景/定位孔/错误ROI仍可能通过，高增益可待检测；青框需对准单穴，调参不锁2244/48但不保证准确率，最近采样未绑定DDR帧。新版本上板/冷启动/识别准确率未验收，A未全部完成。
- **下一条操作**：由用户烧录此镜像，先3528同一位置有件/空穴的GRAY与EDGE，反馈照片/真值/EC/GS/MEAN及模式切换后恢复；再定阈值、黑件/透明带扩展，由用户确认后实施。
- **进程设备**：助手TD综合26463/物理74496、首轮仿真81592、ROI重测35646已结束；无助手TDCLI/vsim/vlog在跑。root单写，v3_frame_review只读审查冻结源与报告；用户TD/bw/设备未操作，未JTAG/Flash/冷启动；无新聊天或自动任务。
- **提交/推送与回退**：本轮及之前WIP/证据未提交未推送，暂存区空。回退v2 R2 SHA c70ad59e63051e71c3ba0d73c4fd7a3ab4f0b38b495d9e43f496f0aa0e057ae9；v1/旧R1及诊断记录未覆盖，最终完整性见verification.json。
'''
agents.write_text(prefix+checkpoint,encoding='utf-8')
copy(doc,'实施说明.md');copy(agents,'AGENTS_checkpoint.md')
copy(record.with_suffix('.md'),'验收记录.md')
copy(project/'td_project/current_codex_build.json','current_codex_build.json')
vendor=Path('D:/AAA/FPGA.....YZW/sim_release')
vendor_names=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v','ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v']
data={'created_at':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),'status':'software_verified_board_pending','branch':branch,'base_head':head,'source_commit':None,'commit_status':'uncommitted_unpushed_workspace_snapshot','tool':'TD6.2.168116','simulator':'ModelSim2019.2','build_inputs_count':209,'build_inputs_sha256':sha(build/'inputs.json'),'changed_production_inputs':load(build/'preparation.json')['changed_production_inputs'],'bit':metadata['release'],'audit':audit,'rollback':{'path':rollback.relative_to(root).as_posix(),'sha256':sha(rollback)},'vendor_model_hashes':[{'path':str(vendor/n),'sha256':sha(vendor/n)} for n in vendor_names],'flow_sha256':sha(Path(metadata['flow'])),'copies':copies}
dump(record/'manifest.json',data)
dump(release/'manifest.json',{k:v for k,v in data.items() if k!='copies'})
print(json.dumps({'record':str(record),'release':str(release),'copies':len(copies),'bit':audit['bit']},ensure_ascii=True))
