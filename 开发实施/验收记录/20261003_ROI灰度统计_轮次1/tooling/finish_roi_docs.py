from pathlib import Path
import json

root = Path(__file__).resolve().parents[2]
project = root / 'fpga/component_inspector'
release = project / 'release/roi_statistics_20261003'
m = json.loads((release / 'manifest.json').read_text(encoding='utf-8'))
t = m['timing']; r = m['resources']; bit = m['bitstream']; sha = bit['sha256']
record = root / '开发实施/验收记录/20261003_ROI灰度统计_轮次1.md'
record.write_text(f'''# A帧保护＋ROI灰度统计：本机验证与交付记录

2026-10-03。用户批准“帧保护＋ROI灰度处理与统计”，临时中央ROI为[384,640)×[236,364)，256×128/32768像素。正常/空穴分类尚未实现。由用户下载并完成现场操作。

## 版本绑定

- 工程：fpga/component_inspector/td_project/camera_to_dsi_display.al。
- 分支：hx1p35a-contest-work；HEAD f87ccf1c6a38e84b58a4f86cecd532a71ae56e89；未提交工作区。
- TD 6.2.168116，PH1P35MDG324，速度级3；ModelSim SE-64 2019.2，原厂ERAM/GSR及实际ISP网表。
- 交付：release/roi_statistics_20261003/camera_to_dsi_display.bit，{bit['bytes']:,}字节，SHA-256 `{sha}`。
- 197项工程输入逐字节核对当前源码与独立构建目录，另存工程.al及仿真源码；完整清单、工具库校验及证据校验见同名目录manifest.json。
- 独立构建：tmp/roi_statistics_cdc_td_build_20261003。旧RAM修复版及旧实验版保留。

## 验证结果

| 项目 | 结果及证据范围 |
|---|---|
| ModelSim controls/cdc/monitor/csi_monitor/i2c | 通过；四键、邮箱原子性、真实CSI→RAW10输入监测、实际I2C字节及ACK/NACK |
| OSD | 通过；全1024×600框内灰度、绿色边框、框外原色与无效横线；两拍显示流水 |
| pack_boundary/pixel_interface | 通过；原有回放/打包特性保留；其PASS不表示原链路任意间断都安全 |
| roi_guard | 通过；独立RGB参考、非4对齐ROI、首末拍、双方完成先后、FE重合、缺列/缺行/长行、重复SOF、进度超前、配置/通道异常、抢占恢复；流水化后补测计算中调参取消待发布样本 |
| roi_chain | 通过；真实native RAW10→uial2axis→demosaic→AWB→打包/统计，7个1024×600帧，短valid暂停、ready低、短行、长暂停及恢复；独立逐像素统计参考 |
| TD综合 | 完成，保存gate资源/建立/保持及约束覆盖报告 |
| TD布局布线 | 完成，建立WNS {t['setup_wns_ns']:.3f}ns、保持WNS {t['hold_wns_ns']:.3f}ns、两项TNS均0；有约束路径通过 |
| 资源 | Slice {r['slice']}（{r['slice_percent']:.2f}%），31 ERAM、8 DSP；较旧RAM修复版13525 Slice增加{r['slice']-13525} |
| 约束覆盖 | STA {t['sta_coverage_percent']:.2f}%，no_clock=0、invalid_constraint=0、combinational_loop=0；新增两邮箱6条物理延迟约束均有效 |
| 本版上板/30分钟/Flash/冷启动 | 未测。旧RAM修复版的画面清楚与四键正常反馈不转移为本版结论 |

10项ModelSim覆盖分批执行：最终界面等9项、统计流水化后roi_guard/roi_chain两项、补充取消计算的roi_guard单项。未启用强制RAM输入覆盖。真实全帧测试仅记录顶层WLF；不模拟物理MIPI接收器、DDR和HDMI发送器。仿真预览为布局验证图，不是实物帧。

### 全帧观测

| 帧 | 输入情形 | 提交次数 | 有效位 | MEAN/MIN/MAX |
|---|---|---:|---:|---|
| 1 | 启动时原demosaic学习行跨度、回放超前 | 0 | 0 | 不发布 |
| 2 | 正常120灰度 | 1 | 1 | 120/120/120 |
| 3 | RAW第100行只有192拍，AWB仍回放153600拍 | 0 | 0 | 存储保留旧值但显示WAIT/横线 |
| 4 | 正常100灰度 | 1 | 1 | 100/100/100 |
| 5 | RAW第100行暂停240拍，固定回放超前 | 0 | 0 | 不发布 |
| 6 | 正常120灰度 | 1 | 1 | 120/120/120 |
| 7 | 正常100灰度 | 1 | 1 | 100/100/100 |

### 失败与修复保留

1. 首次真实链路测试台使用SystemVerilog保留词packed，编译失败。改名packed_data，失败日志独立保留。
2. 首次统计组合路径过长，布局布线setup WNS -2.760ns/TNS -63.328ns，不发布该bit。改为灰度、平衡归约两级流水，控制信号同拍延迟；重新验证统计和帧作废。输入快照与TD报告在failed_td。
3. 流水化后的TD约束检查发现新增邮箱约束被set_clock_groups遮蔽；该镜像也不发布，快照及报告在failed_cdc。CSI与系统跨域改用19ns/8ns物理路径预算，专用邮箱约束进一步限定。重新综合/布局布线，6条新增约束均Dominated、无Ignored/Shadowed。通用预算有2条被专用预算部分Shadowed，属于更具体约束接管，报告保留。

## 约束未决及行为限制

保留基线dummy节点4、PLL/clock检查7、DDR FIFO被时钟组忽略的两条例外；外部输入delay缺37、输出delay缺63、部分输入delay1。未根据假定板级延迟补填数字，不声称全工程约束闭合。最终报告的4条Shadowed/Ignored中，2条是上述通用预算被专用预算接管，另2条是基线DDR例外。

统计表示最近完整有效采集帧，不绑定当前DDR显示帧。停CSI时钟后约1～2秒由独立FPS门控显示WAIT；没有毫秒级停流响应保证。启动可能先等第二帧；调参/配置变化作废样本，传感器实际稳定时间待现场观察。临时ROI不能当已标定单穴ROI或分类准确率证据。

## 现场待填写

| 项目 | 本版结果 |
|---|---|
| 下载方式、日期、镜像SHA核对 | 待用户操作 |
| 实物画面、中央框内灰度/框外原色、框位置 | 未测 |
| KEY1～4曝光−/＋、增益−/＋ | 未测 |
| INPUT宽×高、独立输入FPS、HDMI输出模式 | 未测；不能拿显示器刷新率替代输入FPS |
| 正常/空穴同条件MEAN/MIN/MAX波动范围 | 未测；见11记录表 |
| 30分钟首尾L/F/I/G、花屏/黑屏/冻结/撕裂/重启 | 未测 |
| Flash固化、启动方式、断电自动运行 | 未测；最终A整合后再做冷启动 |

LM358DR、约280mm、EXP1460、报告GAIN90（代码上限89待核对）、光源未测，均是既有临时实验条件。本轮不虚构现场数据。下一步由用户下载此冻结版本，将目标放入临时框，先验证显示及四键，再记录正常/空穴静止统计分布，随后确认正式ROI/分类范围。
''', encoding='utf-8')

