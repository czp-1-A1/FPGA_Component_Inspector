from pathlib import Path
import hashlib,json,shutil,subprocess
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
record=root/'开发实施/验收记录/20261008_A3528调参判定_轮次2'
release=project/'release/led_presence_demo_v2_r2_20261008'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
data=load(record/'manifest.json');audit=load(record/'report_audit.json')
metrics,res=data['timing'],data['resources'];bitsha=data['bit']['sha256']
syn_log=(record/'td_reports/syn_1/build_console.log').read_text(encoding='utf-8-sig',errors='replace')
assert not any('WARNING:' in line and "port 'calibration_ok'" in line for line in syn_log.splitlines())
readme=f'''# 3528 LED有件／空穴第二版（调参恢复）

本版允许调曝光和增益，取得新有效采样后自动显示有件／空穴，不再仅因参数不同于2244/48显示未标定。临时阈值58保留；新镜像尚未上板，准确度待现场核对。

1. 使用本目录`camera_to_dsi_display.bit`，核对`SHA256.txt`。本轮没有自动下载、写Flash或冷启动。
2. 先用约130mm、EXP2244／GAIN48、SW1上/SW2下MODE=GRAY；将一个待测料穴对准青色80×80框，避开定位孔、桌面、带边及邻穴。
3. 静止后直接核对左下自动中文结果与实物。有件为青绿色，空穴为橙色；用户无需手算MEAN。
4. KEY1/KEY2仍调曝光，KEY3/KEY4仍调增益。调参/配置忙时显示等待采样，停下按键后取得新的完整有效记录才恢复判定。先小幅各调一档，分别核对有件和空穴。

MEAN≥58判有件、<58判空穴。曝光2244／增益48是历史阈值证据条件，不再是使能门槛；不同亮度会改变灰度，因此T58在其它参数下可能需要后续重测。机构固定后再做同位置有件/空穴配对标定。黑件/黑带和透明载带专属判定暂未扩展。

SW组合RAW／GRAY／EDGE／GRAY+EDGE保留，四种均用这套3528灰度判定；页脚T80是边缘显示阈值。正常连续帧保留最近完整结果；参数变化、坏帧、切SW和停输入仍撤销旧有效性。结果仍为最近采样，没有绑定DDR当前显示帧。

本机TD6.2.168116重新综合/布局布线完成：setup+{metrics['setup_wns_ns']:.3f}ns，hold+{metrics['hold_wns_ns']:.3f}ns，TNS0；Slice{res['slice_used']}/{res['slice_total']}（{res['slice_percent']:.2f}%），ERAM{res['eram_used']}/108，DSP{res['dsp_used']}/40。STA覆盖{metrics['sta_coverage_percent']:.2f}%，原PLL/I/O及覆盖局限保留。新增分类端口位宽告警已消除，不宣称全部约束闭合或板级验收。

七项定向ModelSim在轮次1通过；轮次2仅将顶层使能常量写成1位，所有被测模块/测试源码逐字节不变，依据simulation_reuse.json复用日志。实际新顶层重新编译，真实顶层使能表达式的对照重新运行PASS：旧绑定在gain47复现关闭分类，新绑定等新采样后恢复。不是整板PHY仿真或各种参数准确率测试。

镜像1789539字节，SHA256：`{bitsha}`。
分支lj4747-contest-work，HEAD基线3be3967f2457622566fb20b7cef3aa5038e7d885，未提交／未推送工作区快照；207输入及冻结源码/工具报告见验收记录20261008_A3528调参判定_轮次2。

回退可用第一版`../led_presence_demo_v1_20261007/`（SHA4c8aa1695e06f3218ba5ae01b67e78e188755a61beea9f1229cdd1ef7296e22e），或稳定EDGE修复`../edge_tail_fix_20261007/`（SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65）。相邻`led_presence_demo_v2_20261008`为本轮第一次构建候选/过程证据，最终推荐本目录R2镜像。
'''
(release/'README.zh-CN.md').write_text(readme,encoding='utf-8')
(record/'README.zh-CN.md').write_text(readme,encoding='utf-8')
md=f'''# 20261008 A3528调参判定：轮次2最终软件交付

## 授权、问题与改变

用户指出第一版只有GAIN48及设定曝光下才能识别，调参后持续显示未标定；确认解除固定值绑定，配置期间等待，新有效完整采样后自动HDMI有件／空穴，继续用临时T58。没有授权自动烧录或其它物料算法。

生产只改design_top_wrapper：采集与显示两处calibration_ok不再比较EXP2244/GAIN48，删除本次孤立的两常量，CLASS_CALIBRATED用明确1位1'b1。207生产输入与v1只有顶层变化；EDGE帧尾修复、206其它输入、IP/ADC/SDC不变。tb_display_state新增非默认参数变化、配置忙、旧token排除、新样本恢复及返回默认值。其它既有工作区变化保留。

R1发现新增32→1位分类使能告警后保留该候选及372主证据，R2修改字面量位宽并重新综合/物理实现，告警消失；未通过放宽约束或隐藏工具日志消除告警。源码CRLF、测试LF保留。

## 版本与结果

- 分支lj4747-contest-work，HEAD基线3be3967f2457622566fb20b7cef3aa5038e7d885；未提交/未推送工作区快照，不冒称新提交已同步。
- 工具本机TD6.2.168116、ModelSim2019.2，PH1P35MDG324 speed3；工具路径/脚本、207输入/67源路径、模型SHA在manifest。
- 隔离构建tmp/led_presence_demo_v2_r2_td_20261008，before保留R1顶层/测试/元数据/AGENTS。
- 最终bit release/led_presence_demo_v2_r2_20261008/camera_to_dsi_display.bit，1789539字节，SHA256 `{bitsha}`。
- R2综合和物理退出0，opt_gate/bitgen完成标记；Routed慢/快角setup+{metrics['setup_wns_ns']:.3f}ns、hold+{metrics['hold_wns_ns']:.3f}ns、TNS0，所有报告违例终点0。
- Slice{res['slice_used']}/21216={res['slice_percent']:.2f}%，LUT6 {res['lut6_used']}、REG{res['reg_used']}、ERAM{res['eram_used']}/108、DSP{res['dsp_used']}/40，STA{metrics['sta_coverage_percent']:.2f}%。处于项目70-80%资源注意区，未增加图像缓存/DSP。

## 仿真依据与复用

R1七项PASS：classifier/display_state/controls/observation/stop_recovery/osd/roi_chain。原厂ERAM模型，无RAM强制接零；真实1024×600 RAW→demosaic/AWB、独立统计、异常帧拒绝/恢复，中文结果/Logo/同步。新增显示回归使用非默认曝光/增益，检查变化立即等待，旧token不重启，完成新记录后有件/空穴恢复。此处输入MEAN是逻辑刺激，不表示曝光/增益边界有实际光学精度。

R2只有顶层使能字面量位宽变化，七项模块测试不编译此顶层。逐字节核对206其它生产输入、runner与测试源码不变后复用七项日志；simulation_reuse.json逐项记录来源及SHA，不称七项R2重新运行。实际R2顶层由TD重新编译并完成bit。

R2另重新从真实旧v1及R2顶层提取两端使能表达式，接入同一分类/显示/真实CDC测试：旧绑定在gain47精确复现关闭分类的断言失败，R2完整PASS。此测试不是顶层所有模块/板级PHY仿真。负对照$fatal在ModelSim -onfinish exit下可能退出0，判据为精确断言/参数上下文/Errors1；正例需PASS且无Fatal。

R2探针准备首次误取R1解除绑定后的源码当作负对照，自然未复现gain47错误；失败日志保留binding_probe_baseline_failure。更正为实际v1带绑定源码后，负对照和R2正例通过，没有修改生产或单元测试来降低判据。

## 资源、约束与证据解释

report_audit.json核真实Summary共31 max-delay规则、24邮箱规则均有匹配/ignored0，8payload规则dominated；原4条握手由相同/更强约束shadow。与v1路径数量会随映射改变，预算命令不变，变化表已记录。检查范围含完整本机约束报告，不表示未约束端口已闭合。

既有dummy4/shadowed9、DDR PLL频率7、无input-delay39、无output-delay63、partial input1和PLL局部网络问题保留。STA覆盖非100%。R1继承解析器把详情重复算成72条，R2仅取MCP/SMD Summary，冻结manifest含24邮箱行；R1/历史证据不回写。

冻结主manifest共{len(data['copies'])}文件SHA含source_snapshot、before、TD报告、七项仿真源/来源日志、原厂模型SHA、对照日志和脚本。README/checkpoint/report_audit/最终验证为补充文件，verification.json另记录SHA。WLF/ModelSim库不作为本轮必需归档，复测须复制到新的ASCII目录，不覆盖冻结文件。

## 实物范围与下一步

未自动JTAG下载、Flash、冷启动；没有第二版上板分类、连续视频或准确率验收。用户自行加载最终bit，人工将单穴对准青框，静止后核HDMI有件/空穴真值，再小幅调曝光或增益，观察等待后重新输出类别。用户不需手算MEAN。

T58来自历史130mm黑带白件显示读数；旧料号未核验、重复图与完整静止范围不足，当前3528型号来自用户。2244/48仅保留为起始参考条件；不同曝光/增益可能改变准确度，机构固定后再同位置配对标定。另两类物料专属判定、DDR帧绑定、30分钟视频、约束闭合和冷启动后续处理，不声称阶段A全部验收。
'''
record.with_suffix('.md').write_text(md,encoding='utf-8')
agents=root/'AGENTS.md';s=agents.read_text(encoding='utf-8');s=s[:s.index('## 当前断点')]
s+=f'''## 当前断点（2026-10-08，3528第二版调参判定已生成，待上板）

- **目标与断点**：用户报告改变EXP/GAIN后持续未标定并确认解除固定值使能绑定。已完成第二版：调参等待、新有效完整样本后自动HDMI有件/空穴；临时T58不承诺不同亮度精度。先3528，另两类及机构固定后精进后续。
- **分支/代码基线**：lj4747-contest-work，HEAD3be3967f2457622566fb20b7cef3aa5038e7d885。207生产输入仅top相对v1变化，两端calibration_ok移除固定EXP/GAIN比较，清理孤立常量，CLASS_CALIBRATED=1'b1。206其余生产文件含EDGE修复/IP/ADC/SDC逐字节不变；tb_display_state新增调参新鲜度测试，此前tb_classifier保留。
- **最终交付与证据**：release/led_presence_demo_v2_r2_20261008/camera_to_dsi_display.bit，1789539字节，SHA {bitsha}；README/SHA256/build_inputs/manifest齐备。冻结20261008_A3528调参判定_轮次2及.md，{len(data['copies'])}主证据源码/报告/日志；当前元数据指向tmp/led_presence_demo_v2_r2_td_20261008和未提交快照，31实施说明同步最终路径。R1候选40b82b...因新增位宽告警留过程证据，推荐R2。
- **验证**：七项ModelSim2019.2原厂RAM在R1 PASS：classifier/display_state/controls/observation/stop_recovery/osd/roi_chain，真实1024×600 RAW/ISP/异常恢复与中文OSD。R2仅顶层字面量位宽修正，被测模块/测试/runner全部SHA相同，依simulation_reuse.json复用日志，不称七项重新跑。实际R2顶层TD重编译和提取真实使能条件的gain47负/正对照重新运行PASS。新增32→1位告警已消除。
- **本机资源时序**：TD6.2.168116两阶段退出0、bitgen完成，Routed慢/快角setup+{metrics['setup_wns_ns']:.3f}ns/hold+{metrics['hold_wns_ns']:.3f}ns/TNS0/违例终点0；Slice{res['slice_used']}/21216={res['slice_percent']:.2f}%，LUT6{res['lut6_used']}、REG{res['reg_used']}、ERAM{res['eram_used']}、DSP{res['dsp_used']}；STA{metrics['sta_coverage_percent']:.2f}%。原PLL/I/O/覆盖问题保留，31规则匹配/ignored0、24邮箱预算不变及原4握手shadow，详report_audit。R2修复R1解析器详情重复计数问题，旧manifest字节保留。
- **未决与阈值限制**：新bit未上板，无第二版物理分类/视频/冷启动/准确率验收。T58、gray高侧和青ROI[472,552)×[260,340)6400像素不变，用户对准单穴；EXP2244/GAIN48仅阈值历史参考不再使能门槛，光学变化仍影响准确度。四视图同一LED判定，页脚T80边缘阈值，最近采样未绑定DDR显示帧。阶段A未全部验收。
- **下一条具体操作**：用户核SHA并加载R2，先GRAY约130mm和参考2244/48，单穴对准青框，分别核有件/空穴真值；小幅调曝光/增益，停下按键后观察等待结束是否恢复中文判定。若误判记录相同覆盖真值/内部读数以调临时阈值；不要求用户手算MEAN。其他物料后续。
- **运行中进程/设备**：R1综合55667/仿真29940/物理76578与R2综合52150/物理23406及对照均已退出0；无助手TDCLI/vsim/vlog运行，最终进程快照在verification。用户TD27224/bw35732/hwserver21964未操作，PID仅记录时快照；未JTAG/Flash/冷启动。root单端实现，无新代理/线程/自动任务。
- **提交/推送与校验**：此前和本轮RTL/tests/元数据/AGENTS/release/证据未提交、未推送，暂存区空；第一版SHA4c8aa169...与稳定EDGE bb6a7144...及v1 364主证据未变。最终校验待执行VERIFY_PENDING。
'''
agents.write_text(s,encoding='utf-8')
for name in ['checkpoint_led_presence_v2_r2_20261008.py','audit_led_presence_v2_r2_20261008.py','finish_led_presence_v2_r2_20261008.py','verify_led_presence_v2_r2_20261008.py']:
    shutil.copy2(root/'tmp'/name,record/'build_scripts'/name)
# Supplement, never rewrite R1 frozen main evidence.
for src in (root/'tmp/led_presence_demo_v2_r2_td_20261008/binding_probe_baseline_failure').iterdir():
    if src.is_file() and src.suffix.lower() in {'.log','.json','.v'}:
        dst=record/'simulation/binding_probe_baseline_failure'/src.name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
dump(record/'warning_gate.json',{'new_calibration_port_width_warning_absent':True,'top_literal':"CLASS_CALIBRATED=1'b1",'synthesis_log_sha256':sha(record/'td_reports/syn_1/build_console.log')})
print('Wrote final R2 README, validation record and checkpoint; verification pending')
