from pathlib import Path
import json, hashlib, subprocess
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
release=project/'release/led_presence_demo_v1_20261007'
record=root/'开发实施/验收记录/20261007_A3528临时判定_轮次1'
data=json.loads((release/'manifest.json').read_text(encoding='utf-8'))
bitsha=data['bit']['sha256']
readme=f'''# 3528 LED临时有件／空穴第一版

用于黑色载带白色3528 LED，使用历史黑带白件照片显示的MEAN作临时起点。新镜像尚未上板，不是正式标定版。

1. 下载本目录`camera_to_dsi_display.bit`，核对`SHA256.txt`。本轮没有自动烧录或写入Flash。
2. SW1上、SW2下，核对MODE=GRAY，EXP2244半行、GAIN48档号，距离约130mm，保持光源和焦点。
3. 青框80×80落在一个待测料穴内，避开定位圆孔、桌面、带边和邻穴；静止后等新采样。
4. MEAN≥58显示绿色“有件”，MEAN<58显示红色“空穴”。曝光／增益改变会撤销旧类别；恢复2244/48后等待新完整样本。无效或等待时不要按旧结果判定。

SW组合仍为RAW／GRAY／EDGE／GRAY+EDGE，四种视图均使用这套LED灰度判定，不会自动识别黑件或透明载带。页脚T80是边缘显示阈值，存在判定阈值是58。界面显示最近完整采样，未绑定DDR当前显示帧。

历史有件MEAN78～88、空穴36～37，旧图当时料号未核验且未测完整静止范围；T58供演示，青框对偏或光学改变仍可能误判。先现场分别试有件／空穴，记录新bit下MEAN和真值，后续机构固定再重测阈值。

本机TD6.2.168116综合／布局布线完成，setup+1.265ns、hold+0.020ns、TNS0，Slice16529/21216（77.91%）、ERAM48/108、DSP8/40；9项定向ModelSim回归通过，原厂RAM模型。约束覆盖94.55%，既有DDR PLL/I/O/异常覆盖问题保留，不能称约束完全闭合或实物验证通过。

镜像1789539字节，SHA-256：`{bitsha}`。
代码为基于HEAD3be3967的未提交工作区快照，生产代码只启用CLASS_CALIBRATED=1和T58；207输入SHA见build_inputs.json，报告及冻结源码见仓库开发实施/验收记录/20261007_A3528临时判定_轮次1。

稳定回退：相邻`../edge_tail_fix_20261007/camera_to_dsi_display.bit`，SHA-256 `bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65`。原稳定EDGE帧尾修复字节保留。
'''
(release/'README.zh-CN.md').write_text(readme,encoding='utf-8')
md=f'''# 20261007 A3528临时判定，轮次1

## 目标、授权与身份

用户明确要求用之前的图试试、先生成第一版代码。先实现3528 LED黑带白件有件／空穴，已有视频修复和取样界面保留。历史T58此前未批准的记录保留为当时状态；此次明确授权允许选临时阈值并生成原型，未要求先完成机构建模或新配对采样。

- 分支：lj4747-contest-work；HEAD基线3be3967f2457622566fb20b7cef3aa5038e7d885，队员冻结源码43a3da6cf36da923835f4e7fb5f03e3bdb5c779f。
- 生产变更：top的CLASS_CALIBRATED=1、CLASS_THRESHOLD=58及说明；其余206/207输入与稳定EDGE修复版一致，未改约束/IP。
- 测试变更：tb_classifier增加历史值和57/58/59边界；原测试LF风格已恢复并重跑该项，初次日志另保留history_classifier_eol。
- 代码状态：未提交／未推送工作区；207输入、6阶段脚本、冻结源码和日志记录版本，不能称新提交已推送。
- 工具：本机TD6.2.168116、ModelSim2019.2、PH1P35MDG324 speed3；不是队员TD6.2.178840的旧报告。
- bit：release/led_presence_demo_v1_20261007/camera_to_dsi_display.bit，1789539字节，SHA `{bitsha}`。

## 阈值及范围

130mm历史有件85/88/78/82，空穴36/37/37/37/36；图8重复图6，旧料号未核验，未记录完整10秒范围和重复摆放。白件高侧规则MEAN≥58有件、<58空穴，EXP2244／GAIN48绑定，青框80×80。照片上的MEAN用于比较器回放，不将手机JPEG当相机RAW重新跑ISP；没有独立准确率指标。当前3528型号来自用户说明。

## 软件与构建结果

| 项目 | 结果 |
|---|---|
| 9项ModelSim | classifier、display_state、controls、roi_core、roi_chain、osd、observation、sobel_tail、isp_writer_stop全部PASS；classifier最终LF文件单项复跑PASS |
| 实际链路 | 原厂ERAM、真实RAW→demosaic/AWB，1024×600完整帧/异常恢复；4模式、尾行和打包；OSD中文/Logo/三拍RGB同步独立参考通过 |
| TD综合／物理 | 两阶段退出0；.opt_gate.end.f、.bitgen.end.f，最终Routed慢/快角setup/hold检查 |
| setup／hold WNS | +1.265ns／+0.020ns，TNS均0，违例终点0 |
| 物理资源 | Slice16529/21216=77.91%，LUT6 14015，REG17495，ERAM48/108，DSP8/40 |
| STA覆盖 | 94.55%，不是100% |
| 完整性 | 207工作区／隔离副本SHA一致，旧稳定bit未变；主manifest包含364证据文件SHA |
| 实物／视频／冷启动 | 新bit均未测，本轮未烧录、不操作用户设备 |

寄存器邮箱max-delay约束均有匹配且ignored=0；有些握手条目由更强约束shadow，不能只凭表面dominated0判无覆盖。既有7项DDR PLL频率、39无input-delay、63无output-delay、局部PLL反馈及时钟网络告警保留。旧本机诊断版已为dummy4/shadowed9，本轮仍4/9；队员新工具报告2/5，属于不同工具/优化报告，不能冒称新类比导致回退。独立只读复核另记本轮independent_review.json，最终内容以实际返回为准。

## 封存、可复现与下一步

本轮隔离构建tmp/led_presence_demo_v1_td_20261007，.prj与当前.al的67项源路径集合核对，207输入含依赖；生产top修改前副本另存before。首次准备用XML解析旧.al的未转义P&R失败，改为仅提取File Path后成功，工程.al未改。生产top保持原CRLF，diff检查按cr-at-eol处理；未放宽时序或启用RAM测试强制覆盖。

冻结目录含source_snapshot、td_reports、simulation/源文件与日志、原厂模型SHA、build_scripts。WLF/生成PPM仍留隔离tmp，不纳入本次证据目录。流程脚本拒绝覆盖已有封存记录；独立复测需复制到新ASCII目录。现有9项定向回归不是runner全部18项，模拟DDR／MIPI不代替真实板级PHY验收。

用户接下来用新bit选择GRAY并核对EXP2244／GAIN48，人工将单穴对准青框，分别确认有件／空穴真值，静止后记录MEAN和结果。若误判按相同覆盖方式收集新bit读数再调临时阈值。另两类、正式固定机构阈值、连续30分钟视频、约束闭合和固化冷启动均单列后续，不阻塞这版临时试用，不声明阶段A全部通过。
'''
(record.with_suffix('.md')).write_text(md,encoding='utf-8')
agents=root/'AGENTS.md'
s=agents.read_text(encoding='utf-8')
s=s[:s.index('## 当前断点')]+f'''## 当前断点（2026-10-07，3528 LED临时判定第一版已生成）

- **目标与断点**：用户明确授权“有之前的图，你先用之前的图试试，先生成第一版代码”，已完成3528 LED临时有件／空穴代码、9项定向仿真与本机TD bit。历史黑带白件读数选T58，不再待新图/阈值二次确认。下一步由用户实物试用；另两类、机构完全固定后的精进标定后续处理。
- **分支/代码基线**：lj4747-contest-work，HEAD及已获取origin仍3be3967f2457622566fb20b7cef3aa5038e7d885；队员冻结源码43a3da6cf36da923835f4e7fb5f03e3bdb5c779f。207输入仅design_top_wrapper.v变化，现有EDGE尾修复、其他RTL/IP/ADC/SDC不变。生产只CLASS_CALIBRATED=1、T58及注释，EXP2244/GAIN48高侧判定不变；测试tb_classifier增加历史及57/58/59边界。
- **交付与证据**：新release/led_presence_demo_v1_20261007/camera_to_dsi_display.bit，1789539字节，SHA {bitsha}；README/SHA256/manifest/build_inputs齐备。冻结记录开发实施/验收记录/20261007_A3528临时判定_轮次1.md及同名目录，364主证据SHA、源码/TD报告/仿真日志；29实施说明、协议28按最新授权更新。当前构建元数据指向本轮隔离构建tmp/led_presence_demo_v1_td_20261007，source_commit为null+base_head，明确未提交工作区快照。
- **验证结果**：ModelSim2019.2原厂RAM模型，classifier/display_state/controls/roi_core/roi_chain/osd/observation/sobel_tail/isp_writer_stop九项PASS，classifier LF最终文件复跑PASS。真实1024×600 RAW/AWB/异常恢复、四视图及EDGE尾行/OSD通过，非板上结果。TD6.2.168116两阶段退出0、bitgen完成；setup+1.265ns、hold+0.020ns、TNS0；Slice16529/21216=77.91%、ERAM48、DSP8、REG17495、LUT6 14015，STA94.55%。不同于队员TD6.2.178840旧报告，不将跨工具资源差当纯功能增量。
- **临时阈值与条件**：历史130mm有件85/88/78/82、空穴36/37/37/37/36，图8重复图6、旧料号未核验、未测完整静止范围；T58仅当前3528演示起点，MEAN≥58有件、<58空穴。当前物料/距离来自用户；青框[472,552)×[260,340)人工对准单穴，避开定位孔/桌面/邻穴。统计AWB后、EDGE着色前；SW只切RAW/GRAY/EDGE/GRAY+EDGE，四种都用这套LED灰度判定。页脚T80仍是边缘显示阈值。配置/坏帧/停输入/切SW现有撤销及等新样本门控不变，不识别对偏或光学变化。
- **未决事项**：新bit未上板；正式准确率、30分钟连续视频、机构固定、冷启动未通过。本轮7项DDR PLL频率、39无input-delay、63无output-delay及局部时钟/例外覆盖问题保留；本机dummy4/shadowed9与旧本机相同，寄存器邮箱预算matched/ignored0需结合shadow来源复核，未修改SDC。既有探索图全为有件不构成空穴真值。阶段A未全部验收。
- **下一条具体操作**：用户加载本轮新bit并核SHA，SW1上/SW2下MODE=GRAY，EXP2244/GAIN48、约130mm，单穴对准青框；静止后试人工真值有件／空穴并发新bit照片，记录MEAN/结果，若误判用相同覆盖对照调临时阈值。后续再扩展另两类，不能拿旧bit图片称新bit实测通过。
- **运行中进程/设备**：本轮综合session32779、物理83290、仿真65465及最终classifier均已退出0，无助手TDCLI/vsim/vlog运行；用户TD27224、bw35732、hwserver38424保留，未关闭/操作。未JTAG下载、写Flash或冷启动；现场视频/真值由用户负责。
- **提交/推送状态**：本轮RTL/test/current_codex_build/AGENTS/协议28/29/release/记录及此前接收/分析记录未提交、未推送，暂存区空，历史未跟踪资料保留。未新增用户线程、外部消息或自动任务。唯一实现端为root，代理只读复核。最终SHA/JSON/diff检查及独立复核写verification.json/independent_review.json后交付。
'''
agents.write_text(s,encoding='utf-8')
(record/'README.zh-CN.md').write_text(readme,encoding='utf-8')
(record/'AGENTS_checkpoint.md').write_bytes(agents.read_bytes())
print('Wrote release guide, validation record, implementation note and final checkpoint')
