from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, shutil, subprocess

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
build = root / 'tmp/dynamic_tracking_v1_r5_td_20261010'
first = root / 'tmp/dynamic_tracking_v1_r3_td_20261010'
retest = root / 'tmp/dynamic_tracking_v1_r4_td_20261010'
before = root / 'tmp/dynamic_tracking_v1_before_20261010'
record = root / '开发实施/验收记录/20261010_B3528动态追踪_轮次1'
release = project / 'release/dynamic_tracking_v1_20261010'
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p, data):
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
audit = load(build / 'audit.json')
assert audit['status'] == 'PASS_logic_and_build_only' and len(audit['tests']) == 29
assert not (record / 'manifest.json').exists() and not (release / 'manifest.json').exists()
if release.exists():
    assert sha(release / 'camera_to_dsi_display.bit') == audit['bit']['sha256']
if record.exists():
    assert load(record / 'audit.json') == audit
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=root, text=True).strip()
assert head == '3be3967f2457622566fb20b7cef3aa5038e7d885' and branch == 'lj4747-contest-work'
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=root, text=True).strip()
inputs = load(build / 'inputs.json')
for e in inputs:
    assert sha(build / e['path']) == e['sha256'] == sha(project / e['path']), e['path']
runs = build / 'td_project/camera_to_dsi_display_Runs'
bit = runs / 'phy_1/camera_to_dsi_display.bit'
assert sha(bit) == audit['bit']['sha256']
release.mkdir(exist_ok=True); record.mkdir(exist_ok=True)
shutil.copy2(bit, release / bit.name)
shutil.copy2(build / 'inputs.json', release / 'build_inputs.json')
(release / 'SHA256.txt').write_text(sha(bit) + '  ' + bit.name + '\n', encoding='ascii')
metadata = dict(syn=str(runs / 'syn_1'), phy=str(runs / 'phy_1'),
    flow='D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl', tool='D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe',
    td_version='6.2.168116', source_commit=None, base_head=head,
    source_snapshot=record.relative_to(root).as_posix() + '/source_snapshot',
    release=dict(path=(release / bit.name).relative_to(root).as_posix(), **audit['bit']),
    validation_record=record.with_suffix('.md').relative_to(root).as_posix())
t, a = audit['timing'], audit['resources']
statistics = (f"Routed慢/快角setup+{t['setup_wns_ns']:.3f}ns、hold+{t['hold_wns_ns']:.3f}ns，TNS0、违例终点0；"
    f"Slice{a['slice_used']}/{a['slice_total']}={a['slice_percent']:.2f}%，LUT6{a['lut6_used']}、REG{a['reg_used']}、"
    f"ERAM{a['eram_used']}、DSP{a['dsp_used']}；STA覆盖{t['sta_coverage_percent']:.2f}%")
