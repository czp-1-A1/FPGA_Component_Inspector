from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, shutil, subprocess

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
first = root / 'tmp/fixed_wb_tuning_td_20261009'
build = root / 'tmp/fixed_wb_tuning_r2_td_20261009'
before = root / 'tmp/fixed_wb_tuning_before_20261009'
record = root / '开发实施/验收记录/20261009_A固定白平衡调参版_轮次1'
release = project / 'release/fixed_wb_tuning_v1_20261009'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: p.read_text(encoding='utf-8-sig')
load = lambda p: json.loads(read(p))
dump = lambda p, d: p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
def document(path, text):
    path.write_bytes(text.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-8'))

audit = load(build / 'audit.json')
assert audit['status'] == 'PASS_logic_and_build_only' and len(audit['tests']) == 11
assert not record.exists() and not record.with_suffix('.md').exists() and not release.exists()
inputs = load(build / 'inputs.json')
for e in inputs:
    assert sha(build / e['path']) == e['sha256'] == sha(project / e['path']), e['path']
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=root, text=True).strip()
assert head == '3be3967f2457622566fb20b7cef3aa5038e7d885' and branch == 'lj4747-contest-work'
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=root, text=True).strip()
syn = build / 'td_project/camera_to_dsi_display_Runs/syn_1'
phy = syn.parent / 'phy_1'
bit = phy / 'camera_to_dsi_display.bit'
assert sha(bit) == audit['bit']['sha256']
rollback = project / 'release/presence_modes_v3_20261008/camera_to_dsi_display.bit'
assert sha(rollback) == '87703eeb66262a4ebecd6f27ea57be78c4993204396250d24c04604f52842398'
record.mkdir(); release.mkdir()
copies = []
def copy(src, relative):
    dst = record / relative
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    assert sha(dst) == sha(src)
    copies.append(dict(path=dst.relative_to(record).as_posix(), bytes=dst.stat().st_size, sha256=sha(dst)))

for e in inputs:
    copy(build / e['path'], Path('source_snapshot') / e['path'])
for name in ['inputs.json', 'stage_inputs.json', 'preparation.json', 'audit.json']:
    copy(build / name, name)
    if name != 'audit.json': copy(first / name, Path('attempt1') / name)
# Attempt1 differs only in AWB. All other inputs resolve to final source_snapshot.
copy(first / 'user_source/hdl_source/awb.v', 'attempt1/source_changes/user_source/hdl_source/awb.v')
copy(before / 'inputs.json', 'before/inputs.json')
for name in ['awb.v', 'isp/isp_top.v']:
    copy(before / 'user_source/hdl_source' / name, Path('before/source_changes/user_source/hdl_source') / name)
copy(before / 'td_project/current_codex_build.json', 'before/current_codex_build.json')
for p in (before / 'documents').rglob('*'):
    if p.is_file(): copy(p, Path('before/documents') / p.relative_to(before / 'documents'))
for attempt, label in [(first, 'attempt1'), (build, 'final')]:
    stages = attempt / 'td_project/camera_to_dsi_display_Runs'
    for name in ['syn_1', 'phy_1']:
        for p in (stages / name).iterdir():
            if p.is_file() and p.suffix.lower() in {'.log', '.logw', '.rpt', '.txt', '.status', '.qor', '.area', '.tcl', '.prj', '.cfg', '.timing', '.bit', '.f'}:
                copy(p, Path('td_reports') / label / name / p.name)
    for p in (attempt / 'sim').glob('*.log'):
        copy(p, Path('simulation') / label / p.name)
    names = [e['name'] for e in audit['tests']] if label == 'attempt1' else ['fixed_wb', 'pixel_interface', 'isp_writer_stop', 'roi_chain']
    for name in names:
        for p in (attempt / 'sim/modelsim_work' / name).glob('*.log'):
            copy(p, Path('simulation') / label / 'model_logs' / name / p.name)
for p in (build / 'sim').iterdir():
    if p.is_file() and p.suffix.lower() in {'.v', '.py', '.ps1', '.md', '.do'}:
        copy(p, Path('simulation/source') / p.name)
for p in (build / 'sim/osd_assets').rglob('*'):
    if p.is_file(): copy(p, Path('simulation/source/osd_assets') / p.relative_to(build / 'sim/osd_assets'))
