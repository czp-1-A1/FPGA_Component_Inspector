# V3 最终验证通过，进入发布（2026-10-27 23:40）

- r2最终bit SHA9ca7905cf147cfc6d8d770738b03416e2a43601b3b8a1315f46bbf43edfd267e；Slice18538/21216=87.38%、ERAM98/DSP30/PLL5；setup0.000/hold+.018/TNS0，49边界/20实际GrayQ/9邮箱/SW3+4键/20bit命令/V2/无LED均PASS。ERAM少1为固定增益40后的SC500GainTbl常量化，hierarchy已对照；不是识别缓存删减。
- 17项选定实际PASS，最终unit5/closed4/native1/legacy7均已完成，636源与实时工作区完全匹配。native最终12源帧/24精确显示栅格/4ID P2E2，位置未到站，不能称RAW停车闭环；RGB202帧3保持和默认100MHz完整1s另有测试。旧弱RAW280边界保留未修。
- scripts/publish_r22_relay_v3.py --check-only --work E:/2026FPGA/.codex_tmp/r22_relay_v3_build_r2_20261027已READY_TO_PUBLISH；下一步提交实现与指南后实际发布，核SHA与Git索引字节，更新交付回执。本行不代表尚未执行的复制已成功。当前没有运行中TD/ModelSim、没有实板操作，未推送。

# R22 继电器 V3 当前接续入口（2026-10-27）

## 当前规则

- 用户要求工程成功优先，先分析视频原因再修改。人操作实物，助手实现、仿真、构建和证据；没有助手烧录或电机动作。只有一个实现端，不覆盖其他工作区，无子代理。
- 每个交付bit原件保留，额外复制 E:/2026FPGA/BIT_FLASH，源/副本核SHA；不覆盖不同SHA旧文件。只读R2的LATEST_READONLY.bit SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f必须保持。
- 继电器板载5V供电，3.3V HIGH直接触发，无NPN；右J2第1脚=V2，第11脚5V/第12脚GND。最终集成版无LED，其他原引脚和视频链不改。
- 原R22识别/编号、中文、Logo、分类阈值保持。新用户授权把原曝光四键改成计数/电机操作，自动版ae_set键输入固定释放，曝光1092/增益40。
- 无证据不判通过，冻结代码/测试答案/原生RAW与RGB、软件与实板分别记录，不放宽位置窗口/时序/CDC保护来伪造通过。

## 最新请求与已找到原因

- 用户要：每次SW3上下可重开，无K3+K4要求；K3单键清零，K1单键计数，K2暂停/继续同一自动流程保留编号和队列。另可待机K2手动送料，K4停止。用户回复速度可能调整，不能声称固定提前量适合所有速度。
- 新视频1c37c718114109722d73fa266087ba88.mp4，9s/270帧/30fps，SHA5d3609e76a87bc90b7889f9bf637b556d9d58ed222d26c531202d90e924b1bfd。约3.2sS2F0X0AB(171)，3.4s稳定X08F(143)，4.4sS4F8。目标160/窗口152..168，停偏17px使1200ms等待超时；未进S3。不是旧V1F6。图像位置变化含流水/显示延迟，不冒称纯机械制动距离。
- 旧V2新RUN有待处理队列即FA，必须clear；V3仅明确的K1/SW3新RUN重置计数与队列，fault自身仍不丢队列。左侧新RUN空区证明保持，FC表示旧料未移开；K2才是原RUN暂停继续。

## 工作区、修改、冻结