identity = f"镜像{bit.stat().st_size}字节，SHA-256 `{sha(bit)}`。"
(release / 'README.md').write_text(f'''# 3528手动横移动态追踪 v1

正式镜像：camera_to_dsi_display.bit。{identity}

固定相机/光源、3528黑带白件、慢速手动横移；定位孔在器件上方，三条黄色搜索线Y212/220/228。首次器件中心对准512/300，参考孔约对准黄色十字464/220；记录初始孔相位，80×80核心框随水平位移更新。连续两帧有效采集锁定，空穴也可定位；失锁/遮挡/越界显示TRACK WAIT与待检测，隐藏青框。相机停更、旧显示槽重复约115ms也撤销旧结论。孔必须亮且有暗边，需看见相邻孔；试用孔距96±24、宽20—64、每帧搜索±16像素，均待现场测定。快速整孔距跳跃可能认错相邻孔，不保证穴位身份，不含电机/编号/NG/停车。

保留曝光、增益、手动R/B及四种视图。KEY1+KEY2长按约1秒进/退WB TUNE，四键调红蓝-/+；复位EXP2244/GAIN48/R064/B064，无掉电保存。MEAN与EDGE独立判定；定位门限不代替分类门限。框、统计及结果跟随DDR完整帧槽一起切换。物理分类阈值尚未验收，不能凭追踪成功判有件/空穴精度合格。

29项仿真通过（R3/R4中27项实际编译源与R5同哈希，R5重跑2项OSD；旧测试仅端口适配修复，原断言不变），210生产输入/70源。{statistics}。34max_delay均匹配、ignored0；124综合/10物理警告同上一版，旧PLL/I/O/例外及STA未覆盖限制保留。未提交、未推送、未烧板；现场跟随、左中右配对、分类准确率、速度、冷启动和长稳待测。

上板说明：开发实施/38_B3528手动横移动态追踪_上板说明.md。证据：{metadata['validation_record']}及同名目录。静态回退：../manual_wb_tuning_v1_20261009/camera_to_dsi_display.bit，SHA {audit['rollback_sha256']}。
''', encoding='utf-8')
guide = root / '开发实施/38_B3528手动横移动态追踪_上板说明.md'
s = guide.read_text(encoding='utf-8')
s = s.replace('用户已授权实现；软件验证进行中，尚未上板。正式镜像身份和验证结论将在构建通过后补入本节，当前不要用中间构建验收。',
    f"代码、29项仿真、综合与布局布线已通过；尚未上板。正式镜像：`{metadata['release']['path']}`。\n\n{identity}\n\n{statistics}。完整证据：`{metadata['validation_record']}`及同名目录；冻结未提交工作区，未推送。")
guide.write_text(s, encoding='utf-8')
plan = root / '开发实施/37_B3528手动横移动态追踪_待确认方案.md'
s = plan.read_text(encoding='utf-8').replace('实现和软件验证进行中，上板未验收。',
    '代码、29项仿真与综合/布局布线已通过；见38上板说明与20261010_B3528动态追踪_轮次1验收记录，上板未验收。')