(release / 'README.md').write_text(f'''# 临时ROI灰度统计版（2026-10-03）

下载文件：camera_to_dsi_display.bit，{bit['bytes']:,}字节。SHA-256：`{sha}`。

中央256×128临时ROI：[384,640)×[236,364)，框内灰度、边框绿色、框外原色；上方EXP/GAIN与ROI MEAN/MIN/MAX、VALID/WAIT，底部保留独立输入FPS及验收计数。四键曝光−/＋、增益−/＋。本版没有正常/空穴分类。

ModelSim 10项通过，TD综合及布局布线完成。最终建立/保持WNS {t['setup_wns_ns']:.3f}/{t['hold_wns_ns']:.3f}ns，TNS0；Slice {r['slice']}（{r['slice_percent']:.2f}%）、31 ERAM、8 DSP。197项当前/构建输入一致，快照与报告见开发实施/验收记录/20261003_ROI灰度统计_轮次1，manifest绑定冻结版本。

上板由用户操作，尚未现场验收。启动首帧可能WAIT，完整后VALID；调参时等待新样本。数值是最近有效采集统计，尚未绑定DDR显示帧。外部I/O、PLL及两项DDR例外约束仍待核验；30分钟、Flash固化及冷启动未测。保留上一已确认画面/四键正常的experiment_ramfix_20261003作为对照。

先将同一目标穴位放在中央框内，确认显示与四键，再在同一距离、EXP、GAIN、光源下分别记录正常和空穴MEAN/MIN/MAX约10秒的波动范围；WAIT不作统计样本。距离和光照可继续逐步调整，每次改变一个变量并记新条件ID。
''', encoding='utf-8')

