from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,shutil,subprocess

root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
build=root/'tmp/manual_wb_v1_td_20261009'
before=root/'tmp/manual_wb_v1_before_20261009'
record=root/'开发实施/验收记录/20261009_A可调白平衡_轮次1'
release=project/'release/manual_wb_tuning_v1_20261009'
read=lambda p:p.read_text(encoding='utf-8-sig')
load=lambda p:json.loads(read(p))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
audit=load(build/'audit.json')
assert audit['status']=='PASS_logic_and_build_only' and len(audit['tests'])==23
assert not record.exists() and not record.with_suffix('.md').exists() and not release.exists()
inputs=load(build/'inputs.json')
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
branch=subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip()
assert head=='3be3967f2457622566fb20b7cef3aa5038e7d885' and branch=='lj4747-contest-work'
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
runs=build/'td_project/camera_to_dsi_display_Runs'
bit=runs/'phy_1/camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256']
rollback=project/'release/fixed_wb_tuning_v1_20261009/camera_to_dsi_display.bit'
assert sha(rollback)=='6905dcab92595971b25232775e75582f1d790896a310371edd50a7dd047e76e1'
t,a=audit['timing'],audit['resources']
statistics=f"Routed慢/快角setup+{t['setup_wns_ns']:.3f}ns、hold+{t['hold_wns_ns']:.3f}ns，TNS0、违例终点0；Slice{a['slice_used']}/{a['slice_total']}={a['slice_percent']:.2f}%，LUT6{a['lut6_used']}、REG{a['reg_used']}、ERAM{a['eram_used']}、DSP{a['dsp_used']}；STA覆盖{t['sta_coverage_percent']:.2f}%"
release.mkdir();record.mkdir()
shutil.copy2(bit,release/bit.name)
shutil.copy2(build/'inputs.json',release/'build_inputs.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
metadata=dict(syn=str(runs/'syn_1'),phy=str(runs/'phy_1'),flow='D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl',
    tool='D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe',td_version='6.2.168116',source_commit=None,base_head=head,
    source_snapshot=record.relative_to(root).as_posix()+'/source_snapshot',
    release=dict(path=(release/bit.name).relative_to(root).as_posix(),**audit['bit']),
    validation_record=record.with_suffix('.md').relative_to(root).as_posix())
dump(project/'td_project/current_codex_build.json',metadata)

(release/'README.md').write_text(f'''# 可调白平衡调参版 v1

烧录本目录camera_to_dsi_display.bit。长按KEY1+KEY2约1秒进入/退出WB TUNE；KEY1/2调红-/+，KEY3/4调蓝-/+。同时按住的组合只切换一次，松开全部键后可再次切换。WB LOCK普通状态恢复曝光/传感器增益操作；KEY1/2普通短按在松开消抖后执行。

HDMI显示实际生效的R/B，064为1.0，范围032—192，即0.5—3.0，步长1/64；星号表示尚待新帧生效。绿色固定1.0。退出后保持当前系数，复位/重新上电恢复R064/B064、EXP2244/GAIN48；第一版无Flash保存。框外彩色可直接观察调色，RAW可用于全画面对照。

23项仿真全部PASS，来自同一冻结候选的4项与19项两次运行；全帧ROI链路14帧、每个完整帧1024×600。验证四lane独立像素乘法/饱和、按键/组合/长按/限幅、WB epoch/真实CDC、帧中改参数撤销采样且视频继续、新完整帧恢复、HDMI独立全栅格参考及已有相机/视频/ROI/Sobel功能。未修改原厂RAM模型、旧断言或看门狗来通过。

{statistics}。31条max_delay匹配且ignored0，约束文件未变。综合124条警告同基线，物理10条；既有PHY-5060时钟扇出307→419，仍有1个数据/控制端，其他诊断相同。dummy模型类别3→4来自8个可调色彩DSP乘法器；其余13项覆盖分类相同。旧PLL、I/O、STA覆盖限制仍在。

镜像{bit.stat().st_size}字节，SHA-256：{sha(bit)}。209生产输入/69工程源，未提交工作区快照，source_commit=null；只8项生产输入相对固定WB R2变化。详细上板步骤：开发实施/35_A可调白平衡_上板说明.md。证据：{metadata['validation_record']}及同名目录。没有上板/调色准确率/长稳/冷启动验收。

WB LOCK只锁WB编辑，未实现全配方生产锁定。白平衡变化会改变灰度/边缘特征；原阈值仍仅为试验值，需冻结照明/机位/EXP/GAIN/R/B后重新有件/空穴配对。当前最近采样未绑定DDR显示帧，完整配方/CAL/INVALID/UNCERTAIN管理未实现。回退：../fixed_wb_tuning_v1_20261009/camera_to_dsi_display.bit，SHA {sha(rollback)}。本轮未提交、未推送、未烧板。
''',encoding='utf-8')
guide=root/'开发实施/35_A可调白平衡_上板说明.md'
s=read(guide)
s=s.replace('用户已授权实现。按键、颜色运算、白平衡采样epoch及原有相机控制仿真已通过；完整回归和布局布线正在验证。发布路径、镜像身份及最终验证结果完成后填写，不用临时构建中的bit进行验收。',f'''代码、23项仿真与本机构建已完成，实际烧录使用：`{metadata['release']['path']}`。

镜像{bit.stat().st_size}字节，SHA-256：`{sha(bit)}`。{statistics}。上板调色、长稳、冷启动和物理分类验收待测；镜像来自冻结的未提交工作区，尚未推送。证据见`{metadata['validation_record']}`及同名目录。''')
guide.write_text(s,encoding='utf-8')
route=root/'开发实施/00_分阶段开发与逐级验证路线.md'
s=read(route)
s=s.replace('当前AWB动态更新通道增益，MEAN和Sobel取其后像素；先用固定样品观察画面其他内容变化时特征是否漂移。固定通道增益或调整检测取样位置属于代码方案，确认后单独实现及回归，不能在当前镜像上宣称已经固定白平衡。','前一固定WB版使用红蓝1.0，可调WB版已实现手动红蓝系数和帧边界生效，MEAN和Sobel仍取其后像素；按[35_A可调白平衡_上板说明.md](35_A可调白平衡_上板说明.md)调中性参考，记录并锁住WB编辑。复位恢复默认值，未实现掉电保存；实物颜色及新的分类阈值仍待验证。')
s=s.replace('awb.v按图像累计值更新红/蓝通道增益；标定前核查并确定白平衡策略，不能假定两参数固定即整条成像链固定。','旧自动AWB按图像累计值更新通道增益；当前可调WB版改为手动红蓝系数并整帧保持。标定仍须记录/冻结WB，不能假定仅EXP/GAIN固定即整条成像链固定。')
route.write_text(s,encoding='utf-8')
test_table='\n'.join('| '+e['name']+' | PASS |' for e in audit['tests'])
report=f'''# A可调白平衡 — 轮次1

用户授权生成可调白平衡代码。本轮逻辑/构建验证通过，实物成像和分类仍待测；未烧板、未提交、未推送。分支{branch}，HEAD{head}，source_commit=null，交付为209生产输入/69工程源的冻结工作区快照。

## 实现范围

相对固定WB R2仅8项生产输入变化：{', '.join(audit['changed_production_inputs'])}。新增3个WB测试，已有测试仅更新新增端口/记录位宽并增加整帧/OSD场景；OSD生成器与独立参考保留原字模/Logo。原DDR/MIPI/FIFO、ROI/门限、Sobel运算、自动路径对照均未改。

长按KEY1+KEY2约1秒进入/退出WB；组合短按无参数变化、长按只触发一次、全松开再重入。四键调红蓝代码32—192，默认64，步长1/64；普通模式保留EXP/GAIN，KEY1/2短按改为松手后执行以屏蔽错开组合的初始曝光误调。绿色1.0。LOCK仅表示WB编辑关闭，不等同生产配方有效或全面锁参。

WB请求32位含16位epoch和红蓝系数，系数真实变化时递增epoch。原生帧起始快照，AWB early SOF保存、首次乘法应用及首组旁路，帧中变化不改变本帧像素。统计/分类/边缘计数取消旧采样；视频继续输出。结果115位原子带WB标签，显示域核对请求/标签并排空旧邮箱、等新完整token。相机收/显、结果、诊断CDC分别81/82/115/84位，原低位布局保留，原约束通配符继续覆盖扩宽数据。HDMI显示实际已应用R/B及TUNE/LOCK，星号表示待生效；不是立即显示未生效请求。

## 仿真

同一冻结候选下两次运行：会话18732完成wb_controls/manual_wb/wb_epoch/controls四项，会话82816完成其余19项，均退出0。未复用旧候选测试作为本轮结果，未强制RAM输入、删断言或放宽看门狗。

| 测试 | 结果 |
|---|---|
{test_table}

manual_wb使用独立floor(pixel×code/64)/饱和参考、四lane随机RGB、5个4整行帧、帧前/帧中修改、首组像素、气泡/ready-low/复位/行尾；不将这项短帧单位测试称完整600行。roi_chain实际14帧1024×600，完整帧153600四像素拍/115200打包拍；新增帧中WB变化要求视频完整、采样取消、系数不变，下一完整帧标签/特征恢复。isp_writer_stop真实600行ISP/writer停止恢复和既有判定/Sobel/相机I2C全部回归。OSD沿用独立614400像素参考，再加LOCK/TUNE/最大值/星号/帧内变化等3幅全栅格；实际PPM转PNG已人工查看，无文字重叠。

## 构建审计

TD6.2.168116综合11905、物理81974退出0，bitgen完成。{statistics}。相对固定WB：Slice+79、LUT6+25、REG+346、ERAM不变、DSP+8。运行时乘法需要DSP，不能继续宣称可调版DSP0；相对原动态自动WB没有恢复整套场景累计/除法反馈。

31条max_delay定义/顺序不变、总匹配非0且ignored0、shadow分类相同；扩宽邮箱使匹配路径数增加，详见audit.json。dummy模型类别3→4，恢复8个AWB乘法器模式脚类别，除法器输出项仍未出现；LSLICE未连输出映射由FIFO同步级改为monitor payload[94]所在slice，monitor/FIFO源码未变，相关仿真通过，不等同逐物理引脚独立验收。其余13项覆盖分类相同。

综合124条警告标准化位置后完全相同；物理10条，其中既有PHY-5060时钟扇出307→419，1个数据/控制端不变，控制寄存器/邮箱扩宽增加时钟端，其余警告相同。原PLL反馈/时钟、I/O和例外限制保留。建立余量0.169ns较上一固定版0.895ns小，仍满足当前约束；STA92.59%不是100%覆盖，不能宣称全硬件可靠性已证实。

## 镜像、证据及后续

镜像：{metadata['release']['path']}，{bit.stat().st_size}字节，SHA-256 {sha(bit)}。current_codex_build指本轮冻结构建与source_snapshot。证据包含209生产输入、8项改前来源、23测试源码/日志、OSD资源及实际PNG、构建报告/bit/脚本、改前Git状态/资料、路线/上板说明/断点/哈希清单。原厂仿真库和工具流程另存路径/哈希；不复制巨型波形与编译库。

旧四组证据共{sum(audit['prior_evidence_copies'].values())}份哈希复核通过，旧固定WB和v3回退镜像保持原身份。先用本版固定照明、机位、EXP/GAIN，对中性白/灰参考手动调R/B，退出并记录；框外彩色即可观察，RAW只是便于对照。再取同位置有件/空穴配对，重选/验证阈值。每次上电默认R064/B064，没有掉电保存；选定系数后再按确认方案写启动值。

尚未验收实物颜色、组合键手感、长稳、冷启动、物理误报/漏检；旧门限和黑带门控未重新标定，黑桌面/孔/错位可能误判、透明带未支持。最近采样未绑定DDR显示帧；完整CAL失效/恢复、INVALID/UNCERTAIN、运行时物料配方、生产锁定尚未实现。
'''
record.with_suffix('.md').write_text(report,encoding='utf-8')
agents=root/'AGENTS.md'
prefix=read(agents).split('## 当前断点')[0]
agents.write_text(prefix+f'''## 当前断点（2026-10-09，可调白平衡代码/镜像已交付，待上板）

- **目标与断点**：用户授权实现可调WB；完成KEY1+KEY2长按约1秒切换，四键红蓝-/+，退出保持。普通状态保留曝光/GAIN；KEY1/2短按改为松手消抖后执行。默认064、范围032—192、步长1/64。框外彩色可调色，RAW仅方便对照；3528成像冻结及配对仍待完成。
- **分支/改动**：{branch}，HEAD{head}，source_commit=null，暂存区空，既有WIP与本轮未提交。相对固定WB R2只8项生产输入：ae_set/awb/isp_top/roi_observation_snapshot/roi_display_state/design_top_wrapper/experiment_osd/osd_ascii_rom；新增wb_controls/manual_wb/wb_epoch及既有接口/OSD/ROI回归，更新00/35/AGENTS。DDR/MIPI/ROI/Sobel门限未改。
- **行为**：32位WB含epoch及R/B，原生FS和AWB首组乘法边界生效；帧中变更撤销采样，视频继续。结果115位带标签，显示核对请求并等新完整token。既有CDC扩81/82/115/84位。HDMI显示实际系数、LOCK/TUNE、待生效星号。LOCK仅锁WB编辑，复位恢复R064/B064、2244/48，无Flash保存。
- **交付/证据**：{metadata['release']['path']}，{bit.stat().st_size}字节，SHA {sha(bit)}；README/SHA256/build_inputs/manifest完整。{metadata['validation_record']}及同名目录冻结209输入/69源、23测试/实际OSD栅格/报告/脚本/改前8项/资料。current_codex_build已指本轮，tmp/manual_wb_v1_td_20261009冻结不追改。
- **验证**：同一冻结候选四项18732加十九项82816共23项PASS、退出0。独立四lane色彩算术/限幅、组合/长按/恢复、真CDC epoch与停钟回返、HDMI全栅格通过；roi_chain14帧含WB帧中修改不丢视频与新整帧恢复。旧断言/时限/原厂RAM未降低或强制接零。SYN11905/PHY81974退出0/bitgen完成；{statistics}。31max_delay匹配/ignored0、约束未改；dummy类别3→4为8DSP乘法、映射悬空输出改变，其余13覆盖分类相同。综合124警告同前；物理10条、PHY-5060 clock fanout307→419但1个data/ctrl不变，其余诊断相同。
- **未决事项**：上板调色/按键、长稳/冷启动/准确率均待现场。改变WB后旧阈值需配对复核，黑背景/孔/错位可能误判、透明带不支持；最近采样非DDR显示帧绑定。全CAL/INVALID/UNCERTAIN/配方/生产锁定/掉电保存未实现。STA覆盖及原PLL/I/O/例外限制保留。
- **下一条操作**：用户按35烧交付bit，固定3528机位/照明/EXP/GAIN，用中性参考调R/B并退出、等待星号消失，记录参数与光学条件。检查视频计数、组合键/四键及复位；再发同位置有件/空穴配对。选定默认R/B和阈值后另按确认方案写入，不能凭手机照片猜校准值。
- **进程/设备**：本轮ModelSim18732/82816、TD11905/81974已结束；无助手构建/仿真在跑。旧复核代理为interrupted，不宣称本轮独立代理审计。用户TD/板卡未操作，无JTAG/Flash，无新聊天/自动任务。
- **提交/回退**：未提交未推送，暂存区空。本轮verification.json校验快照和镜像；旧四组证据{sum(audit['prior_evidence_copies'].values())}份保持。固定WB回退SHA{sha(rollback)}，v3回退SHA87703eeb66262a4ebecd6f27ea57be78c4993204396250d24c04604f52842398。未验收不称工业可靠版。
''',encoding='utf-8')
copies=[]
def copy(src,rel):
    dst=record/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    assert sha(dst)==sha(src)
    copies.append(dict(path=dst.relative_to(record).as_posix(),bytes=dst.stat().st_size,sha256=sha(dst)))
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for name in ['inputs.json','stage_inputs.json','simulation_inputs.json','preparation.json','build_audit.json','audit.json','simulation_execution.json']:
    copy(build/name,name)
copy(before/'inputs.json','before/inputs.json');copy(before/'git_status.txt','before/git_status.txt')
for rel in audit['changed_production_inputs']:copy(before/rel,Path('before/source_changes')/rel)
for p in (before/'documents').rglob('*'):
    if p.is_file():copy(p,Path('before/documents')/p.relative_to(before/'documents'))
for stage in ['syn_1','phy_1']:
    for p in (runs/stage).iterdir():
        if p.is_file() and p.suffix.lower() in {'.log','.logw','.rpt','.txt','.json','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:
            copy(p,Path('td_reports')/stage/p.name)
for e in load(build/'simulation_inputs.json'):copy(build/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
for e in audit['tests']:
    for p in (build/'sim/modelsim_work'/e['name']).glob('*.log'):copy(p,Path('simulation/logs')/e['name']/p.name)
for p in (build/'sim').glob('*.log'):copy(p,Path('simulation')/p.name)
for p in (build/'sim').glob('osd_wb_*_actual.png'):copy(p,Path('simulation/actual_raster')/p.name)
for name in ['prepare_manual_wb_20261009.py','implement_manual_wb_20261009.py','integrate_manual_wb_sim_20261009.py',
             'finish_manual_wb_tests_20261009.py','freeze_manual_wb_inputs_20261009.py','audit_manual_wb_20261009.py',
             'freeze_manual_wb_release_20261009.py','verify_manual_wb_release_20261009.py']:
    copy(root/'tmp'/name,Path('build_scripts')/name)
for p in [route,guide]:copy(p,Path('documents')/p.name)
copy(agents,'AGENTS_checkpoint.md');copy(record.with_suffix('.md'),'验收记录.md')
copy(project/'td_project/current_codex_build.json','current_codex_build.json');copy(release/'README.md','release_README.md')
vendor=Path('D:/AAA/FPGA.....YZW/sim_release')
vendor_names=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v','ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v']
data=dict(created_at=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),status='software_verified_board_pending',
    branch=branch,base_head=head,source_commit=None,commit_status='uncommitted_unpushed_workspace_snapshot',tool='TD6.2.168116',simulator='ModelSim2019.2',
    build_inputs_count=209,source_entries=69,bit=metadata['release'],audit=audit,rollback=dict(path=rollback.relative_to(root).as_posix(),sha256=sha(rollback)),
    vendor_model_hashes=[dict(path=str(vendor/n),sha256=sha(vendor/n)) for n in vendor_names],flow_sha256=sha(Path(metadata['flow'])),copies=copies)
dump(record/'manifest.json',data)
dump(release/'manifest.json',{k:v for k,v in data.items() if k!='copies'})
print(json.dumps(dict(record=str(record),release=str(release),copies=len(copies),bit=audit['bit']),ensure_ascii=True))