plan.write_text(s, encoding='utf-8')
table = '\n'.join('| ' + e['name'] + ' | PASS | ' + ('R5' if 'r5_' in e['build_root'] else 'R3' if 'r3_' in e['build_root'] else 'R4') + ' |' for e in audit['tests'])
record.with_suffix('.md').write_text(f'''# B3528动态追踪 — 轮次1

用户授权实现慢速手动水平追踪。软件逻辑和本机构建通过，实物未验收；未烧板、未提交、未推送。分支{branch}，HEAD{head}，source_commit=null。210生产输入/70源冻结工作区；生产来源R5；R3/R4生产输入同哈希，R5仅补绘OSD状态文字区域，所有引用测试的实际编译源逐项校验与R5一致。

## 改动与边界

相对20261009可调WB版变化11项生产输入：{', '.join(audit['changed_production_inputs'])}。新增三行局部孔扫描与同帧ROI位移、完整帧元数据、显示过期保护；既有灰度/边缘判定门限和算术、MIPI/DDR IP/打包、按键、WB默认值不变。仅水平追踪，固定80×80框和Y；孔带在核心上方。两帧建立锁定，初始参考孔到器件相位由手动对准建立，不自动定位器件中心。

候选需暗边、宽度/间距/三行形状与局部位移可信；失锁待检测。元数据含EXP/GAIN、WB/视图标签、坐标、统计及分类，摄像epoch一致且完整像素写完才发布，DDR选图同步选择其元数据，OSD在首个DE锁存。相机停更时约115ms重复显示槽过期，不保留旧判定。周期孔整孔距突跳可能混淆，不保证工业穴位身份；未加入电机、编号、NG或停车。

## 冻结仿真、失败与复测

R3会话17765先通过前10项，随后presence_modes失败：旧位置连接把scene_ok接到了新增dynamic_x0，输出悬空z。R2/R3原始失败编译/仿真日志保留；仅将该测试改为命名连接并明确静态动态输入0，原断言、样本、门限、原厂模型及看门狗不变。R4会话84897冻结复测剩余19项。R3/R4生产输入完全一致，模拟输入只该一份适配文件变化。查看真实PPM栅格又发现TRACK文字虽有字模选择却未启用绘制区域；R5仅修OSD panel使能，新增状态文字逐像素断言，重跑tracking_osd/osd并重新综合/布局布线。其余27项实际编译源哈希均与R5一致，才引用原结果；不重用旧WB发布版结果充当本轮测试。

| 测试 | 结果 | 冻结来源 |
|---|---|---|
{table}

专项测试包含真实RAW10/重建/原厂ERAM/WB/Sobel/除法器十帧，同帧动态ROI独立6400像素统计、四视图、有件/空穴和失锁恢复；首帧为原有重建行跨度预热。动态Sobel独立二维像素参考覆盖不对齐ROI、横/竖/斜/彩色/气泡/取消/复位；孔追踪覆盖双向/暂停/空穴/遮挡/步长超限/歧义/错距/错形。元数据测试异步三时钟、延迟结果、旧active槽保护、坏帧不发布；OSD三幅完整614400像素栅格验证VS后到达的坐标、帧中不跳框、失锁隐藏。原23项视频/CSI/I2C/ROI/按键/WB/OSD回归全部通过。

早期定位done残留及孔/器件相位错误已修复；初始真实ISP测试预热断言修正原因在development_notes.md。工作区最早失败日志被探索覆盖，未声称全部原始失败已保存；正式R2/R3测试接口失败日志及最终复测完整保存。软件合成样本不代表现场分类准确率。

## 资源与时序

TD6.2.168116：最终R5综合46674、物理会话见simulation_execution.json均退出0，bitgen完成。{statistics}。相对可调WB增加Slice{a['slice_used']-12239}、LUT6{a['lut6_used']-10464}、REG{a['reg_used']-12445}，ERAM/DSP不变。未新增整帧RAM、浮点/像素级可变除法，不修改时钟来通过。

34条max_delay匹配、ignored0；替换3条被优化掉的旧ROI邮箱约束，新增6条相机元数据/active帧元数据邮箱约束，原FIFO约束保留。124综合/10物理警告与上一版标准化后完全相同；14覆盖分类同基线，dummy仍4模型类别、LSLICE未连输出映射到CSI有效寄存器u_csi_unpacket/csi_valid_r_reg_syn_3.ofb（旧映射到monitor payload）；CSI/FIFO源码未变，相关回归通过，不代表逐物理引脚独立验收。STA{t['sta_coverage_percent']:.2f}%不是100%覆盖，原PLL/I/O/例外限制未解决。

## 镜像与后续

正式镜像：{metadata['release']['path']}。{identity} 旧可调WB静态镜像及{audit['prior_evidence_copies']}份证据副本哈希核对保持。源码/脚本/测试/源清单/失败与复测/报告/bit/说明/断点均冻结，未复制大型编译库与波形。原厂仿真库、工具流程记录路径及哈希。

下一步按38说明摆放、锁定成像条件，先验慢速跟随同穴及失锁保护，再采同位置有件/空穴的静止/左中右移动配对。试用几何与灰度阈值、跨位置色差影响、误报/漏检、最大速度、冷启动和长稳仍待人确认；完整配方/CAL/INVALID/UNCERTAIN/Flash保存未实现。不要把本版称工业可靠版。
''', encoding='utf-8')
copies = []
def copy(src, rel):
    dst = record / rel; dst.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(src, dst)
    copies.append(dict(path=dst.relative_to(record).as_posix(), bytes=dst.stat().st_size, sha256=sha(dst)))
for e in inputs:
    copy(build / e['path'], Path('source_snapshot') / e['path'])
for name in ['inputs.json', 'stage_inputs.json', 'simulation_inputs.json', 'audit.json', 'development_notes.md']:
    copy(build / name, name)
copy(retest / 'simulation_inputs.json', 'simulation/r4_inputs.json')
copy(first / 'simulation_inputs.json', 'simulation/r3_inputs.json')
copy(first / 'inputs.json', 'simulation/r3_production_inputs.json')
copy(retest / 'inputs.json', 'simulation/r4_production_inputs.json')
copy(first / 'user_source/hdl_source/experiment_osd.v', 'simulation/before_label_fix/experiment_osd.v')
copy(build / 'simulation_execution.json', 'simulation_execution.json')
copy(before / 'inputs.json', 'before/inputs.json')
for rel in audit['changed_production_inputs']:
    if (before / rel).exists(): copy(before / rel, Path('before/source_changes') / rel)
