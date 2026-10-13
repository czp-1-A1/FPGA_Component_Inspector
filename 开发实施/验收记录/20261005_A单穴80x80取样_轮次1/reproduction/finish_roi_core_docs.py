from pathlib import Path
import hashlib,json,re,shutil

root=Path(__file__).resolve().parents[2];p=root/'fpga/component_inspector'
release=p/'release/roi_core_80_20261005'
evidence=root/'开发实施/验收记录/20261005_A单穴80x80取样_轮次1'
record=root/'开发实施/验收记录/20261005_A单穴80x80取样_轮次1.md'
m=json.loads((release/'manifest.json').read_text(encoding='utf-8'))
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
bit=m['bitstream']['sha256'];r=m['resources'];t=m['timing']
phy=Path(m['build_directory'])/'td_project/camera_to_dsi_display_Runs/phy_1'
report=(phy/'camera_to_dsi_display_pr.timing').read_text(encoding='utf-8')
# Keep actual timing paths in original reports; do not infer coverage from positive WNS.
td=f"Slice {r['slice']}（{r['slice_percent']:.2f}%），ERAM {r['eram']}，DSP {r['dsp']}；Setup/Recovery WNS {t['setup_wns_ns']:.3f}ns、Hold WNS {t['hold_wns_ns']:.3f}ns，TNS均0；STA {t['sta_coverage_percent']:.2f}%"
record.write_text(f'''# A单穴80×80取样验收记录，轮次1

日期：2026-10-05。用户回复“可以”批准17稿范围。结论：离线实现、ModelSim和TD通过，已冻结独立镜像；本版尚未上板，不作完整A阶段通过。

## 版本与输入身份

- 分支：{m['branch']}；HEAD：{m['head']}。工作区未提交、未推送，沿用并保留已有改动。
- 新镜像：fpga/component_inspector/release/roi_core_80_20261005/camera_to_dsi_display.bit，{m['bitstream']['bytes']:,}字节。
- SHA-256：`{bit}`。
- TD {m['td_version']}，{m['device']}，speed3；ModelSim {m['modelsim_version']}。独立构建tmp/roi_core_td_build_20261005。
- 当前工程、隔离构建及证据快照逐项核对198项输入哈希，.al单独核对。相对roi_classifier_20261004仅design_top_wrapper/isp_top/experiment_osd三个综合RTL输入变化；ADC/SDC/.al、统计算法/guard/classifier/CDC/相机四键保持。
- 5个旧release bit哈希另行核对，不覆盖。本目录保存源文件、测试台、12项compile/console/transcript/WLF、完整回归输出、TD日志/资源/时序/约束覆盖/阶段标记、PPM/PNG预览及工具脚本。最终manifest列出全部证据文件SHA。

## 本版行为

绿框为512×256灰度观察区[256,768)×[172,428)；青框为80×80核心取样区[472,552)×[260,340)，6400像素。MEAN/MIN/MAX/VALID仅来自青框，RECENT旁新增CYAN 80X80。青框内部仍为灰度，绿框以外保留彩色。

当前仍CLASS_CALIBRATED=0，RECENT UNCAL；T=0/亮侧/EXP2244/GAIN48为占位或候选条件。只有一套统计、没有新增帧缓存；6400满量程和1632000，沿用28位sum/20位count与28拍除法。新FS取消未完成计算，最近完整调参统计保留；异常及配置更新失效。统计为最近完成采集，不绑定DDR显示帧。

## ModelSim

默认命令12项全PASS，未使用TieUnusedAwbRamInputs。完整runner终结标志为`PASS ModelSim: all 12 tests, including original vendor ERAM model`。

| 测试 | 本轮结果 |
|---|---|
| controls / cdc / monitor / csi_monitor / i2c | 全PASS，四键、原子跨域、输入测量、实际CSI/RAW解包与实际I2C ACK/NACK回归 |
| pack_boundary / pixel_interface | 全PASS，原厂RAM/GSR及实际AWB/打包、ready低、气泡、未完整行特征保持 |
| roi_guard / classifier | 全PASS，非4对齐ROI、完整性、配置/lane/FS取消恢复、两极性/等值/0/255及27位邮箱 |
| roi_core | PASS，6400像素独立SUM/MEAN/MIN/MAX参考；框外黑/白结果一致；255满量程、valid气泡 |
| osd | PASS，1024×600逐像素绿框/灰度/青框/框外彩色、CYAN字样、两级HS/VS/DE及ENABLE=0旁路；四状态VS快照 |
| roi_chain | PASS，真实7帧1024×600 native RAW→选定demosaic/AWB/原厂ERAM/统计；6400参考、短行/长暂停拒绝、配置失效/恢复；人工T=110仅测试 |

启动帧按旧demosaic学习行为拒绝，后续完整帧有效。仿真预览已检查，表示布局与逻辑，不是实物成像或物理MIPI/DDR/HDMI验证。

## TD资源、时序和约束

{td}。

综合LUT {r['synthesis_lut']} / REG {r['synthesis_reg']}；物理LUT6 {r['physical_lut6']} / REG {r['physical_reg']}。资源没有增加ERAM或DSP，未增加第二套统计。最紧建立路径位于MIPI_RX_BYTE_CLK域，u_roi_statistics/add12_syn_124→beat_hi_reg[7]，WNS1.437ns；建立/恢复和保持无负余量，最终路径详见td/phy_1/camera_to_dsi_display_pr.timing，不用布局估计代替布线结果。

最终约束覆盖分类计数与旧发布基线一致：dummy4、PLL/clock7、无input delay37、无output delay63、partial input1、shadowed/ignored总4（既有DDR/FIFO2及被专用预算覆盖的通用预算2）。无clock/invalid constraint/组合环等为0。6条专用邮箱payload/req/ack预算均Matched=Dominated>0、Ignored=Shadowed=0。仍有两PLL本地反馈告警，未放宽SDC，不宣称全部路径覆盖。当前默认未标定比较会被优化，未来启用须新TD验证。

## 中间工具调用记录

首次ModelSim相对Tee日志被runner Push-Location解析到sim下，未得到完整回归；改绝对日志路径后全部通过。首次TD带-f参数只报source参数错误，没有执行综合；正确直接传build.tcl后综合及物理阶段通过。原始TD调用失败日志和最终retry日志都保留，细节见history/invocation_notes.md。未出现本轮RTL断言失败，未放松测试。

## 待用户上板与标定

1. 自行下载上述新镜像，确认大绿框、小青框、框外彩色、四键、统计VALID及UNCAL。
2. 候选130mm，先沿用EXP2244/GAIN48，固定同一焦点/光源与载带高度；同种载带方向及观察面一致。
3. 单个穴位内部核心对准青框，排除邻穴、大定位孔和台面。有件/空穴各静止约10秒，记录MEAN最低/最高、MIN/MAX、VALID、INPUT FPS、L/F/I/G和真值，每类至少重复一次摆放。青框无需包整穴。
4. 小框不适配先反馈边界再调整ROI；分布有间隔后另确认T/方向及配方，另批启用并验证准确率。

130mm三轮大框照片独立保留，不用于新单穴T；轮次3批准前17稿保留原字节快照，其历史proposal_approved=false反映当时状态。本版实物准确率、30分钟、固化断电启动和A整合后冷启动均未测。
''',encoding='utf-8')
(release/'README.md').write_text(f'''# 单穴80×80取样版，2026-10-05

下载文件：camera_to_dsi_display.bit（{m['bitstream']['bytes']:,}字节）。
SHA-256：{bit}

保留512×256灰度绿框，增加中央80×80青框[472,552)×[260,340)。MEAN/MIN/MAX/VALID只统计青框内6400像素，CYAN 80X80标识归属，默认RECENT UNCAL。相机1024×600和四键保持。

ModelSim默认12项全PASS；TD {m['td_version']}最终综合/布局布线通过，{td}。完整输入198项及.al哈希核对；约束覆盖缺口保持，没有放宽SDC。此版尚未上板。

用户自行下载，固定130mm候选条件与同一光源/焦点，先用EXP2244/GAIN48，将单穴核心区域对青框；有件/空穴各记录约10秒MEAN范围/MIN/MAX/VALID/输入FPS/错误计数，每类重复摆放一次。小框不需包整穴，排除定位孔/邻穴/台面。数据确认后再定阈值，当前不输出实际分类。

说明：开发实施/18_A单穴80x80取样_实施说明.md。验收记录与证据：开发实施/验收记录/20261005_A单穴80x80取样_轮次1.md及同名目录。回退版roi_classifier_20261004保持。30分钟、实物准确率与固化冷启动未测，未提交或推送。
''',encoding='utf-8')
proposal=root/'开发实施/17_A单穴ROI实物标定_讨论稿.md'
text=proposal.read_text(encoding='utf-8').replace('实现与验证进行中。','RTL、12项ModelSim与TD已完成并冻结，细节见18说明及20261005_A单穴80x80取样_轮次1记录；实物待验证。')
proposal.write_text(text,encoding='utf-8')
agents=root/'AGENTS.md';s=agents.read_text(encoding='utf-8')
s=s.replace('最新已发布基线roi_classifier_20261004','上一冻结基线roi_classifier_20261004')
s=s.replace('12项ModelSim通过、综合完成，独立TD布局布线进行中；尚未冻结或上板，不当作完整A验收。','12项ModelSim及最终TD通过，独立版本已冻结，等待用户下载采样；未上板，不当作完整A验收。')
s=s.replace('最终复制待TD完成。','已冻结至20261005_A单穴80x80取样_轮次1同名证据目录，198项输入/.al及12项日志/WLF/TD报告/文档快照完整。')
s=s.replace('ERAM/DSP及最终Slice/WNS以物理报告为准。',td+'。')
start=s.index('- **下一条具体操作**：');end=s.index('- **提交/推送**：',start)
s=s[:start]+f'''- **冻结镜像**：release/roi_core_80_20261005/camera_to_dsi_display.bit，{m['bitstream']['bytes']:,}字节，SHA {bit}。198输入/.al与工程和隔离构建逐项一致。约束覆盖计数与旧版一致，6专用邮箱预算有效；基线缺口保持。5旧bit哈希验证保留。
- **下一条具体操作**：用户自行下载本次冻结bit，将同一穴内核心位置对青框，在130mm/EXP2244/GAIN48和相同光源/焦点下两类各静止10秒、至少重复摆放一次，记录MEAN范围/MIN/MAX/VALID/INPUT FPS/L/F/I/G。小框不适配则反馈边界；取得单穴分布后另行确认T/方向和启用范围。准确率/30分钟/固化冷启动未测。
- **运行进程/设备**：本批ModelSim/TD均已结束，无后台构建；设备由用户管理，助手不操作JTAG/USB。最终说明18及验收记录已保存。
'''+s[end:]
agents.write_text(s,encoding='utf-8')
for source in [agents,proposal,root/'开发实施/18_A单穴80x80取样_实施说明.md',root/'开发实施/04_FPGA接口与异常处理约定.md',record]:
    dst=evidence/'docs_snapshot'/source.relative_to(root);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dst)