p = root / 'AGENTS.md'
s = p.read_text(encoding='utf-8')
start = s.index('## 当前断点（2026-10-03）')
s = s[:start] + f'''## 当前断点（2026-10-03）

- **目标与断点**：用户批准帧保护＋ROI灰度统计及中央临时256×128框。代码、ModelSim及最终TD构建完成，待用户下载ROI版与现场统计；没有分类/阈值/Logo或字体美化实施，不当作完整A验收。
- **分支/基线**：hx1p35a-contest-work，HEAD f87ccf1c6a38e84b58a4f86cecd532a71ae56e89；正式工程fpga/component_inspector。本机D:/BaiduNetdiskDownload/HX1P35A_Contest_202606/FPGA_Component_Inspector。既有改动与证据保留。
- **改动文件**：新增roi_frame_guard.v/roi_statistics.v及两测试台；根awb独立O_pixel_sof；isp_top/design_top_wrapper接保护、配置与结果邮箱；experiment_osd显示灰度框/统计，参数仅EXP/GAIN，底部监测。zhenghe/line_buffer只读RAM web/dib接零。工程.al/SDC接入；sim脚本、run_roi.do、10～14/04/11文档与证据更新。四键映射保留。
- **验证与证据**：ModelSim10项通过；实际native RAW10→真实demosaic/AWB/原厂ERAM/打包统计7帧1024×600，启动学习帧拒绝，正常统计独立参考一致，短行/長暂停回放拒绝并恢复；单元另测非4对齐ROI、SOF抢占、配置取消计算。新库未强制覆盖，未模拟物理MIPI/DDR/HDMI。证据开发实施/验收记录/20261003_ROI灰度统计_轮次1含197项输入快照、10项WLF/日志、最终及两次未发布TD快照/报告、预览/manifest；失败不覆盖。
- **冻结镜像/TD**：release/roi_statistics_20261003/camera_to_dsi_display.bit，{bit['bytes']:,}字节，SHA-256 {sha}；197项当前/构建输入逐字节一致。TD6.2.168116，Slice{r['slice']}（{r['slice_percent']:.2f}%）、31ERAM/8DSP，Setup/Hold WNS {t['setup_wns_ns']:.3f}/{t['hold_wns_ns']:.3f}ns、TNS0、STA{t['sta_coverage_percent']:.2f}%。新增6条邮箱物理预算有效；2条通用预算部分由专用预算接管。基线dummy4、PLL7、DDR忽略例外2、input delay缺37/output缺63/partial input1仍待核验。
- **旧实物基线**：experiment_ramfix_20261003 SHA e8c925afb42ffbcc4bebd5081ec0fb4b4e266a5ca61fb80caa4d0140fef3fb97由用户确认成功下载、画面清楚且四键正常；旧experiment_20261003也保留。该反馈不移作ROI版本上板通过。
- **现场条件/未决**：LM358DR，约280mm、机构60～400mm可调、EXP1460、报告GAIN90但代码上限89待核对、光源未测、原始帧采集不确定。临时ROI[384,640)×[236,364)，gray=floor((R+2G+B)/4)；显示最近有效采集统计，未绑定DDR帧。CSI时钟停流约1～2秒WAIT。正式单穴ROI、分类阈值、换样作废/显示帧绑定、准确率目标未冻结；INPUT/FPS/HDMI模式、30分钟、Flash/冷启动未测。
- **下一条具体操作**：用户下载冻结ROI bit，验证框内灰度/框外原色、四键及VALID恢复；同条件正常件/空穴静止10秒记录MEAN/MIN/MAX范围并调整成像变量，填11现场表。发现问题按冻结SHA复现修复；下一分类批次先明确单穴ROI与样本特征，再由用户确认范围。
- **运行进程/设备**：本轮ModelSim/TD构建已结束；Codex不操作下载服务/USB，硬件由用户管理。
- **提交/推送状态**：未提交/推送；保留既有工作区。新源码/仿真/文档/证据及新旧release一同交接。git diff --check仅既有uii2c.v:148行尾空格，本轮未触碰。
'''
p.write_text(s, encoding='utf-8')
print('Release README, hardware acceptance record and AGENTS checkpoint saved')