for stage in ['syn_1', 'phy_1']:
    for p in (runs / stage).iterdir():
        if p.is_file() and p.suffix.lower() in {'.log', '.logw', '.rpt', '.txt', '.status', '.qor', '.area', '.tcl', '.prj', '.cfg', '.timing', '.bit', '.f'}:
            copy(p, Path('td_reports') / stage / p.name)
for e in load(build / 'simulation_inputs.json'):
    copy(build / e['path'], Path('simulation/source') / Path(e['path']).relative_to('sim'))
for e in audit['tests']:
    for p in (root / e['build_root'] / 'sim/modelsim_work' / e['name']).glob('*.log'):
        copy(p, Path('simulation/logs') / e['name'] / p.name)
for version in ['r2', 'r3']:
    failed = root / f'tmp/dynamic_tracking_v1_{version}_td_20261010/sim'
    for p in (failed / 'modelsim_work/presence_modes').glob('*.log'):
        copy(p, Path('simulation/failures') / version / p.name)
    copy(failed / 'tb_presence_modes.v', Path('simulation/failures') / version / 'tb_presence_modes.v')
for b, label in [(first, 'r3'), (retest, 'r4'), (build, 'r5')]:
    for p in (b / 'sim').glob('*.log'): copy(p, Path('simulation') / label / p.name)
    marker = b / 'sim/regression_exit_code.txt'
    if marker.exists():
        copy(marker, Path('simulation') / label / 'regression_exit_code.txt')
    else:
        assert label == 'r3'  # Failed batch has console evidence, but no separate exit marker.
for p in (retest / 'sim').glob('osd_wb_*_actual.png'):
    copy(p, Path('simulation/actual_raster') / p.name)
visual=root/'tmp/tracking_visual_r5_20261010'
for rel in ['notes.json','sim/tb_tracking_osd.v','sim/visual_exit_code.txt','sim/visual_console.log','sim/modelsim_work/tracking_osd/compile.log','sim/modelsim_work/tracking_osd/console.log']:
    copy(visual/rel,Path('simulation/visual')/rel)
for p in (visual/'sim').glob('tracking_*.png'):copy(p,Path('simulation/visual')/p.name)
for p in (root/'tmp/tracking_visual_20261010/sim').glob('tracking_*.png'):copy(p,Path('simulation/before_label_fix')/p.name)
for name in ['prepare_tracking_build_20261010.py', 'audit_tracking_20261010.py', 'freeze_tracking_release_20261010.py']:
    copy(root / 'tmp' / name, Path('build_scripts') / name)