for name in ['README.md','camera_to_dsi_display.bit.sha256']:shutil.copy2(release/name,evidence/('release_'+name))
shutil.copy2(Path(__file__),evidence/'reproduction'/Path(__file__).name)
shutil.copy2(root/'tmp/modelsim_probe/checkpoint_roi_core.py',evidence/'reproduction/checkpoint_roi_core.py')
for entry in m['verified_build_inputs']:
    relative=entry['path'];assert sha(p/relative)==entry['sha256']==sha(evidence/'source_snapshot'/relative)
assert sha(p/'td_project/camera_to_dsi_display.al')==m['project_sha256']
assert sha(release/'camera_to_dsi_display.bit')==bit
for entry in m['simulation_library']:assert sha(Path(entry['path']))==entry['sha256']
olds=[('experiment_20261003','0b1a72e36772b852195fd16275d9540bd694d849a3dae2b110596f2eac6c907a'),('experiment_ramfix_20261003','e8c925afb42ffbcc4bebd5081ec0fb4b4e266a5ca61fb80caa4d0140fef3fb97'),('roi_statistics_20261003','53b6e341c02da01292067eb27bb7d0f456afded30602a449d79496b2051fabce'),('roi_statistics_large_20261003','a20859510c99568d15377d6bb9622090d23ca92d4f275a4282bed70cad466a48'),('roi_classifier_20261004',m['previous_bit_sha256'])]
for name,expected in olds:assert sha(p/'release'/name/'camera_to_dsi_display.bit')==expected
m['previous_bitstreams_verified']=[{'release':n,'sha256':s} for n,s in olds]
m['evidence_files']=[{'path':str(f.relative_to(evidence)).replace('\\','/'),'sha256':sha(f),'bytes':f.stat().st_size} for f in sorted(evidence.rglob('*')) if f.is_file() and f.name!='manifest.json']
(evidence/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for entry in m['evidence_files']:assert sha(evidence/entry['path'])==entry['sha256']
print(f"Final docs/checkpoint complete; {len(m['evidence_files'])} evidence hashes, 198 inputs, .al and five old bitstreams verified.")