for name in ['prepare_fixed_wb_tuning_20261009.py', 'freeze_fixed_wb_inputs_20261009.py',
             'prepare_fixed_wb_tuning_r2_20261009.py', 'audit_fixed_wb_tuning_20261009.py',
             'freeze_fixed_wb_tuning_20261009.py', 'verify_fixed_wb_tuning_20261009.py']:
    copy(root / 'tmp' / name, Path('build_scripts') / name)

shutil.copy2(bit, release / bit.name)
shutil.copy2(build / 'inputs.json', release / 'build_inputs.json')
(release / 'SHA256.txt').write_text(sha(bit) + '  ' + bit.name + '\n', encoding='ascii')
metadata = dict(syn=str(syn), phy=str(phy), flow='D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl',
                tool='D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe', td_version='6.2.168116',
                source_commit=None, base_head=head,
                source_snapshot=record.relative_to(root).as_posix() + '/source_snapshot',
                release=dict(path=(release / bit.name).relative_to(root).as_posix(), **audit['bit']),
                validation_record=record.with_suffix('.md').relative_to(root).as_posix())
dump(project / 'td_project/current_codex_build.json', metadata)
t, a = audit['timing'], audit['resources']
statistics = f"Routed慢/快角setup+{t['setup_wns_ns']:.3f}ns、hold+{t['hold_wns_ns']:.3f}ns，TNS0、违例终点0；Slice{a['slice_used']}/{a['slice_total']}={a['slice_percent']:.2f}%，LUT6{a['lut6_used']}、REG{a['reg_used']}、ERAM{a['eram_used']}、DSP{a['dsp_used']}；STA覆盖{t['sta_coverage_percent']:.2f}%"
document(release / 'README.md', f'''# 固定白平衡调参试验版 v1

烧录本目录camera_to_dsi_display.bit；实际交付采用R2源。红、蓝增益固定1.0，曝光/增益按键保留，启动2244/48仅为调参起点。新成像条件须重新采样，旧门限尚未验收；运行时配方及新CAL/INVALID/UNCERTAIN管理未实现。

SHA-256：{sha(bit)}。{bit.stat().st_size}字节，TD6.2.168116，209输入/69工程源，未提交工作区快照。仅AWB与isp_top两项生产输入相对前一交付改变。

首轮11项仿真全部PASS；首轮综合新增两条HDL-7238关键警告，镜像不交付。R2改为generate常量连线，相关4项fixed_wb/pixel_interface/isp_writer_stop/roi_chain复测PASS，另外7项测试输入完全不变并复用首轮PASS。两轮测试源码/断言均未修改，原厂ERAM模型无强制接零。最终综合/物理退出0，警告与前一交付比较无新增。

{statistics}。31条max_delay均匹配、ignored0；dummy模型类别4→3（AWB DSP/除法器项消失、LSLICE未连接输出映射改变），其余13项覆盖分类相同。原PLL/I/O/覆盖限制保留，不代表所有路径已约束。

先按开发实施/34_A固定白平衡调参版_上板说明.md固定3528位置/光源，检查四视图更新，再调EXP/GAIN，冻结条件后发同位置有件/空穴照片。原MEAN58、EC48/96、GS16384/32768和黑带门控仍为试验值。没有上板/长稳/冷启动/准确率验收。

证据：{metadata['validation_record']}及同名目录。回退：../presence_modes_v3_20261008/camera_to_dsi_display.bit，SHA {sha(rollback)}。本轮未提交、未推送。
''')
report = f'''# A固定白平衡调参版 — 轮次1

用户已确认修订路线并授权第一步。最终结果为逻辑/构建验证通过、上板与成像验收待测；采用R2镜像，不使用首轮存在新增关键综合警告的镜像。无JTAG/Flash操作，无提交/推送。

分支{branch}，HEAD{head}；未提交209生产输入/69工程源。相对presence_modes_v3只有根awb.v和isp/isp_top.v两项生产变化：固定红蓝1.0以稳定检测输入；AWB默认自动路径保留作对照，原四像素/缓存/行帧同步保持，EXP/GAIN按键、ROI、门限及判定显示未改。新增tb_fixed_wb与runner条目；00/33路线已确认，34为上板步骤。

## 两次构建与测试

首轮11项全部PASS：fixed_wb、presence_modes、isp_writer_stop、observation、stop_recovery、display_state、controls、osd、pixel_interface、classifier、roi_chain。固定背景变化试验采用完整行和20拍不变ROI，独立检查固定1.0及R1.5/B0.5算术和饱和；实际自动AWB阳性对照2304拍输出变化。涵盖四lane、气泡、ready-low、复位及行尾；完整1024×600/12帧由roi_chain验证，isp_writer_stop验证真实ISP600行和配置epoch停止恢复。OSD独立614400像素参考、按键消抖/长按/相机配置、判定与CDC回归保留。

首轮综合/物理均退出0，但新增两条HDL-7238“assignment under multiple clock edges”关键警告，来自固定增益时钟过程的常量赋值。首轮不接受为交付镜像，源码、bit、报告和11项日志保留。R2仅把该固定路径改为generate常量连线，原自动增益时序保持；新隔离快照下AWB相关4项全部复测PASS。其余7项不引用AWB/ISP，各自RTL/测试/资源字节未变，复用首轮日志并校验，不宣称11项在R2同一运行中重跑。未修改测试断言、时限或RAM模型来通过。

R2综合/物理退出0、bitgen完成。{statistics}。相对v3资源增量：{json.dumps(audit['resource_delta_v3'], ensure_ascii=False)}。31条max_delay顺序/定义一致、匹配非0、ignored0，shadow类别未变；dummy模型类别4→3，AWB DSP模式脚/除法器未连接输出消失，LSLICE未连接输出映射变为读FIFO指针同步级所在slice的ofa，FIFO RTL字节未改，相关ISP/writer回归通过；其余13项覆盖分类相同，不宣称每个物理引脚均独立验证。综合{audit['warnings']['syn_1']['lines']}条/物理{audit['warnings']['phy_1']['lines']}条警告标准化比较无新增。STA比例下降需结合逻辑删减理解，不能把时序余量提高当成全路径覆盖；原PLL反馈/频率、I/O延迟及例外限制未解决。

## 交付与可复现证据

镜像：{metadata['release']['path']}，{bit.stat().st_size}字节，SHA-256 {sha(bit)}。current_codex_build已指R2与冻结源码；source_commit为null，不能称对应已提交新版本。前一v3回退SHA不变，666份旧主证据及11份前轮计划证据校验通过。

证据包含209最终源码、两轮TD配置/报告/bit、首轮11项及R2相关4项日志、统一测试源码/runner/字模、改前资料、构建/校验脚本、路线/上板说明/断点/当前元数据和哈希清单。首轮重建时：按attempt1/inputs.json，以attempt1/source_changes中的awb.v替换最终source_snapshot，其余208项相同；改前重建用before/source_changes两项替换，其余207项相同。原厂仿真库另记录绝对路径及哈希，未复制安装库和巨大波形文件。

## 现场边界与下一步

固定1.0仅为调参试验起点；EXP2244/GAIN48非最终参数。原MEAN58、EC48/96、GS16384/32768、暗条灰度100/75%均未在新成像下配对标定。黑背景、孔或错误ROI可通过门控；透明带尚不适用，当前显示最近采样且未绑定DDR显示帧。运行时配方、验证身份失效、独立INVALID/UNCERTAIN、生产锁定未实现；A未全验收。

用户按34说明固定3528相机/载带/照明，对准青框单穴；先验证四模式连续更新，再单项调EXP/GAIN，记录光源、约130mm距离/对焦、参数及配对真值/照片/MEAN/EC/GS。冻结条件后用独立穴位选择与验证规则，最终参数由用户确认，再进入3528运行时参数化；不同时扩展另外两类。
'''
document(record.with_suffix('.md'), report)
agents = root / 'AGENTS.md'
prefix = read(agents).split('## 当前断点')[0]
document(agents, prefix + f'''## 当前断点（2026-10-09，固定白平衡调参版已交付，待上板）

- **目标与断点**：用户确认修订路线；完成第一步固定WB调参版，红蓝1.0仅试验起点，成像/门限待测。路线为3528闭环→仅3528运行时参数回归→三份预置换型→现场写入后新型号测试→B/C；后续功能未实现。
- **分支/改动**：{branch}，HEAD{head}，暂存区空，未提交209输入/69源快照。仅awb.v与isp_top.v相对v3改变：generate固定增益连线，默认自动路径保留，像素同步/缓存/四lane及EXP/GAIN按键保持。新增tb_fixed_wb与runner，更新00/33/34/AGENTS；ROI、门限、分类、OSD未改。
- **交付与证据**：{metadata['release']['path']}，{bit.stat().st_size}字节，SHA {sha(bit)}；release有README/SHA256/build_inputs/manifest。{metadata['validation_record']}和同名目录冻结两轮报告/日志、209最终源码、首轮AWB差异、前快照差异及脚本/断点/说明；current_codex_build已指R2，source_commit=null。
- **验证/修正**：首轮11项仿真PASS，但综合新增2条HDL-7238关键警告，首轮镜像不交付。仅将固定寄存器常量赋值改为generate常量连线，R2相关4项fixed_wb/pixel_interface/isp_writer_stop/roi_chain重测PASS；7项不含AWB/ISP且字节未变，复用首轮记录，未改断言/时限/原厂RAM。实际自动WB阳性对照2304拍变化，固定ROI红蓝背景不变，非1.0独立算术/饱和及整帧链路通过。
- **资源/时序**：TD6.2.168116两阶段退出0、bitgen完成；{statistics}。31条max_delay匹配/ignored0、shadow相同；dummy模型类别4→3，AWB项消失、FIFO所在LSLICE未连接输出映射改变，原FIFO字节未改，相关回归PASS；其余13项覆盖分类相同。警告对v3无新增，原PLL/I/O/例外限制未解决。
- **扩展约定**：配方与工艺分开，调试/生产及判定/视图分离；关键修改使调试副本CAL失效，保留已验证原配方，完整恢复且工艺匹配可恢复资格。INVALID/WAIT/UNCERTAIN分别处理，不关停视频。初期80×80受限位置，algorithm_mode有限规则；预置表仅证明预置换型，第四型号须先有写参数能力，Flash持久保存独立验收。切换等待相机实际生效和新完整帧；A不宣称自动穴位定位。
- **未决事项**：无上板/长稳/冷启动/物理准确率验收。固定WB1.0、2244/48与旧T58/EC/GS/暗条门限均未选定为生产配方；黑背景/孔/错位可误判，高增益可待检测，透明带不支持，最近采样未绑定显示帧。运行时配方/CAL新规则/INVALID/UNCERTAIN/生产锁定未实现。
- **下一条操作**：用户按34烧新bit并固定3528位置/光源，先查RAW/GRAY/EDGE/BOTH更新，再逐项调EXP/GAIN；同位置有件/空穴发照片与真值/参数/MEAN/EC/GS，冻结成像后独立验证，最终门限另确认后实施。
- **进程/设备**：首轮ModelSim38083/TD SYN86591/PHY70515及R2 ModelSim70951/SYN63228/PHY42654均结束；无助手TDCLI/仿真在跑。用户TD/bw窗口与板卡未操作，无JTAG/Flash；无新代理/聊天/自动任务。两个tmp构建目录已冻结，不边测边改。
- **提交/回退**：本轮及此前WIP未提交未推送，暂存区空。v3回退SHA {sha(rollback)}不变，旧666份主证据及前轮11份计划证据保留；完整性见本轮verification.json，未验收不称工业可靠版本。
''')
for relative in ['开发实施/00_分阶段开发与逐级验证路线.md', '开发实施/33_A3528成像冻结与物料配方实施方案.md', '开发实施/34_A固定白平衡调参版_上板说明.md']:
    p = root / relative
    document(p, read(p))
    copy(p, Path('documents') / p.name)