for p in [guide, plan, record.with_suffix('.md')]: copy(p, Path('documents') / p.name)
checkpoint = root / 'AGENTS.md'
s = checkpoint.read_text(encoding='utf-8'); s = s[:s.index('## 当前断点')] + f'''## 当前断点（2026-10-10，3528手动横移动态追踪v1软件完成，上板待验）

- **目标/断点**：用户已授权并完成3528黑带白件单穴慢速手动水平追踪；孔在器件上方，先同帧定位再分类，空穴也定位，失锁/停更待检测。固定相机/光源、首次器件中心512/300、参考孔464/220；三行212/220/228，孔初始相位+水平位移，80×80/Y固定。现场摆放问题未获答复，以上为本版使用条件，不等于现场安装已确认。
- **分支/来源**：{branch}，HEAD{head}，source_commit=null、暂存区空，既有WIP保留。生产冻结tmp/dynamic_tracking_v1_r5_td_20261010，210输入/70源；R3/R4生产同哈希，R5仅补绘OSD状态区域，其余27项测试依赖均同R5，2项OSD重跑。新增tracker和6测试，修改动态ROI/OSD、ISP、video_in/out/顶层、.al/.sdc、run_modelsim及presence_modes测试连接；11生产输入相对manualWB变化。
- **验证/证据**：29项PASS（R3中9+R4中18+R5中2）；旧位置连接失败日志保留，原断言不变。R5综合46674/物理会话见simulation_execution.json，均退出0；{statistics}。34max_delay匹配/ignored0，124/10警告同基线，原PLL/I/O限制保留。正式记录{metadata['validation_record']}及同名目录、source_snapshot/manifest；旧{audit['prior_evidence_copies']}证据副本及回退SHA保持。
- **镜像**：{metadata['release']['path']}；{bit.stat().st_size}字节，SHA {sha(bit)}。current_codex_build指本版来源；未烧板。
- **未决限制**：试用亮120/暗100、孔距96±24、宽20—64、步长16像素/输入帧须实测；垂直固定/孔上方，误差和速度未验收。重复孔整孔距突跳可能串穴，无穴位身份保证/编号/电机/NG。3528同穴有件空穴配对、左中右色差影响、参数冻结、分类准确率、冷启动和长稳未验证。MEAN/EDGE独立且阈值试用；RAW经重建/WB。无全配方CAL/INVALID/UNCERTAIN/Flash，WB LOCK仅关闭WB编辑。
- **下一条操作**：按38上板说明，仅下载正式SHA镜像；孔上方三行对准、两帧锁定→静止/慢左/慢右/暂停跟同穴→遮挡/越界/停更撤旧结论→同穴左中右有件/空穴配对。先记录孔距/宽度/Y/灰度、成像参数和容许误差；不凭软件PASS宣称实物可靠。现场不满足上方孔带条件须调整方案。
- **进程/设备**：最终R5综合46674/物理及OSD59606结束0，R4回归84897结束0；R3回归17765/R2回归16616旧测试连接失败结束1；R2综合19270、R1探索81165、专项43856已结束。未操作JTAG/Flash/板卡，无代理/新聊天/自动任务。
- **提交/回退**：未提交未推送、暂存区空。静态manualWB回退SHA{audit['rollback_sha256']}；固定WB SHA6905dcab92595971b25232775e75582f1d790896a310371edd50a7dd047e76e1、v3 SHA87703eeb66262a4ebecd6f27ea57be78c4993204396250d24c04604f52842398。
'''
checkpoint.write_text(s, encoding='utf-8'); copy(checkpoint, 'AGENTS_checkpoint.md')
dump(project / 'td_project/current_codex_build.json', metadata)
copy(project / 'td_project/current_codex_build.json', 'current_codex_build.json')
copy(release / 'README.md', 'release_README.md')
vendor = Path('D:/AAA/FPGA.....YZW/sim_release')
vendor_names = ['common/al_map_basic.v', 'common/al_map_lut.v', 'common/al_map_adder.v', 'common/al_phy_glbl.v', 'ph1p/ph1p_logic_eram.v', 'ph1p/ph1p_phy_gsr.v']
data = dict(created_at=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),
    status='software_verified_board_pending', branch=branch, base_head=head, source_commit=None,
    commit_status='uncommitted_unpushed_workspace_snapshot', tool='TD6.2.168116', simulator='ModelSim2019.2',
    build_inputs_count=210, source_entries=70, bit=metadata['release'], audit=audit,
    rollback=dict(path='fpga/component_inspector/release/manual_wb_tuning_v1_20261009/camera_to_dsi_display.bit', sha256=audit['rollback_sha256']),
    vendor_model_hashes=[dict(path=str(vendor/n), sha256=sha(vendor/n)) for n in vendor_names],
    flow_sha256=sha(Path(metadata['flow'])), copies=copies)
dump(record / 'manifest.json', data)
dump(release / 'manifest.json', {k:v for k,v in data.items() if k != 'copies'})
for e in copies:
    assert sha(record / e['path']) == e['sha256'] and (record / e['path']).stat().st_size == e['bytes']
assert sha(release / bit.name) == audit['bit']['sha256']
print(json.dumps(dict(record=str(record), release=str(release), copies=len(copies), bit=audit['bit']), ensure_ascii=False))
