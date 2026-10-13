from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,shutil,subprocess

root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
build=root/'tmp/tracking_late_r1_td_20261011'
tests=root/'tmp/tracking_late_r3_td_20261011'
before=root/'tmp/tracking_late_before_td_20261011'
visual=root/'tmp/tracking_late_visual_td_20261011'
record=root/'开发实施/验收记录/20261011_B下方定位孔追踪修订_轮次1'
release=project/'release/tracking_lower_holes_v1_20261011'
guide=root/'开发实施/39_B3528下方定位孔追踪与诊断_上板说明.md'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def dump(p,data):p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

audit=load(tests/'audit.json')
assert audit['status']=='PASS_logic_and_build_only' and len(audit['tests'])==32
assert not (record/'manifest.json').exists() and not (release/'manifest.json').exists()
inputs=load(build/'inputs.json');assert inputs==load(tests/'inputs.json') and len(inputs)==210
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
branch=subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip()
assert head=='3be3967f2457622566fb20b7cef3aa5038e7d885' and branch=='lj4747-contest-work'
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
runs=build/'td_project/camera_to_dsi_display_Runs';bit=runs/'phy_1/camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256'] and bit.stat().st_size==audit['bit']['bytes']
assert (visual/'sim/visual_exit_code.txt').read_text().strip()=='0'
notes=load(visual/'visual_notes.json')
assert notes['source_sha256']==sha(project/'sim/tb_tracking_osd.v')
assert notes['modified_testbench_sha256']==sha(visual/'sim/tb_tracking_osd.v')
for e in notes['rasters']:assert sha(visual/e['path'])==e['sha256']
release.mkdir(parents=True,exist_ok=True);record.mkdir(parents=True,exist_ok=True)
shutil.copy2(bit,release/bit.name);shutil.copy2(build/'inputs.json',release/'build_inputs.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
metadata=dict(syn=str(runs/'syn_1'),phy=str(runs/'phy_1'),
 flow='D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl',tool='D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe',td_version='6.2.168116',
 source_commit=None,base_head=head,source_snapshot=record.relative_to(root).as_posix()+'/source_snapshot',
 simulation_root=tests.relative_to(root).as_posix(),release=dict(path=(release/bit.name).relative_to(root).as_posix(),**audit['bit']),
 validation_record=record.with_suffix('.md').relative_to(root).as_posix())
t=audit['timing'];a=audit['resources']
statistics=(f"Routed慢/快角setup+{t['setup_wns_ns']:.3f}ns、hold+{t['hold_wns_ns']:.3f}ns，TNS0、违例终点0；"
 f"Slice{a['slice_used']}/{a['slice_total']}={a['slice_percent']:.2f}%，LUT6{a['lut6_used']}、REG{a['reg_used']}、ERAM{a['eram_used']}、DSP{a['dsp_used']}；STA覆盖{t['sta_coverage_percent']:.2f}%")
identity=f"镜像{bit.stat().st_size}字节，SHA-256 `{sha(bit)}`。"
(release/'README.md').write_text(f'''# 3528下方定位孔追踪 v1

正式镜像camera_to_dsi_display.bit。{identity}

适配定位孔在器件下方的3528黑带白件；固定相机/光源、慢速手动横移。初始器件中心512/300，80×80检测框X[472,552)、Y[260,340)；孔参考464/380，三行372/380/388。在帧开始按上一完整有效帧孔位冻结检测框，本帧下方孔复核偏差≤4像素才发布本帧结果。框可能滞后本帧目标最多4像素；不承诺精确到像素或实际毫米/秒速率。连续两帧建立锁定，空穴也靠孔定位。失锁需回初始标记重新对准。

HDMI失锁显示黄色对准框、具体原因与ROW三行候选状态；锁定显示青框、统计及有件/空穴。遮孔、错形、超速、越界、帧停更或参数不匹配撤销旧结论。试用孔亮120/暗带100、宽20—64、孔距96±24；尚无ROI高度/定位阈值按键菜单。周期孔突跳整孔距可能串穴，无编号/电机/NG停车。

保留EXP/GAIN、手动R/B、四视图及原MEAN/EDGE独立分类门限。32项冻结仿真PASS，210生产输入/70源；{statistics}。34max_delay均匹配、ignored0，约束未放宽，124/10警告与旧上方孔版内容相同。原PLL/I/O及STA未覆盖限制保留；实物追踪、阈值、分类准确率、速度和长稳未验收。

来源为未提交工作区快照，未推送、未烧板。上板说明：开发实施/39_B3528下方定位孔追踪与诊断_上板说明.md；证据：{metadata['validation_record']}及同名目录。回退上方孔版：../dynamic_tracking_v1_20261010/camera_to_dsi_display.bit，SHA {audit['rollback_sha256']}；静态可调WB版保留。
''',encoding='utf-8')
s=guide.read_text(encoding='utf-8')
s=s.replace('软件验证与构建进行中，尚未生成本轮正式发布身份；不要将中间构建当成验收镜像。',
 f"代码、32项仿真、综合及布局布线已通过；尚未上板验收。正式镜像：`{metadata['release']['path']}`。\n\n{identity}\n\n{statistics}。34max_delay全匹配、ignored0，约束未放宽；既有PLL/I/O及未覆盖时序限制保留。完整证据：`{metadata['validation_record']}`及同名目录；未提交、未推送。")
s+='\n## 软件画面核对\n\n以下是实际RTL仿真导出的1024×600像素画面，背景为测试常量，不是相机照片或板上证据：\n\n'
s+=f"[锁定画面](验收记录/{record.name}/simulation/visual/tracking_1.png) · [失锁与下方对准画面](验收记录/{record.name}/simulation/visual/tracking_3.png)。\n"
guide.write_text(s,encoding='utf-8')
table='\n'.join('| '+e['name']+' | PASS | R3 |' for e in audit['tests'])
record.with_suffix('.md').write_text(f'''# B下方定位孔追踪修订 — 轮次1

用户再次确认实施。软件逻辑、本机构建和发布身份通过，实物尚待验证；未烧板、未提交、未推送。分支{branch}，HEAD{head}，source_commit=null。生产来源R1，完整32项仿真来源R3；R1/R2/R3的210生产输入完全同哈希，TD工程70个源条目。

## 问题与修改

两次现场照片仍TRACK WAIT、统计---，孔均在器件下方，原上方Y212/220/228搜索不切孔；第二图更水平仍不锁，不能用只摆水平解释。VF两图均01D8且FR/SEC前进，不能凭照片断言持续坏帧。原诊断把定位、统计、参数、传输、新鲜度混在WAIT中，缺少分项线索。原反馈和照片分别保留，未经本轮程序上板验证，原因判断不是现场验收结论。

仅改4项生产输入：{', '.join(audit['changed_production_inputs'])}。生产下方孔Y372/380/388，80×80核心Y260..339保持。下方孔晚于核心被扫描，因此帧开始按上一完整有效帧孔位冻结ROI，本帧孔位再复核偏差≤4像素才发布；坐标始终对应实际采样框，统计/定位/配置随完整DDR槽发布。首帧获取、第二帧锁定；遮孔、错形、超速和越界撤销。新增黄色初始对准框、原因与ROW，所有显示内容按HDMI帧锁存。FRAME STALE/CONFIG WAIT/NO INPUT FPS/VIDEO WAIT/PARAM CHANGED/ROI INCOMPLETE等可分别诊断；CHECK CORE ROI仍保留原分类等待语义。坏采集不发布，CAPTURE BAD可能被后续STALE代替。

默认上方模式接口兼容，未修改video_in/out生产源码、CSI/DDR IP、SDC、MEAN/Sobel/分类算术与阈值、WB/EXP/GAIN按键。帧元数据170→178位，只前置8位诊断，低170位意义保持；active帧CDC有效位/槽位同步扩宽。

## 冻结仿真与失败保留

R1 tracking_late首次测试失败（统计0）：新增测试的roi_statistics夹具没有设置80×80 AREA而使用默认512×256。只修夹具参数，生产代码和断言/样本不变；R1编译/运行失败日志与原测试保留。R2六项专项PASS；R3补强frame_metadata高8位检查后完整32项从头回归PASS，没有拿旧版结果替代。既有测试仅命名接口/元数据位宽/下方OSD适配；老上方孔真实ISP测试继续通过。

| 测试 | 结果 | 冻结来源 |
|---|---|---|
{table}

新增下方追踪单元覆盖14帧、双向4像素慢移、暂停、空穴、遮挡、8像素超速、错形及取消，独立逐像素6400点统计，逐拍断言帧内ROI固定、孔复核前不得锁定。4096组合诊断测试独立核对有效门控和原因优先级。真实RAW10/原厂RAM/重建/WB/Sobel十三帧覆盖预热、初锁、左右慢移、四视图、有件/空穴、遮孔/恢复、12像素超速/回基准重锁；独立统计与178位完整帧标签坐标核对。frame_metadata测试异步三时钟和高8位诊断、旧active槽/坏帧保护；OSD验证完整三幅614400像素、下方线/黄色对准框/原因字模、帧中不跳框。原厂模型和看门狗未改，软件合成样本不代表现场准确率。

实际OSD三幅栅格保留，已查看锁定1和失锁3；可视化仅在冻结测试加入PPM导出，所有断言保留，源/修改后源哈希有记录。背景为常量，不是硬件图。全部最终测试实际编译生产源哈希与R1/当前工作区核对相同。

## 构建、约束与身份

TD6.2.168116，综合64252/物理24570退出0且bitgen完成。{statistics}。相对上方孔版Slice+242、LUT6+199、REG+52、ERAM/DSP不变，无整帧缓存或像素级可变除法。34max_delay内容与前版相同且均匹配/ignored0，无放宽时钟或约束。综合124/物理10警告标准化后逐项完全相同；覆盖分类与旧版相同，dummy仍4类别、LSLICE映射为u_isp_top/u_roi_sobel_view/line_age_reg[2]_syn_2.ofb。STA覆盖不是100%，既有PLL/I/O/例外限制未解决。

正式镜像：{metadata['release']['path']}。{identity} 冻结源码、清单、脚本、失败/复测、最终32测试日志、TD报告、bit、说明及接力断点；不复制大型编译库/波形。旧上方孔镜像和{audit['prior_evidence_copies']}份证据已逐项核对，静态可调WB回退仍保留。

## 实物待验

按39说明让黄色下方三行切孔、参考孔及器件框同时对准，静止锁定后慢左/慢右/暂停，再遮孔/快速移位/恢复。偏差容许4px而非精确到像素；26/27输入fps约4px/有效帧的初版范围须实测，真实时间及模糊会影响结果。垂直位置和倍率固定，尚无ROI/孔高度按键菜单；失锁需回基准。试用孔亮120/暗100、宽20—64、孔距96±24未由手机照片标定。

周期孔突跳整孔距可能串穴，无工业身份/穴位编号/电机/NG停车；同穴有件/空穴配对、成像冻结、左中右色差影响、误报漏检、速度、冷启动和长稳待人验证。配方CAL/INVALID/UNCERTAIN/Flash未实现，追踪通过不等于分类精度通过。
''',encoding='utf-8')
execution=dict(build_sessions=dict(synthesis=64252,physical=24570,exit_code=0),
 simulation_sessions=dict(partial_r2=80348,full_r3=72375,visual=45945),
 full_regression_exit_code=0,hardware='not_operated',production_sources='R1 == R2 == R3',
 failure='R1 fixture AREA default; original console retained; production unchanged',final_regression='all 32 from frozen R3',
 visual='PPM dump only, all assertions retained')
dump(tests/'simulation_execution.json',execution)
checkpoint=root/'AGENTS.md';s=checkpoint.read_text(encoding='utf-8');s=s[:s.index('## 当前断点')]+f'''## 当前断点（2026-10-11，下方定位孔追踪v1软件完成，上板待验）

- **目标/断点**：用户授权按孔在器件下方修订并分项诊断。帧开始按上一完整有效帧孔位冻结本帧80×80/Y260..339核心，本帧下方372/380/388三行复核偏差≤4px才发布；两帧锁定、失败待检测。失锁黄色对准框、NO HOLE/HOLE SHAPE/MOVE TOO FAST等原因+ROW；有效青框与统计/分类和完整DDR槽一致。初始器件512/300、参考孔464/380，固定相机/光源，慢速手动水平。
- **分支/来源**：{branch}，HEAD{head}，source_commit=null，暂存区空、既有WIP保留。生产tmp/tracking_late_r1_td_20261011，210输入/70源；R1/R2/R3生产完全同哈希，最终32仿真R3。相对上方版仅tape_hole_tracker.v、isp_top.v、design_top_wrapper.v、experiment_osd.v共4生产输入变化；SDC/视频IP/分类/成像按键不改。
- **验证/证据**：32项完整回归PASS，真实RAW10/ISP十三帧、4096诊断组合、帧内固定ROI/4px复核、空穴/失锁/超速/恢复、178位元数据、三幅完整OSD；锁定1/失锁3实际栅格已查看。R1 AREA夹具失败日志保留，仅修测试80×80；R2专项PASS，R3从头全跑。综合64252/物理24570退出0，{statistics}。34max_delay匹配/ignored0、124/10警告同上方版，原PLL/I/O未覆盖限制保留；dummy LSLICE映射当前Sobel line_age_reg[2]。正式记录{metadata['validation_record']}及同名目录，旧{audit['prior_evidence_copies']}上方版证据副本保持。
- **镜像**：{metadata['release']['path']}，{audit['bit']['bytes']}字节，SHA {sha(bit)}；current_codex_build指R1构建/R3仿真及冻结快照。未烧板、板上镜像SHA未核对；新程序现场追踪未验收。
- **未决限制**：≤4px/有效输入帧的偏差容许且框可滞后4px；失锁回基准，两帧重新锁定。垂直/倍率固定，无ROI/孔高度按键菜单；试用亮120/暗100、孔距96±24、宽20—64待实测。重复孔整孔距突跳可能串穴，无身份/编号/电机/NG。同穴有件空穴配对、色差影响、成像冻结、分类准确率、冷启动长稳未验证；无完整配方CAL/INVALID/UNCERTAIN/Flash。
- **下一条操作**：按39说明下载正式SHA镜像，黄色下方三行/孔参考与器件框同时对准，静止LOCK→慢左/慢右/暂停→遮孔/超速/越界/恢复；记录原因/ROW、实际孔灰度/宽距/Y和同穴真值。若NO HOLE继续核对亮暗/倍率/初始相位，不把软件PASS当现场通过。
- **进程/设备**：本轮综合64252/物理24570、完整回归72375、专项80348、可视化45945均结束0；R1夹具失败日志保留。无运行进程，无JTAG/Flash/板卡操作，无代理/新聊天/自动任务。
- **提交/回退**：未提交未推送、暂存区空；上方追踪回退SHA{audit['rollback_sha256']}，静态manualWB SHAf71b8d6cc7e8d90c04a84c9ce4916403e2d763c49c5d2c57a1ebf511e8e02800；固定WB/v3历史不改。
'''
checkpoint.write_text(s,encoding='utf-8')
dump(project/'td_project/current_codex_build.json',metadata)
copies=[]
def copy(src,rel):
    dst=record/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    copies.append(dict(path=dst.relative_to(record).as_posix(),bytes=dst.stat().st_size,sha256=sha(dst)))
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for src,rel in [(build/'inputs.json','inputs.json'),(build/'stage_inputs.json','stage_inputs.json'),
 (tests/'simulation_inputs.json','simulation_inputs.json'),(tests/'audit.json','audit.json'),
 (tests/'simulation_execution.json','simulation_execution.json'),(before/'inputs.json','before/inputs.json')]:copy(src,rel)
for rel in audit['changed_production_inputs']:copy(before/rel,Path('before/source_changes')/rel)
for stage in ['syn_1','phy_1']:
    for p in (runs/stage).iterdir():
        if p.is_file() and p.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:
            copy(p,Path('td_reports')/stage/p.name)
for e in load(tests/'simulation_inputs.json'):copy(tests/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
for e in audit['tests']:
    for p in (tests/'sim/modelsim_work'/e['name']).glob('*.log'):copy(p,Path('simulation/logs')/e['name']/p.name)
for version in ['r1','r2']:
    b=root/f'tmp/tracking_late_{version}_td_20261011'
    copy(b/'simulation_inputs.json',Path('simulation')/version/'inputs.json')
    copy(b/'sim/tb_tracking_late.v',Path('simulation')/version/'tb_tracking_late.v')
    for p in (b/'sim/modelsim_work').glob('*/*.log'):copy(p,Path('simulation')/version/p.relative_to(b/'sim/modelsim_work'))
    for p in (b/'sim').iterdir():
        if p.is_file() and (p.suffix=='.log' or p.name.endswith('_exit_code.txt')):copy(p,Path('simulation')/version/p.name)
for p in (tests/'sim').iterdir():
    if p.is_file() and (p.suffix=='.log' or p.name.endswith('_exit_code.txt')):copy(p,Path('simulation/r3')/p.name)
for rel in ['visual_notes.json','sim/tb_tracking_osd.v','sim/visual_exit_code.txt','sim/visual_console.log',
 'sim/modelsim_work/tracking_osd/compile.log','sim/modelsim_work/tracking_osd/console.log']:copy(visual/rel,Path('simulation/visual')/rel)
for p in (visual/'sim').glob('tracking_*.png'):copy(p,Path('simulation/visual')/p.name)
for name in ['prepare_tracking_late_20261011.py','create_late_tests_20261011.py','audit_tracking_late_20261011.py',
 'prepare_late_visual_20261011.py','convert_late_visual_20261011.py','freeze_tracking_late_20261011.py','verify_tracking_late_20261011.py']:
    copy(root/'tmp'/name,Path('build_scripts')/name)
for p in [guide,record.with_suffix('.md')]:copy(p,Path('documents')/p.name)
copy(checkpoint,'AGENTS_checkpoint.md');copy(project/'td_project/current_codex_build.json','current_codex_build.json');copy(release/'README.md','release_README.md')
vendor=Path('D:/AAA/FPGA.....YZW/sim_release')
models=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v','ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v']
manifest=dict(created_at=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),status='software_verified_board_pending',
 branch=branch,base_head=head,source_commit=None,commit_status='uncommitted_unpushed_workspace_snapshot',tool='TD6.2.168116',simulator='ModelSim2019.2',
 build_inputs_count=210,source_entries=70,bit=metadata['release'],audit=audit,
 rollback=dict(path='fpga/component_inspector/release/dynamic_tracking_v1_20261010/camera_to_dsi_display.bit',sha256=audit['rollback_sha256']),
 vendor_model_hashes=[dict(path=str(vendor/n),sha256=sha(vendor/n)) for n in models],flow_sha256=sha(Path(metadata['flow'])),copies=copies)
dump(record/'manifest.json',manifest);dump(release/'manifest.json',{k:v for k,v in manifest.items() if k!='copies'})
for e in copies:assert sha(record/e['path'])==e['sha256'] and (record/e['path']).stat().st_size==e['bytes']
print(json.dumps(dict(record=str(record),release=str(release),copies=len(copies),bit=audit['bit']),ensure_ascii=False))
