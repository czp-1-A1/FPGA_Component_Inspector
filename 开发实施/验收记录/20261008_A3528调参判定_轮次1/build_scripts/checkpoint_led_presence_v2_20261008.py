from pathlib import Path
import json, subprocess, sys
root=Path(__file__).resolve().parent.parent
phase=sys.argv[1] if len(sys.argv)>1 else 'prepared'
sessions=json.loads(sys.argv[2]) if len(sys.argv)>2 else {}
p=root/'AGENTS.md'
s=p.read_text(encoding='utf-8')
s=s[:s.index('## 当前断点')]+'''## 当前断点（2026-10-08，3528第二版解除调参绑定）

- **目标与断点**：用户报告第一版调节曝光/增益后持续未标定；代码确认采集和显示两端硬绑定EXP2244/GAIN48。用户确认第二版方案：允许按键调参，调参时等待采样，新有效完整采样后自动HDMI有件/空穴；临时T58不承诺各种光学条件准确。先3528 LED，另两类后续处理。
- **分支/代码基线**：lj4747-contest-work，HEAD 3be3967f2457622566fb20b7cef3aa5038e7d885；第一版未提交工作区为本轮基线。原207生产输入与第一版仅design_top_wrapper.v变化：两处calibration_ok解除EXP/GAIN比较，移除本次产生的无用常量，保留config/帧有效/新token门控与EDGE尾修复；tb_display_state增加调参后等待/新样本恢复及参数边界测试。此前tb_classifier改动保留。
- **交付与证据**：新隔离构建tmp/led_presence_demo_v2_td_20261008，修改前备份tmp/led_presence_demo_v2_before_20261008；prepare/checkpoint脚本及207输入SHA已准备。第一版release/led_presence_demo_v1_20261007 SHA4c8aa1695e06f3218ba5ae01b67e78e188755a61beea9f1229cdd1ef7296e22e与队员edge_tail_fix SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65保持。新bit尚未交付。
- **验证状态**：仅完成静态修改/输入一致性/diff检查；本轮计划ModelSim真实原厂RAM定向7项（classifier/display_state/controls/observation/stop_recovery/osd/roi_chain）及TD6.2.168116综合+布局布线。尚未获得本轮通过结果；此前v1九项PASS与WNS+1.265/+0.020ns不能当作v2结果。
- **临时判定与限制**：MEAN≥58有件、<58空穴；青ROI[472,552)×[260,340)6400像素，人对准单穴。曝光2244/增益48仍是历史阈值证据条件，第二版不作为使能门槛。曝光/增益改变会改变灰度，正式阈值与精度待机构固定再测。四种SW视图同一LED灰度判定，页脚T80为边缘叠加阈值；结果为最近采样，未绑定DDR当前显示帧。
- **未决事项**：第二版仿真/bit/资源时序待完成，上板分类及视频、连续运行、冷启动未验收。原SDC与覆盖局限保留，无放宽时序。第一版用户故障报告不等于完整实物验收，冻结旧记录不改。
- **下一条具体操作**：检查本轮仿真及综合；通过后完成物理实现，核资源/两角时序/约束匹配和冻结源码、bit SHA、日志；给用户新的bit与现场试用说明。无自动烧录、Flash或冷启动。
- **运行中进程/设备**：阶段 PHASE；本轮会话 SESSIONS。用户TD/bw/hwserver未操作，不用旧PID判断实时状态。
- **提交/推送状态**：本轮和此前工作区改动、资料均未提交/未推送，暂存区空；只由root实现，未调用代理或新线程/自动任务。不要覆盖旧镜像/冻结证据或他人变更。
'''.replace('PHASE',phase).replace('SESSIONS',json.dumps(sessions,ensure_ascii=False))
p.write_text(s,encoding='utf-8')
subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--check'],cwd=root,check=True)
print('checkpoint:',phase,sessions)
