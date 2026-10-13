from pathlib import Path
import json
root = Path(__file__).resolve().parent.parent
protocol = root / '开发实施/28_A临时固定条件有件空穴演示_准备协议.md'
data = protocol.read_text(encoding='utf-8')
old = '当前确认状态：用户随后回复“确认”，本轮取样方案已确认。下一步等待3528 LED同位置有件／空穴各3张对照；当前尚无这两组读数，未选择具体阈值，此次确认不记录为某个尚未提出的阈值获批。'
new = '授权更新（2026-10-07）：用户随后明确要求“有之前的图，你先用之前的图试试，先生成第一版代码”。本轮已授权直接使用历史黑带白件130mm照片的读数选临时阈值并生成原型，不再等待新的配对照片或二次阈值确认。历史有件MEAN78～88、空穴36～37，先选T58、高侧有件，并绑定EXP2244/GAIN48。旧图当时料号未核验，用作当前3528 LED演示的临时起点；不是当前条件的正式标定或独立准确率。以下采样方法仍供后续调参/机构固定后使用，其中“待新图/待确认/不生成”的原准备限制已由本次明确授权替代。实现及构建证据见29说明和20261007_A3528临时判定_轮次1记录。'
assert old in data
protocol.write_text(data.replace(old,new), encoding='utf-8')
agents = root / 'AGENTS.md'
data = agents.read_text(encoding='utf-8')
header = '## 当前断点'
data = data[:data.index(header)] + '''## 当前断点（2026-10-07，3528 LED临时判定第一版正在构建）

- **目标与断点**：用户最新明确授权“有之前的图，你先用之前的图试试，先生成第一版代码”。先为3528 LED黑带白件启用现有均值分类与取样界面；使用历史黑带白件130mm照片的临时T58，不再等待新照片/二次确认。另两类、机构固定后正式标定、长时间视频验收后续分别处理。
- **分支/代码基线**：lj4747-contest-work，HEAD及已获取origin为3be3967f2457622566fb20b7cef3aa5038e7d885；队员冻结源码43a3da6cf36da923835f4e7fb5f03e3bdb5c779f。207输入除design_top_wrapper.v外与edge_tail_fix_20261007冻结输入一致；旧EDGE尾修复、其他RTL/IP/约束未变。
- **改动文件**：design_top_wrapper.v只把CLASS_CALIBRATED=1、CLASS_THRESHOLD=58并注释临时来源，CLASS_PRESENT_HIGH=1、EXP2244/GAIN48及80×80核心不变；sim/tb_classifier.v增加历史读数及57/58/59边界回归。协议28按最新授权更新；本断点更新。修改前top/test/构建元数据和AGENTS在tmp/led_presence_demo_v1_before_20261007保存。新隔离构建tmp/led_presence_demo_v1_td_20261007、207输入SHA及6阶段脚本SHA已保存。
- **阈值与条件**：历史有件85/88/78/82，空穴36/37/37/37/36（图8重复图6），未记录完整10秒范围；T58暂选，MEAN≥58有件、<58空穴。旧图料号未核验，不能追溯称旧图已确认3528；现物料型号为用户说明。本轮130mm、EXP2244/GAIN48，青框必须人工对准一个料穴，避开定位孔/背景/邻穴；算法不识别物料或对偏。统计在AWB后、边缘着色前；SW仅切视图，不切物料分类配方。
- **验证及证据**：历史9JPEG与原manifest字节/SHA已只读复核，队内确认阈值来源和边界。正在隔离运行9项ModelSim：classifier、display_state、controls、roi_core、roi_chain、osd、observation、sobel_tail、isp_writer_stop；TD先综合，完成后独立布局布线。使用本机TDCLI D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe及原厂RAM模型，不使用测试强制接零。准备脚本首次用XML解析旧.al的未转义P&R失败；改成仅提取File Path后准备成功，未改工程.al。
- **原镜像与现场状态**：稳定回退release/edge_tail_fix_20261007/camera_to_dsi_display.bit，1789539字节，SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65，未改。用户已确认原版本四视图稳定、固定模式VF不增；当前新原型尚未上板。新镜像将另存led_presence_demo_v1_20261007，未烧录/冷启动。
- **未决事项**：先等仿真和本机物理报告，不借用队员TD6.2.178840报告作本轮结果。旧约束覆盖94.59%、DDR PLL参考频率/无I/O delay及异常覆盖缺口保留；不放宽SDC。本轮临时阈值不构成完整阶段A或三类准确率验收。
- **下一条具体操作**：检查隔离sim/suite_console.log及9项console PASS；检查syn_1/build_console.log、.opt_gate.end.f后启动phy_1/build.tcl；物理完成后核对WNS/TNS、资源/告警及207输入SHA，另冻新release/记录，写29实施说明和上板试用步骤。
- **运行中进程/设备**：助手综合exec session32779、ModelSim session65465运行中，后续查真实PID/结束状态。用户TD27224、bw35732、hwserver38424保留，未关闭/操作；实物/连续视频与真值由用户负责，无JTAG/冷启动操作。
- **提交/推送状态**：本轮RTL/test/docs及此前接收/分析文档未提交、未推送，暂存区原为空；历史未跟踪资料保留。独立审核代理只读；根代理唯一实现写入端。不新建用户线程、不发外部消息。
'''
agents.write_text(data, encoding='utf-8')
print('Updated current authorization and resumable checkpoint')
