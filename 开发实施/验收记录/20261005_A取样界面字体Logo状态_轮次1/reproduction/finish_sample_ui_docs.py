from pathlib import Path
import json,hashlib,shutil
r=Path(__file__).resolve().parents[2];p=r/'fpga/component_inspector';release=p/'release/sample_ui_20261005'
e=r/'开发实施/验收记录/20261005_A取样界面字体Logo状态_轮次1';m=json.loads((release/'manifest.json').read_text(encoding='utf-8'))
res=m['resources'];t=m['timing'];bit=m['bitstream'];sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
body=f'''# A取样界面、字体Logo与状态处理实施说明

2026-10-05。用户明确选择“直接用取样界面”，本批已完成RTL、ModelSim、TD综合与布局布线；**尚未上板，不代表A阶段完整实物验收**。机构定位和正式阈值标定继续后移，CLASS_CALIBRATED=0、T=0占位，不启用讨论中的T58。

## 界面和操作

1024×600保持原相机坐标。顶部80像素显示安路Logo、曝光EXP（半行）和增益GAIN（档号）；底部96像素显示中文最近采样、MEAN/MIN/MAX及验收信息。无额外界面切换或菜单，KEY1～KEY4仍为曝光−/＋、增益−/＋。输入尺寸和FPS来自RAW接收前测量；FPS不是HDMI刷新率。L/F/I/G及FR/SEC为十六进制，旁边标HEX；普通读数为十进制，前导零改为空白。

绿色观测框仍[256,768)×[172,428)，内部灰度floor((R+2G+B)/4)；青色核心仍[472,552)×[260,340)，6400像素统计。上下条只覆盖图像边缘，不缩放视频、不改变ROI。两个框颜色固定，不表示与当前DDR显示帧绑定。

中文33字、24×24，主要结果整数2倍48×48；ASCII32字符、8×16，主要读数16×32。96×64安路Logo由随板Lab3原ROM裁掉空白、保留比例并量化为白/蓝/红。字模和Logo净有效数据4424字节，按地址深度对齐后的ROM81920bit；TD分别映射1＋3＋1块ERAM，总新增5块，没有完整字库、DSP或全帧缓存。源字体/Logo输入SHA及生成器见source_snapshot/sim/osd_assets/manifest.json及generate_osd_assets.py；综合只读取已生成的3个Verilog ROM。

## 状态语义

| 条件（从上到下优先） | 主文字 / 统计 |
|---|---|
| CFG未完成 | 等待采样，配置中，统计--- |
| CFG完成但独立FPS=0 | 等待采样，无输入，统计--- |
| 坏帧、无效、恢复后未有新完整记录 | 等待采样，等待有效帧，统计--- |
| 有效完整记录但未标定或配方不匹配 | 未标定，显示有效MEAN/MIN/MAX |
| 配方匹配且新完整记录判有件 | 有件（仅存在性），绿色 |
| 配方匹配且新完整记录判空穴 | 空穴，橙色 |

正常下一native FS只重置source classifier当前帧新鲜性，显示保留上一完整采样，下一完整记录到达时统一更新。新增roi_result_snapshot等sample_new后一采集时钟，使类别和三统计同一记录发布；FS抢占、invalidate/config/lane撤销待发布记录。28位邮箱为完成token1＋状态2＋有效1＋统计24；token仅新完整发布翻转，轮询不翻转。

目的端roi_display_state在配置、参数、FPS或有效性变化时撤销；参数/输入恢复有32像素拍稳定等待用于排空旧跨域内容，之后要求新的完成token。失去标定保留有用统计但撤销类别，匹配回来仍要求新分类。持续有钟的保守传播约338.2ns，小于615.36ns稳定窗口；真实相邻采样约37ms，远长于邮箱传递。详见04接口约定。独立1秒监测窗口仍需约1～2秒检测停流，OSD字段整帧锁存，撤销显示再等待一VS边界。HDMI停钟、显示器断线仍需现场观察。

错误计数只表示累计历史，非零显示“累计异常”，不永久锁成当前故障。没有自动识别手动换样、灯光/焦点/距离变化，也没有DDR帧号绑定；使用“最近采样”说明这一限制。有件不代表偏位、极性、引脚或综合质量合格。

## 离线验证

ModelSim SE64 2019.2默认14项通过，没有强制覆盖。保留原12项，新增display_state和stop_recovery。实际RAW→demosaic/AWB/原厂ERAM共7帧1024×600，独立6400像素参考和新快照核对，短行/长暂停拒绝、配置撤销与恢复。

状态单元使用真实28位CDC、source classifier和显示门控，检查正常FS不闪烁、原子字段、坏帧/调参、旧在途载荷、配方失配/恢复、CSI停钟和复位。停流测试使用独立50MHz参考的真实input_monitor，把窗口缩为1000参考拍，在两端相位直接停CSI时钟；1850/1020参考拍内归零（均不超过两窗口），冻结邮箱不能恢复有效，必须新完成采样。

OSD完整614400像素＋6个98304像素状态条与独立Python参考一致，包含中文字、Logo、无效占位、错误提示、双框/灰度/框外彩色。三拍RGB/DE/HS/VS及ENABLE旁路一致，字段VS锁存；65535参数及前导空白检查通过。仿真图见本批证据rendered；它们是合成色底测试图，不是相机实物照片。旧classifier的27位测试作为历史模块回归保留，新生产28位链路由新增测试核对。

## TD结果与约束

| 项目 | 最终结果 | 前版80×80取样基线 |
|---|---:|---:|
| Slice | {res['slice']} / {res['slice_percent']}% | 14122 / 66.56% |
| ERAM | {res['eram']} | 31 |
| DSP | {res['dsp']} | 8 |
| 综合LUT / REG | {res['lut']} / {res['reg']} | 15006 / 15680 |
| 建立/恢复WNS | {t['setup_wns_ns']} ns | 1.437 ns |
| 保持WNS | {t['hold_wns_ns']} ns | 0.020 ns |
| 建立/保持TNS | 0 / 0 ns | 0 / 0 ns |
| STA覆盖 | {t['sta_coverage_percent']}% | 95.05% |

TD6.2.168116，PH1P35MDG324 speed3，最终Routed、slow/fast两角。原SDC/ADC字节不改。6个camera_receive/roi_display专用物理预算Matched=Dominated>0、Redundant/Ignored=0，28位生产邮箱已覆盖。完整constraint_coverage计数与基线相同：dummy4、PLL约束7、no_input37、no_output63、partial_input1、shadow/ignored4（2原DDR/FIFO例外＋2通用预算被专用覆盖）；没有新增无钟、组合环或无路径约束。仍保留两PLL本地反馈关键告警。**建立保持通过不等于约束100%覆盖或这些既有问题已解决**，详细原报告存td/phy_1。

## 镜像和现场检查

独立版本fpga/component_inspector/release/sample_ui_20261005/camera_to_dsi_display.bit，{bit['bytes']}字节，SHA-256：

`{bit['sha256']}`

由用户下载。本助手未操作JTAG/USB。下载后先检查Logo与中文、正常等待→未标定、统计与两框、框外彩色及四键；调参时应暂时统计---再恢复有效。停相机输入观察独立FPS归零及等待采样，恢复应等新完整记录；注意用板卡允许的断流方式，不要求带电插拔。随后另记录30分钟错误/画面和固化冷启动。正式位置/光源/焦点固定后再取两类同位完整统计范围并确认启用判定。本批未补填实物、准确率、固化或冷启动通过。

203综合输入和.al逐项与隔离构建tmp/sample_ui_td_build_20261005一致；只改前版3项既有RTL（top/ISP/OSD），新增快照、显示门控与3小ROM。branch {m['branch']}，HEAD {m['head']}，未提交未推送。历史镜像哈希已核对保留。本批说明/源码/素材、测试波形、工具报告、脚本和图均冻结到同名验收证据目录；工具首次调用问题另记history/invocation_notes.md，不充当最终通过。
'''
doc=r/'开发实施/21_A取样界面字体Logo与状态处理_实施说明.md';doc.write_text(body,encoding='utf-8')
report=e.with_suffix('.md');report.write_text(body,encoding='utf-8')
(release/'README.md').write_text(f'''# Sampling UI build 2026-10-05

User-approved sampling interface only. 1024x600, finite Chinese/ASCII ROM fonts, Anlogic mark, 512x256 gray observation and 80x80 cyan statistics core; four controls unchanged. Recent coherent 28-bit sample + destination recovery gate; all video/sync/bypass delayed 3 pixel clocks. Production classification disabled (UNCAL), no T58 enabled.

ModelSim default 14 tests PASS. TD synthesis/place/route PASS: Slice {res['slice']} ({res['slice_percent']}%), ERAM {res['eram']}, DSP {res['dsp']}; setup {t['setup_wns_ns']}ns, hold {t['hold_wns_ns']}ns, TNS zero. SDC unchanged; existing IO/PLL/DDR coverage gaps retained, STA {t['sta_coverage_percent']}%. Six dedicated receive/ROI mailbox budgets matched. Not hardware tested; user downloads the bit.

Bit SHA-256: {bit['sha256']}

Evidence: 开发实施/验收记录/20261005_A取样界面字体Logo状态_轮次1.md and same-name directory. All 203 inputs and project hash recorded in manifest.json. Working tree uncommitted and not pushed; prior releases preserved.
''',encoding='utf-8')
plan=r/'开发实施/20_A结果显示字体Logo与状态处理_待确认方案.md';s=plan.read_text(encoding='utf-8').replace('实施中。','已完成离线实现和验证，实物检查待用户下载。')
s+='\n## 10. 实施落点\n\n仅取样界面已实现，最终结果见21实施说明及20261005_A取样界面字体Logo状态_轮次1。14项ModelSim与TD通过，CLASS_CALIBRATED=0。此前预览图/preview_manifest保持方案当时状态，不改造成实物或新bit证据。\n';plan.write_text(s,encoding='utf-8')
a=r/'AGENTS.md';s=a.read_text(encoding='utf-8');s=s[:s.index('## 当前断点')]+f'''## 当前断点（2026-10-05）

- **目标/断点**：用户“直接用取样界面”已实施并离线验证，独立bit待用户下载；不当作完整A实物验收。中文33字/ASCII32字、小Logo、最近完整快照和恢复门控已接入，仅取样界面，无演示菜单。机构未固定，CLASS_CALIBRATED=0/T58不启用。
- **分支/基线**：{m['branch']}，HEAD {m['head']}；既有工作区改动保留。前版roi_core_80_20261005 SHA78d9a419cc75bae78655cc7608037959415ea67fd0452580446de0b7176c3c54及旧release哈希核对保留。
- **改动文件**：既有top/isp_top/experiment_osd，新增roi_result_snapshot/roi_display_state/osd_ascii_rom/osd_cjk_rom/osd_logo_rom并注册.al；sim增加2状态测试、字模生成/独立布局参考，增强OSD/真实ISP并更新ModelSim/Icarus入口、README；04/20/21文档及本批证据。原SDC/ADC、相机/按键、guard/statistics/classifier不改。
- **接口**：ROI28位token1+state2+valid1+三统计24，sample_new后一拍原子发布；source classifier在FS仍清新鲜度，显示正常FS保留最近完整。坏帧/配置/停流撤销，32像素拍排空旧内容后需新token；失配恢复需新分类。OSD三拍RGB/DE/HS/VS和旁路，VS字段快照。未DDR帧绑定，FPS窗口停流约1～2秒＋显示帧边界。
- **验证/证据**：默认14项ModelSim PASS，无覆盖；真实7帧RAW/ISP/原厂ERAM/6400像素及快照核对。整帧614400像素和6状态条各98304像素独立参考一致，最大65535/前导空白、同步/旁路；停CSI钟而独立50MHz监测运行，两相位1850/1020参考拍（REF_HZ=1000）归零，恢复不凭旧邮箱。日志/WLF/图、203输入+.al、TD报告和文档快照已冻结至开发实施/验收记录/20261005_A取样界面字体Logo状态_轮次1。初次GUI TD调用、runner过滤和测试边界增强有history记录，不当最终验收。
- **构建/约束**：tmp/sample_ui_td_build_20261005与工程203输入/.al哈希一致。TD6.2.168116/PH1P35MDG324 speed3，Slice{res['slice']}（{res['slice_percent']}%）、ERAM36（ROM1+3+1新增5）、DSP8、综合LUT{res['lut']}/REG{res['reg']}。建立/恢复WNS{t['setup_wns_ns']}ns，保持{t['hold_wns_ns']}ns，TNS0，STA{t['sta_coverage_percent']}%。约束字节不改，覆盖计数同前版：dummy4、PLL7、无输入37/无输出63/部分输入1、shadow/ignored4（原DDR/FIFO2+通用2）；六专用邮箱预算有效，两PLL反馈关键告警保留，非100%覆盖。
- **镜像**：release/sample_ui_20261005/camera_to_dsi_display.bit，{bit['bytes']}字节，SHA {bit['sha256']}。原release不覆盖，本版尚未上板。
- **现场/限制**：固定摄像头，1024×600/四键保持；观测[256,768)×[172,428)，核心[472,552)×[260,340)。130mm候选、焦点光源未冻结；单穴照片有件78～88/空穴36～37仅时点探索。建模未完成，暂不要求严格重复测量。正式分类、准确率、30分钟、固化及本版冷启动未验收。
- **下一操作**：用户下载此唯一新bit，检查中文/Logo、两框/彩色、四键及状态撤销恢复；反馈问题按本版源快照定位。可独立做30分钟/固化冷启动；机构可固定后重新选ROI/焦点/配方、记录每类完整范围，再确认启用阈值并重新TD。不要凭仿真有件/空穴状态认为实际分类已启用。
- **进程/设备**：本轮ModelSim/TD已结束，无后台构建或服务；用户原TD界面未关闭。板卡由用户管理，助手未操作JTAG/USB。
- **提交/推送**：未提交未推送。不称已同步；git diff --check只保留原uii2c.v:148行尾空格，未改该行。
''';a.write_text(s,encoding='utf-8')
copy_names=['AGENTS.md','开发实施/04_FPGA接口与异常处理约定.md','开发实施/20_A结果显示字体Logo与状态处理_待确认方案.md','开发实施/21_A取样界面字体Logo与状态处理_实施说明.md']
for rel in copy_names:
 dst=e/'docs_snapshot'/Path(rel).name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(r/rel,dst)
shutil.copy2(Path(__file__),e/'reproduction'/Path(__file__).name)
shutil.copy2(report,e/'验收记录.md');shutil.copy2(release/'README.md',e/'release_readme.md')
m['evidence_files']=[{'path':str(f.relative_to(e)).replace('\\','/'),'sha256':sha(f),'bytes':f.stat().st_size} for f in sorted(e.rglob('*')) if f.is_file() and f!=e/'manifest.json']
for f in [release/'manifest.json',e/'manifest.json']:f.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert sha(release/'camera_to_dsi_display.bit')==bit['sha256']
for entry in m['evidence_files']:assert sha(e/entry['path'])==entry['sha256']
print('Final docs/checkpoint and',len(m['evidence_files']),'frozen evidence files verified. Hardware pending, uncommitted/unpushed.')