copy(agents, 'AGENTS_checkpoint.md')
copy(record.with_suffix('.md'), '验收记录.md')
copy(project / 'td_project/current_codex_build.json', 'current_codex_build.json')
copy(release / 'README.md', 'release_README.md')
vendor = Path('D:/AAA/FPGA.....YZW/sim_release')
vendor_names = ['common/al_map_basic.v', 'common/al_map_lut.v', 'common/al_map_adder.v', 'common/al_phy_glbl.v', 'ph1p/ph1p_logic_eram.v', 'ph1p/ph1p_phy_gsr.v']
data = dict(created_at=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),
            status='software_verified_board_pending', branch=branch, base_head=head, source_commit=None,
            commit_status='uncommitted_unpushed_workspace_snapshot', tool='TD6.2.168116', simulator='ModelSim2019.2',
            build_inputs_count=209, build_inputs_sha256=sha(build / 'inputs.json'),
            changed_production_inputs=audit['changed_production_inputs'], bit=metadata['release'], audit=audit,
            rollback=dict(path=rollback.relative_to(root).as_posix(), sha256=sha(rollback)),
            vendor_model_hashes=[dict(path=str(vendor / n), sha256=sha(vendor / n)) for n in vendor_names],
            flow_sha256=sha(Path(metadata['flow'])), copies=copies)
dump(record / 'manifest.json', data)
dump(release / 'manifest.json', {k: v for k, v in data.items() if k != 'copies'})
print(json.dumps(dict(record=str(record), release=str(release), copies=len(copies), bit=audit['bit']), ensure_ascii=True))