- 本工作区 D:/CodexWork/FPGA_R22_Relay_20261027，分支codex/r22-relay-controls-v3，父e51cb15（已发布V2），原R22a1cceaa。旧E盘R19/诊断保留，不回退/清理/重置。当前修改尚未提交，未推送。
- 6个硬件源：pocket_run_controls.v添加pocket_key_motor_controls，20ms逐键消抖/释放再触发，20bit{mode,17bitcommand}同邮箱；top wrapper改WIDTH20，移除重复SW3许可链，注册V2输出/暂停和手动UI；pocket_relay_stop_v2增加默认关闭新RUN策略、pause（旧.*测试明确连0，无改答案）；ISP接pause；两个OSD转发RELAY_KEYS_V3，显示RL3。位图/分类/框和ADC/SDC未改。
- K2暂停期间继续验证图像和关联，冻结到站等待/停车计时，HOLD恢复重新确认并完整1s。暂停最后1ms到站边界也已覆盖。自动初值TARGET160/ADVANCE32/TOL8，右向左；不是速度自适应，没有反向纠偏。
- 最终冻结构建 r2：E:/2026FPGA/.codex_tmp/r22_relay_v3_build_r2_20261027，636冻结文件/104硬件依赖，TD6.2.168116 seed2。从此目录project跑测试。r1被替代（暂停计时边界/手动状态显示修正前），只保留诊断，不发布。

## 正在运行与下一步

- TD r2 exec session51576。最终软件：unit5项目录.../r22_relay_v3_final_unit_20261027已PASS；closed4项.../r22_relay_v3_final_closed_20261027已PASS，实际双计数器585帧/六SW3重开/暂停保留头，完整处理RGB202帧3保持，V3和V2兼容两个100MHz100000000周期默认完整1秒。以verification.json为准。
- 最终原生RAW测试.../r22_relay_v3_final_native_20261027（exec66503）仍运行，V3生产参数/RAW360/12源帧，24显示帧；这是到站前运输/精确显示验证，不会到停车线。必须等verification.json才算通过。旧native_r1被替代，已终止，不算PASS。
- 7项旧回归在r2/project/sim/modelsim_work运行，exec35710，总日志.../r22_relay_v3_final_legacy_20261027.log；tests=classified_counter,result_recorder_pipeline,local_pipeline,switch_recorder_controls,recovery_protection,simple_recovery_ui,text_plane_prefetch。不复用旧V2数目冒称本版已跑。
- 脚本scripts/audit_r22_relay.py已增--keys-v3：保留49maxdelay/20实际GrayQ/9组邮箱，原SW3同步链+4键实际同步/fanout、20bit邮箱、V2/无LED。必须真实布线双TNS0再发布；不接受Placed或中间负Slack。
- 下一条：检查以上完成回执，运行r2的--keys-v3审计，实际资源/时序/IO后写新的V3publisher（尚未创建）、提交实现，再版本化release+ZIP+BIT_FLASH/SHA。审计若不合格先修，不发布未验bit。V3还未交付/烧录。

## 文档、旧版本及未决

- docs/R22_RELAY_V3_FIELD_GUIDE.md已写新键表、FC/暂停区别、F8证据、5次定速+不同速度分组采集、像素/mm标定；docs/R22_RELAY_V3_FIELD_ANALYSIS.json证据；tmp/autostop_v2_field_20261027有帧/状态序列图，源视频绝对路径见video_metadata.json。
- 旧V2bit R22_RelayAuto_Left_V2_20261027.bit SHA99d1593ffd97d127e2690d4fc9da816e93e8bac280bf7e768222f2f8ff9d03ed保持，不覆盖。V2完整发布releases/r22_relay_left_v2_20261027；旧V1和R22回退bit也保留。
- 原R22弱RAW280孔的既有漏检边界未修；docs/R22_RELAY_LEFT_V2_WEAK_NATIVE_BOUNDARY.json及V2发布原始失败/逐位回放证据保持；V3分类器相关源没有改。不可把这项失败混入PASS数量。
- 仍需人实测：每个选定速度5次，记录稳定X/S/F/是否S3→S1及停车后3秒；另验证六SW3轮次/单键清零/K2保留计数。当前没有不同速度重复性、±1mm或板载5V负载正式验收；无吸嘴/补件握手，空跑先验证。
- Git未跟踪原有calibration*.txt/compact*.hex/region_cadence*.pgm为仿真产物，勿盲目stage全部或删除。releases为稀疏排除路径，新发布要git add --sparse，保留-text原字节后核对Git索引SHA。
