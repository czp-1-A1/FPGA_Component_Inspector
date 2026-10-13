from pathlib import Path
import hashlib,json,shutil,re
root=Path(__file__).resolve().parents[2];p=root/'fpga/component_inspector'
evidence=root/'开发实施/验收记录/20261004_A均值离线判定_轮次1'
release=p/'release/roi_classifier_20261004'
m=json.loads((release/'manifest.json').read_text(encoding='utf-8'))
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
assert len(m['verified_build_inputs'])==198
bit=m['bitstream']['sha256'];t=m['timing'];r=m['resources']
record=root/'开发实施/验收记录/20261004_A均值离线判定_轮次1.md'
record.write_text(f'''# A均值离线判定：本轮验收记录

2026-10-04。用户“执行”批准15稿离线最小实现；无法上板，下载及现场复核由用户进行。本记录区分仿真、TD构建、实物状态，不作为完整A阶段通过结论。

## 代码与镜像身份

- 分支：{m['branch']}；HEAD：{m['head']}；未提交、未推送。
- 工程入口：fpga/component_inspector/td_project/camera_to_dsi_display.al。
- 最终独立构建：tmp/roi_classifier_final_td_build_20261004；与当前工程、冻结快照逐项核对198项输入及.al哈希一致。
- bit：fpga/component_inspector/release/roi_classifier_20261004/camera_to_dsi_display.bit；{m['bitstream']['bytes']:,}字节。
- SHA-256：`{bit}`。
- 回退基线：roi_statistics_large_20261003，SHA-256 `{m['previous_bit_sha256']}`；所有旧发布保持。

本批新增roi_classifier与独立RECENT状态行；统计sample_new、native FS取消旧计算、配置/lane直接取消；27位结果邮箱。正常新帧保留最近完整调参统计，但清除旧分类。512×256仍用于观测，CLASS_CALIBRATED=0，因此本次实物应显示UNCAL，不会直接分类多个穴位。详细接口、位宽、延迟、旁路及标定步骤见16实施说明。

## ModelSim最终证据

ModelSim SE-64 2019.2，真实原厂ERAM/GSR/除法网表；未使用强制覆盖RAM输入。最终10项短测试在regression_classifier_final10_console.log通过；随后classifier增加最近统计保留断言单独通过；roi_chain按最终RTL单独通过。合计11项均有最终compile/console/transcript/WLF，不将中间旧版链路的通过冒作最终版。

| 测试 | 最终结果 | 主要依据 |
|---|---|---|
| controls | PASS | 四键、限幅与相机配置请求 |
| cdc | PASS | 稳定握手快照 |
| monitor | PASS | 输入尺寸/帧率及计数逻辑 |
| csi_monitor | PASS | 实际CSI解包与输入监测 |
| i2c | PASS | 实际I2C总线 |
| osd | PASS | EXP/GAIN/统计、四状态字样/字模、VS快照及全图灰度/边框/框外彩色 |
| pack_boundary | PASS | 原打包边界行为 |
| pixel_interface | PASS | 真实像素接口与原厂模型 |
| roi_guard | PASS | 独立RGB灰度参考、非4对齐、帧异常与恢复 |
| classifier | PASS | 128像素独立SUM/MEAN、阈值两极性/等值/0/255、UNCAL/WAIT、FS/config/lane/短帧/复位/恢复与27位CDC |
| roi_chain | PASS | 七个1024×600实际native RAW10→demosaic/AWB/统计帧，纯仿真T=110分类、短行与长暂停拒绝/恢复 |

人工图像独立数学：SUM/MEAN=5120/40、10240/80、5335/41、7680/60；ROI[1,17)×[2,10)，128像素。框外0/255变化不改变特征，单个255亮点在人工T=60时仍为空侧。该结论只针对人工组成，不是实物反光鲁棒性或准确率。

真实链路首帧因原demosaic学习行跨度导致回放超前而拒绝；帧2/4/6/7有效、均值120/100/120/100；帧3短native行和帧5长暂停回放无效；中间配置无效撤销结果。每个有效大ROI采样131072像素，sum/min/max与独立AWB RGB参考一致。最终链路Warnings=27，仍为原厂网表ECC端口宽度、未使用端口及legacy ready连接等基线提醒，无新增classifier接口警告；Errors=0。仿真时间33,613,540ns，不是实物运行时长。

## TD最终资源与时序

TD{m['td_version']}，{m['device']}，speed3；最终综合及布局布线/bitgen完成，没有error标记。报告为Routed、Slow/Fast两个corner，未修改SDC放宽条件。

| 指标 | 最终值 | 相对扩大框基线 |
|---|---:|---|
| 布线Slice | {r['slice']} / 21216（{r['slice_percent']}%） | +61（约+0.29个百分点） |
| 物理LUT6 | {r['physical_lut6']} | 见phy.area，不能与综合LUT直接混比 |
| 物理寄存器 | {r['physical_reg']} | 见phy.area |
| 综合LUT / REG | {r['synthesis_lut']} / {r['synthesis_reg']} | +23 / +2 |
| ERAM / DSP | {r['eram']} / {r['dsp']} | 均无增加 |
| Setup/Recovery WNS | {t['setup_wns_ns']:.3f}ns | 基线0.962ns |
| Hold WNS | {t['hold_wns_ns']:.3f}ns | 基线0.020ns |
| Setup/Hold TNS | 0 / 0 | 无违例端点 |
| STA coverage | {t['sta_coverage_percent']}% | 基线同值 |

综合层次增量：OSD logic LUT704→720，seq656保持；统计logic LUT290→292、seq229→231、ripple55保持。默认未标定使classifier比较/fresh逻辑被优化掉，因此不以本次资源证明未来启用的全部资源或时序；启用真实配方必须重新TD验证。

全设计最紧0.199ns路径是原DDR控制器usr_clk域复位到pageInfo异步复位端的recovery（报告1329行附近），非新均值比较路径。CSI域SWNS1.777ns。余量为正，但全局低于0.3～0.5ns优化目标，应在后续增量时继续跟踪；本批不重构原DDR底层。

## 约束覆盖边界

constraint_coverage.txt：no clock0、clock definition0、invalid constraint0、combinational loops0、no path constraints0。6条camera_receive/roi_display的payload/req/ack物理预算有效，Dominated数量匹配，Ignored/Shadowed0；本次SDC与前版哈希完全相同。

仍保留基线问题：dummy4、PLL/clock buffer checks7、no input delay37、no output delay63、partial input delay1。coverage中的shadowed/ignored共4类包括既有DDR/FIFO两条无效例外与两条被邮箱细化预算部分覆盖的广义预算，不能理解为6条邮箱预算失效。两个PLL local反馈CRITICAL-WARNING保留。95.06%覆盖率和正WNS不代表完整外部I/O约束关闭。

## 现场状态与下一步

本镜像未下载、未观察实物；INPUT实测分辨率/输入FPS、HDMI输出模式、30分钟错误/花屏/黑屏/冻结/撕裂/重启、Flash启动与断电冷启动全部未测。仅可保留此前小框照片及用户“四键正常”的历史反馈，不能移作本版通过。

下次上板：使用本次冻结bit，先确认512×256灰度框、框外彩色、四键、EXP/GAIN、统计与RECENT UNCAL；调整成像后选一个完整穴位ROI，同条件分别采正常/空穴约10秒的范围和真值。距离/光源可继续调节，但改变后重检配方；不从四张显示器照片65～68/83～84直接设阈值。获得ROI、T、方向和曝光/增益后，再生成启用分类版并重新仿真/TD/现场验证。准确率目标、Logo/字体、30分钟及固化冷启动仍未闭环。

## 证据位置

目录20261004_A均值离线判定_轮次1包含198项source_snapshot、11项ModelSim compile/console/transcript/WLF、TD syn/phy报告和覆盖、仿真OSD预览、输入/证据manifest与文档快照。preview为人工RGB场景，不是相机原始帧。history/failure_notes区分首次重复声明、异步测试刺激问题、隔离目录缺依赖和未发布中间综合；不补造丢失失败波形。
''',encoding='utf-8')
(release/'README.md').write_text(f'''# 离线均值判定准备版（2026-10-04）

镜像：camera_to_dsi_display.bit，{m['bitstream']['bytes']:,}字节；SHA-256 `{bit}`。

已集成均值分类、帧新鲜度和独立RECENT状态行。交付默认CLASS_CALIBRATED=0，应显示RECENT UNCAL；保留512×256中央灰度观测框、框外彩色、EXP/GAIN和四键。正式单穴ROI、阈值、方向、光源/距离尚未标定，本版不输出实物分类。

ModelSim11项通过，TD6.2.168116最终构建：Slice14140（66.65%），31ERAM/8DSP，Setup/Recovery WNS0.199ns、Hold0.020ns、TNS0，STA95.06%；既有I/O/PLL/DDR约束缺口仍待处理。默认禁用比较逻辑被优化；未来启用必须重新TD检查。

本版未上板。用户自行下载后先检查画面、四键、统计和UNCAL，之后选单穴ROI并采同条件有件/空穴数据。结果为最近采集状态，不与DDR显示帧绑定；不能用于运动或逐穴NG。30分钟、实物准确率、固化/冷启动均未测。

完整说明：仓库开发实施/16_A均值判定与离线验证_实施说明.md；证据：开发实施/验收记录/20261004_A均值离线判定_轮次1.md及同名目录。回退版roi_statistics_large_20261003保持。
''',encoding='utf-8')
agents=root/'AGENTS.md';s=agents.read_text(encoding='utf-8');s=s[:s.index('## 当前断点')]+f'''## 当前断点（2026-10-04）

- **目标与断点**：用户“执行”批准15稿离线批次，已完成均值判定/UNCAL/WAIT/PRESENT/EMPTY与独立RECENT行、ModelSim11项和最终TD，冻结待现场。本版默认未标定，保留512×256观测框，未上板、不当完整A验收。Logo/整体字体不在本批。
- **分支/基线**：{m['branch']}，HEAD {m['head']}；fpga/component_inspector。本机工程与冻结198项输入及.al哈希一致；保留原工作区及全部旧release。
- **本批改动**：新增roi_classifier.v/tb_classifier.v；roi_statistics增加sample_new和native frame_start取消旧计算；isp_top/顶层/OSD/.al及四测试/ModelSim脚本接入。正常新FS清分类fresh，保留最近完整调参统计；配置/lane/坏帧仍撤销有效性。27位原子邮箱CSI→HDMI，VS锁存独立状态行；没有DDR帧绑定。
- **验证及证据**：ModelSim SE64 2019.2最终11项PASS，无强制覆盖；128像素非4对齐独立SUM/MEAN、两极性与0/255/等值、亮点/框外/暂停/取消/复位/恢复/27位CDC。真实RAW→选定demosaic/AWB/原厂RAM共7帧1024×600，短行/长暂停拒绝，正常统计及人工分类通过。16说明、15/04/simREADME与20261004_A均值离线判定_轮次1记录/目录含198输入、WLF/日志、TD报告/覆盖、预览及manifest；中间失败/未发布综合有说明，不冒充最终证据。
- **冻结镜像/TD**：release/roi_classifier_20261004/camera_to_dsi_display.bit，1,789,539字节，SHA {bit}。TD6.2.168116，Slice14140/66.65%、ERAM31/DSP8；综合LUT14982/REG15682，物理LUT611533/REG15374；WNS0.199/0.020ns、TNS0、STA95.06%。最紧是原DDR复位recovery，CSI WNS1.777ns；余量低于优化目标，后续跟踪。SDC未放宽，6条邮箱预算有效；基线I/O/PLL/DDR约束缺口保持。
- **参数/未决**：CLASS_CALIBRATED=0，T=0/亮侧/EXP2244/GAIN48均占位。现ROI[256,768)×[172,428)131072像素，不能解释为单穴分类。未来实际单穴ROI/阈值/方向/EXP/GAIN标定后才启用；默认禁用的TD会优化比较，启用须重构建。距离/照明变化需人工作废配方。CSI停流约1～2秒后已标定WAIT，未标定UNCAL。实物准确率、30分钟、固化/冷启动未测。
- **历史基线**：roi_statistics_large_20261003 SHA a20859510c99568d15377d6bb9622090d23ca92d4f275a4282bed70cad466a48，无上板反馈。小框四照片证明灰度/框外彩色/四键正常，EXP2116/GAIN43，图3/4 INPUT1024×600、FPS27/26；不移作本版验收。旧ramfix成功下载反馈保持。历史LM358DR约280mm、光源未测，后续条件未冻结。
- **下一条具体操作**：用户实物可用后下载本次冻结bit，复核观测框/四键/统计/UNCAL；选一个穴位并记录同条件有件/空穴约10秒统计范围与真值。取得ROI/T/方向与配方后，再确认下一批启用范围；不套用显示器照片均值。用户自行下载，助手不操作JTAG/USB。
- **运行进程/设备**：本批ModelSim/TD均已结束，无后台构建；设备由用户管理。
- **提交/推送**：未提交、未推送；既有改动保留。git diff --check仅既有uii2c.v:148行尾空格，未修改该行；不要称已同步。
'''
agents.write_text(s,encoding='utf-8')
docs=[agents,root/'开发实施/15_A单穴判定与离线验证_讨论稿.md',root/'开发实施/16_A均值判定与离线验证_实施说明.md',root/'开发实施/04_FPGA接口与异常处理约定.md',record]
for source in docs:
 target=evidence/'docs_snapshot'/source.relative_to(root);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
