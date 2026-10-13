from pathlib import Path
import sys,json
root=Path(__file__).resolve().parent.parent
p=root/'AGENTS.md';s=p.read_text(encoding='utf-8');s=s[:s.index('## 当前断点')]
sessions=json.loads(sys.argv[1]) if len(sys.argv)>1 else {}
s+='''## 当前断点（2026-10-08，第二版最后位宽修正重编译中）

- **目标与断点**：用户报告调EXP/GAIN后持续未标定，确认允许调参、等待新完整采样再自动HDMI有件/空穴。第二版两处固定2244/48比较已移除；T58仍临时阈值，不承诺不同亮度精度。粗略先3528，其他物料后续。
- **分支/代码基线**：lj4747-contest-work，HEAD3be3967f2457622566fb20b7cef3aa5038e7d885。207生产输入仅design_top_wrapper相对v1变化，206其余输入含EDGE尾修复/IP/ADC/SDC不变。生产修改两处calibration_ok、删除孤立EXP/GAIN常量；R2明确CLASS_CALIBRATED=1'b1避免新增32→1端口告警。tb_display_state新增非默认参数/旧token/配置忙/新完整样本恢复；此前tb_classifier保留。
- **验证与证据**：R1第二版七项ModelSim通过（classifier/display_state/controls/observation/stop_recovery/osd/roi_chain），真实原厂RAM+1024×600 RAW/ISP；从真实修改前后wrapper提取使能表达式的对照复现gain47关闭分类，解除绑定后PASS。TD6.2.168116 R1 setup+0.696ns/hold+0.020ns/TNS0、Slice16521=77.87%、ERAM48/DSP8、STA94.57%，但新增端口位宽告警，检查后决定1位常量修正并重编译。R1保留为候选证据，不作为最终推荐bit。
- **当前构建**：tmp/led_presence_demo_v2_r2_td_20261008，修改前tmp/led_presence_demo_v2_r2_before_20261008。R2只有常量字面量位宽变化，七项模块测试不编译wrapper且所有实际模块/测试源逐字节不变，日志复用和SHA依据见simulation_reuse.json，不声称七项重新运行；新wrapper编译与使能对照已重新运行后PASS。R2工具/资源/时序待最终结果。
- **回退与封存**：R1候选release/led_presence_demo_v2_20261008 SHA40b82b27c229490ac806542552047c86877ccfb7d7e72dd1aaccb70c0f13f382，372主证据封存20261008_A3528调参判定_轮次1。冻结manifest继承解析器重复读详情出现72邮箱条目，report_audit.json按Summary校正31 max-delay/24邮箱，旧证据不改；R2解析器已改Summary范围。第一版v1 SHA4c8aa1695e06f3218ba5ae01b67e78e188755a61beea9f1229cdd1ef7296e22e及稳定EDGE SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65不变。
- **未决事项**：R2新bit生成/告警对比/最终验证与文档待完成。没有新bit板上分类、30分钟连续视频或冷启动验收，既有PLL/I/O/约束覆盖局限保留。EXP/GAIN仍影响灰度，T58准确度需机构固定重测；青框人工对准单穴，最近采样未绑定DDR显示帧。
- **下一条具体操作**：完成R2综合再布局布线，核新端口告警消失、资源和两角时序，封存轮次2源码/镜像/SHA/日志复用说明并给用户新bit。用户自行烧录并调曝光/增益，观察等待后恢复中文有件/空穴与实物；不要求用户手算MEAN。
- **运行中进程/设备**：本轮会话 SESSIONS；用户TD27224/bw35732/hwserver21964未操作，旧PID仅记录时快照。R1综合55667/仿真29940/物理76578结束0；未JTAG/Flash/冷启动；root单端实现，无代理委派。
- **提交/推送状态**：此前及本轮改动、release和证据未提交/未推送，暂存区空；未创建线程、外部消息或自动任务，不覆盖旧镜像或证据。
'''.replace('SESSIONS',json.dumps(sessions,ensure_ascii=False))
p.write_text(s,encoding='utf-8')
print('checkpoint',sessions)