shutil.copy2(release/'README.md',evidence/'release_README.md')
shutil.copy2(Path(__file__),evidence/'finish_classifier_docs.py')
shutil.copy2(release/'camera_to_dsi_display.bit.sha256',evidence/'camera_to_dsi_display.bit.sha256')
for entry in m['verified_build_inputs']:
 relative=entry['path'];assert sha(p/relative)==entry['sha256']==sha(evidence/'source_snapshot'/relative)
assert sha(p/'td_project/camera_to_dsi_display.al')==m['project_sha256']
assert sha(release/'camera_to_dsi_display.bit')==bit
m['evidence_files']=[{'path':str(f.relative_to(evidence)).replace('\\','/'),'sha256':sha(f),'bytes':f.stat().st_size} for f in sorted(evidence.rglob('*')) if f.is_file() and f.name!='manifest.json']
(evidence/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for entry in m['evidence_files']:assert sha(evidence/entry['path'])==entry['sha256']
for old_release,expected in [('experiment_20261003','0b1a72e36772b852195fd16275d9540bd694d849a3dae2b110596f2eac6c907a'),('experiment_ramfix_20261003','e8c925afb42ffbcc4bebd5081ec0fb4b4e266a5ca61fb80caa4d0140fef3fb97'),('roi_statistics_20261003','53b6e341c02da01292067eb27bb7d0f456afded30602a449d79496b2051fabce'),('roi_statistics_large_20261003',m['previous_bit_sha256'])]:assert sha(p/'release'/old_release/'camera_to_dsi_display.bit')==expected
print(f'Final docs and handoff saved; {len(m["evidence_files"])} evidence files, 198 inputs and all four previous bitstreams verified')
