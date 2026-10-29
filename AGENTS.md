# D2 保留单列停车并加第二条识别（2026-10-29，当前入口，用户纠正D1范围）

- 已交付D2：E:/2026FPGA/BIT_FLASH/R22_SingleStop_SecondRecognition_D2_20261029.bit，SHA1b2d3c1b0e279b53e8245fe8acd61db0ce6c69e37ae1ff3d9419fbab938803ae，与R4构建/发布原件一致。源码57793ece（生产44664cbe），分支codex/r22-single-stop-plus-second-recognition-d2，未推送。最终独立seed4，Slice19713/21216=92.92%、ERAM106/108、DSP30/40、PLL5/6，SWNS+.038/HWNS+.020/双TNS0。18项选定软件检查和原49bound/20Gray/9邮箱/四键SW3/V2/实际报警互锁审计PASS；R4相机303单元两复位×126完整串行I2C PASS。全部TD/ModelSim已结束，无硬件动作。
- 完整发布releases/r22_dual_stop_d2_20261029及相邻ZIP，ZIP SHAb7e8bf84267fb32149d012fb8a9d80417c9d3686eb635717bba9e1b6a2a30a59，1036载荷/636源/104硬件依赖；docs/R22_DUAL_STOP_D2_DELIVERY.json和GIT_AUDIT.json记录逐字节核验，1674 Git blobs含ZIP/源。旧RL7/D1/只读R2均保持。上方仍原384×160，下方480×168；用户只是问尺寸，不自动改几何。
- 下一步人验收RL7+D2实时相机、第一条单/三连完整1秒并继续、五空报警及K3解除、第二条多空但不混计数/队列/报警。K1新RUN/K2暂停继续/K3单清停止/K4停止，SW3上停下新RUN不变；右J2 pin1=V2高运行、板载5V、无LED。第二条只识别，队友只交双列计数，停车整合仍由本工程负责；106/108ERAM意味着后续接入须重新评估资源和共电机调度。无实板光学/任意高速/±1mm达标声明；不再启动额外构建。

- 最新续接：R4 seed4 完整构建通过，生产636源与R3逐SHA相同。Slice19713/21216=92.92%、ERAM106/DSP30/PLL5，SWNS+.038/HWNS+.020/双TNS0；原49bound/20Gray/9邮箱/四键SW3/V2无LED及实际报警互锁审计PASS。R3 seed3完整布线hold-.154/TNS-.203已拒绝，H1~H7 ECO试验未成功且未用于交付；最终bit只来自独立R4，无SDC放松。R4实际303单元相机SYN锥两复位×126笔串行I2C已PASS；18项软件检查均通过，五项R3旧回归用636源逐SHA和日志SHA复用，不冒称R4重跑。当前没有活动PHY任务或硬件动作。目标D2 bit尚待封包。

- 最高优先级r3（20:56起）：r2原17软件检查全过，但布线多轮setup约-.93/-.96/-.90ns，placed关键为candidate_region→high_worst最大值选择→distance比较→high_boxes ERAM使能13级。已核r2唯一父子PID并停止未完成构建，r2ABORT_REASON.json留存；不是routed失败验收。只在现有SCALE拍寄存high_free/high_worst/high_write_index，COMPARE用寄存值，SECOND_LANE=0仍走旧组合，不增加节拍。新d2_pixels_final_r4两项全PASS：原六RGB/48目标逐位等价，新增tb_d2_high_priority用18实际高阈值孔/12保留结果/满bank替换与拒绝/原RL7高阈值缓存逐位等价。新冻结d2_single_stop_second_lane_build_r3_20261029，seed3（前两次seed2），stage-timeout7200，636源/104依赖，全新构建/回归中；不改SYN/SDC约束来通过。publisher改选pixels_final_r4、ui_control_r4、rgb_final_r3、final_compat_r4、keys_compat_r1(编译6源未改)、native_r3、camera_r3、r3工程5旧回归，共18检查；是否完成以实际verification为准。活动构建session89975，RGB50841，RAW17503，UI+兼容67061；本记录之后新session以工具输出为准。r3新18项软件验证除camera_r3收尾均已PASS（RAW17503完成），当前准备提交r3源码；发布前必须核全部636Git blob。

- 最新r2：r1物理布线多轮SWNS停在-1.378ns，placed最差为灰度RAM-bank mux到legacy_ok的11级路径，助手已核唯一D2进程父子PID并停止该未完成构建；不是完整routed审计失败、更没有发布bit。r1冻结源/日志和ABORT_REASON.json保留。只对SECOND_LANE扩展模式加sampled_q一级寄存器及body/Sobel额外等待拍，原两区延迟不变，配对六RGB/48目标仍逐位等价PASS(d2_pixels_r3)。新冻结构建d2_single_stop_second_lane_build_r2_20261029运行中，其他检查正按新输入重跑；不得把r1资源/仿真回执当r2完整通过。用户问上下框为何一长一短，已解释原RL7右计数384×160、下方旧双ROI480×168、左黄窗另计；用户未要求统一尺寸，不改几何。

- 用户明确要求保留原第一条单列计数/编号/停车/1000ms/恢复/五空报警，再加一条识别；队友只研究双列计数，不负责停车。D1关闭整套计数停车属于范围误解，已向用户承认并纠正，不能再以D1纯识别作为当前交付。当前分支codex/r22-single-stop-plus-second-recognition-d2（从30d1a5a5开始），工作目录D:/CodexWork/FPGA_R22_Relay_20261027；无子代理，无实板动作。
- 当前SECOND_LANE=1,DUAL_RECOGNITION_ONLY=0；第一条右448..831×240..399计数、左64..447×240..399补件定位、黄72..232/中心152/触发184/完整1s及F15五空报警全保留；下方新增400..879×432..599独立识别。内部实际3区域，共享flood-fill/原完整mask，追加分段灰度缓存；原608bit只接第一条计数/定位，下方304bit独立，不能混入第一条队列/transport_occupied/报警。元数据1039bit，原887bit低位映射不动，新152bit位[1038:887]。原计数器/分类计数流水线/停车控制器/原ADC/原SDC/相机增益修复源保持。K1新RUN/K2暂停继续/K3单清停止/K4停止/SW3上停下新RUN，V2板载5V无LED。
- 生产冻结E:/2026FPGA/.codex_tmp/d2_single_stop_second_lane_build_r1_20261029，636源/104硬件依赖；当前完整PHY尚在运行，禁止改冻结源，尚不称最终资源/时序通过或新bit已交付。综合/早期物理报告仅参考，最终49bound/20Gray/9邮箱/四键SW3/V2报警互锁必须全部重新审计。scripts/audit_r22_relay.py新增--second-lane-d2，保留原全部检查；r2流水化后的综合资源为ERAM106/DSP30（r1曾为31DSP），按实际新映射核验，不放松时序。
- 已通过17项全新选定软件检查：d2_pixels_r2(六RGB/48实际P/E，与归档原RL7同输入的计数/定位608bits、occupied、trace一致)；ui_control_r2两项(完整两OSD/旧窗口状态报警+新增下框、21实际motor代码互锁)；rgb_r1(206RGB/原6IDs/3次完整10000000cycles=测试10MHz的1s/继续，第二条持续多空穴不混计数报警)；rgb_alarm_r1(75RGB/上方P+5E第五报警、下方独立识别)；first_compat_r2旧V7单穴/五空/OSD三项；keys_compat_r1旧键27检查+停车65断言两项；native_r1(七RAW/14显示/13088282精确像素，1039bit同槽/4views/WB取消，实例化计数停车但permit=0，不当RAW停车成功)；camera_r1(300单元实际相机锥2复位x126写入)；冻结工程regions/classified_counter/result_recorder_pipeline/empty_trace_abort/text_plane_prefetch五项。
- tests/dual_stop_d2；说明docs/R22_DUAL_STOP_D2_FIELD_GUIDE.md/INTERFACE.md明确三个区域和队友只交计数。d2_first_compat_r1遗漏include support、d2_pixels_r1把区外测试物放入左定位区属于夹具错误，独立日志保留，不算PASS；未因此更改生产判据。6份相对D1生产源修改（7份相对原RL7），frame/edge文件换行由LF变CRLF引起大diff，语义审阅使用--ignore-space-at-eol；冻结后不为换行重写。
- 目标独立名R22_SingleStop_SecondRecognition_D2_20261029.bit；发布脚本scripts/publish_dual_stop_d2.py需严格核17checks/原49约束/报警路径后才封包。是否交付/Git字节审计以docs/R22_DUAL_STOP_D2_DELIVERY.json/GIT_AUDIT.json实际回执为准，当前尚未封包。旧RL7 SHA3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750、D1 SHAe9938418f0cc69790a583b401897657f4b44dff55e57cb361fcbeada1bad24cd、只读R2 SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f保持。所有新bit复制BIT_FLASH并核SHA。若PHY/时序失败，修具体资源/路径问题，不能再次关停车减功能来通过。

# D1 双区识别（2026-10-29，旧交付，已被用户纠正范围）

- 用户现在要求恢复原上下双ROI识别；双列计数等待队友代码，本轮不实现。当前分支codex/r22-dual-recognition-d1，起点a716eac，工作目录D:/CodexWork/FPGA_R22_Relay_20261027。无子代理，无烧录/接线/电机/继电器动作。
- 顶层DUAL_RECOGNITION_ONLY=1；上ROI[400,880)×[240,400)，下ROI[400,880)×[432,600)，1280×720处理像素；恢复原区域/缓存，R22现有检测开关及相机增益修复保留。每区内部4候选/显示2结果。当前不实例化计数/编号/停车/五连报警；旧RL7逻辑及bit保留，不能称本版自动补件仍启用。K1手动运行、K2暂停/运行、K3/K4停止；SW3上停、下沿运行；上电停，V2/板载5V/无LED，原ADC不改。
- 5份既有生产RTL修改+新增独立识别SDC，631份原源与RL7逐SHA不变。637冻结源/105硬件依赖构建E:/2026FPGA/.codex_tmp/dual_recognition_d1_build_r1_20261029已完成；Slice16299/21216=76.82%、ERAM100/108、DSP26/40、PLL5/6；SWNS+.107/HWNS+.020ns、双TNS0。识别SDC仅去掉未实例化count-live邮箱3约束，原SDC不改；严格46活动bound无忽略/20实际Gray/6手动邮箱组/四键SW3/V2无LED审计通过。
- 10项全新选定仿真通过：dual_d1_initial_r2两项（28按键断言+六RGB/32物理P/E）、osd_r3一项（两完整栅格/792字符）、native_r3一项（七RAW10源帧/14显示完整栅格/13088282逐像素/4views/WB取消）、camera_r1一项（实际302单元相机锥/2复位x126写入）、compat_r1旧键一项、osd_compat_r1旧OSD一项、冻结工程regions/text_plane_prefetch/empty_trace_abort三项。均有输入SHA回执，不当作实板/任意速度/光学召回验收。
- native早期首帧无效假设失败；同fixture对原RL7和D1均得到完整首帧，最终用例对全部7帧包括首帧执行相同完整字数/提交/像素验证。诊断失败不算PASS、不修改生产源绕过。测试tests/dual_recognition_d1；交接docs/R22_DUAL_RECOGNITION_D1_INTERFACE.md解释608bit候选及帧证明，端口不是计数事件，队友尚未接入。
- 目标独立发布R22_DualROI_Recognition_D1_20261029.bit，必须复制BIT_FLASH并核SHA。完整原件releases/r22_dual_recognition_d1_20261029及ZIP；实际是否交付/Git归档以docs/R22_DUAL_RECOGNITION_D1_DELIVERY.json和GIT_AUDIT.json为准。生产bit SHAe9938418f0cc69790a583b401897657f4b44dff55e57cb361fcbeada1bad24cd。已交付BIT_FLASH并与构建原件/发布原件核SHA一致；源码67538ef，未推送。990载荷ZIP SHAed8d10ea34da67442a51f2450b60b269218877d3dea202464747197c7b2c7997；归档提交766e1911已过HEAD逐字节审计：990载荷、清单、ZIP及637生产源共1629个Git blob核SHA通过；回执docs/R22_DUAL_RECOGNITION_D1_GIT_AUDIT.json。全部构建/仿真已结束，不另开构建。
- 旧RL7 SHA3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750及只读R2 LATEST_READONLY.bit SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f不覆盖。下一步用户检查D1标识/实时画面、两条料带分别有件/空穴/一条空置以及K1/K2；双列计数与后续自动定位另行集成。

# RL7 已交付（2026-10-28，旧自动停车入口保留）

- 用户要求补件区稍左移、连续5个空穴报警停机。已交付E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V7_ShiftAlarm_20261028.bit，SHA3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750，构建/发布原件/烧录副本一致。源码e037c9b（生产功能1d43470），分支codex/r22-left-shift-five-empty-v7，未推送。旧RL6/RL5/以太网R2保持。
- 窗口72..232、目标152、触发184（提前32），整体左移8px/宽160。FIVE_EMPTY_V7顶层1；按同RUN合法主计数序号累计EMPTY，PRESENT打断。第5个当拍锁存FF报警/送料关闭并禁止同拍弹队，保留待处理队列；顶部红字ALARM 5 EMPTY - MOTOR STOP - K3 CLEAR。K2/手动不能绕过；K3清零停止或明确K1/SW3新RUN才复位。保持单排、J2 pin1/V2高有效/板载5V、无LED和蜂鸣器新引脚。正常1~4空穴保持完整1秒，RL6一次500ms停机找回保留。
- E:/2026FPGA/.codex_tmp/r22_shift_alarm_v7_build_r1_20261028完成636源/104硬件依赖构建；5生产源修改、631源与RL6逐SHA相同。Slice18972/21216=89.42%、ERAM98/108、DSP30/40、PLL5/6；SWNS+.001ns/HWNS+.020ns/双TNS0，严格49最大延迟无忽略/20实际Gray/9邮箱/四键+SW3/V2无LED审计PASS。报警Q经实际alarm_stop网→电机注册LUT→V2输出同物理捕获单元已核；TD把该单元命名为station/counter/event_valid_reg_syn_3，不能只凭名字误认信号，证据physical_verification.json/alarm_interlock_packed_cell_proof。
- 全31项新选定检查PASS：final_units_r2的13、alarm_control_r2的1（21断言，实际顶层motor代码体逐字核对）、final_rgb_r3的2（206帧3保持+真实100MHz100000000周期1秒）、rgb_alarm_r1的1（75完整RGB帧P+5E、第5确认停机）、compat_r1的5、核心回归7、native_r1的1（12RAW/24精确显示，V7启用，未到停车线）、camera_gate_r1的1（实际305单元相机锥/2复位x126写入，非实物读回）。最终输入SHA逐项与冻结源/夹具一致；早期r1/r2夹具错误日志保留但不选PASS。
- 原件releases/r22_relay_shift_alarm_v7_20261028及相邻ZIP，1110载荷，ZIP SHA171f2e1004a973ba308d202fc0079b925c5840f37275fc69a41890802c22473c。docs/R22_SHIFT_ALARM_V7_DELIVERY.json回执；最终Git字节审计docs/R22_SHIFT_ALARM_V7_GIT_AUDIT.json以实际结果为准。BIT_FLASH同前缀_说明.md/_RELEASE.json包含操作/来源/资源。旧失败边界单独封存，不算新PASS。两段RL6现场视频及依据在docs/R22_V7_FIELD_ANALYSIS.md/.json，不能作为RL7实板验收。
- 所有TD/ModelSim工作已结束，无烧录/接线/电机动作，无子代理，不启动额外构建或自动跟进。下一步用户保持原接线，烧RL7确认T098/A020，先原普通/慢速三连，再4/5/6连和4空+有件+4空；4连继续、第5确认应报警，录上下两行后再K3清。新停点/五连报警/实物重复性待验收，无吸嘴握手/±1mm达标声明。主计数既有高速/弱RAW280漏检边界未修；不允许改编号/类别/上游gap保护假装通过。

# RL7 实施记录（以下为交付前过程，以本节以上结果为准）

- 用户新视频105ebf…为普通速度、930403…慢速，均RL6，最终S1F0Q00。普通速度2/3/4/11/16号保持X137/185/235/139/131，第三穴距右界240仅5px。用户要求补件区略左移、连续5空穴直接报警停机，已授权实施，无需再问确认。证据docs/R22_V7_FIELD_ANALYSIS.md/.json、docs/evidence/r22_rl6_shift_20261028（旧RL6实测，不能当RL7硬件通过）。
- 工作目录D:/CodexWork/FPGA_R22_Relay_20261027，分支codex/r22-left-shift-five-empty-v7，从1a82896起。生产只改5份：top/isp/relay_controller/dual_OSD/compact_OSD，主计数器/检测分类/ADC/SDC/相机源与RL6相同。FIVE_EMPTY_V7顶层默认1，叶模块默认0兼容。窗口72..232、目标152、提前32、触发184，整体左移8px/宽160，左ROI仍64..447留8px边。单排不恢复双ROI，原J2 pin1/V2高有效、板载5V、无LED。
- 五连报警按同RUN连续主计数编号的合法EMPTY事件累计；PRESENT打断，不按队列深度/图像帧数。第五个当拍锁存alarm_stop并fail15（上方S4 FF），保留队列含第五个、禁止同拍HOLD弹队。顶部红字ALARM 5 EMPTY - MOTOR STOP - K3 CLEAR。顶层实际motor_output再受!relay_alarm约束，K4后K2手动也不能绕过；K3清零停止或明确K1/SW3新RUN才重置报警和连续段。正常1~4穴仍逐个完整1秒，RL6一次500ms停机找回保留。
- 生产已冻结E:/2026FPGA/.codex_tmp/r22_shift_alarm_v7_build_r1_20261028（636源/104硬件依赖），SYN完成、PHY进行中，禁止修改冻结RTL。原生RAW V7/tol80/target152回放进行中，未到停车线，不混称RAW停车通过。相机实际305单元综合网表2复位x126串行写入已PASS。尚无新bit交付，旧RL6/RL5/只读R2保持。
- 最终拟选31项：final_units_r2的13项（31控制断言、移框/红字/两栅格、1~4连继续、5/8连在第5触发、回归/负例/变速）；alarm_control_r1的1项19断言（4+P+4/队列8不报，第5报，实际顶层motor寄存器代码体提取并逐字检查，K2/手动禁绕过、K3/新RUN、同拍HOLD冲突、错ID/RUN、暂停中第5）；RGB三连+实际100MHz1秒2项final_rgb_r3重跑中；RGB五连1项75完整帧已PASS；兼容5项+核心7项PASS；native1进行中；camera_gate1 PASS。r1真实秒夹具.*漏声明alarm_stop、r2夹具仍旧192触发，均为测试加载/激励错误；已改为输出声明及184/152，失败日志保留但不得当PASS。生产源未因此重构。
- scripts/publish_r22_shift_alarm_v7.py与audit_r22_relay.py --keys-v3 --adjacent-v6 --five-empty-v7准备中，严格49最大延迟/20Gray/9邮箱/四键+SW3/V2无LED外，新增alarm_latched到motor_output实际FF布线路径审计。5变动/631不变、全部636Git blob、31项冻结输入SHA、CRC/ZIP/发布payload及BIT_FLASH副本SHA必须核。拟名R22_RelayAuto_Left_V7_ShiftAlarm_20261028.bit；尚未发布。
- 继承弱RAW280/高速40pitch24step主计数失败/上游gap保护；高速失败是旧RL5/V6对照，不是本版新测或PASS，主计数/分类源未动。无吸嘴/实际补件/±1mm硬件验收。本轮仅文件/仿真/构建，没有烧录/接线/继电器/电机操作；无子代理，保留原未跟踪产物。

# RL6 交付记录（2026-10-28，以下为前版）

- 已生成独立交付E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V6_Adjacent_20261028.bit，SHA7a6c18f56d90f0b2743d544a55bb4167882f4dbb930095b847f4372355ff20bd，与实际构建/发布原件一致；源码ec53ab4（生产功能cc0d804），未推送。原件releases/r22_relay_adjacent_v6_20261028及相邻ZIP，ZIP SHAa79eeadf1bd20bdec9e09579af4e1ec0dc86a7c463efcbf591a9263102f60001，1086载荷/636源/104硬件依赖。docs/R22_ADJACENT_V6_DELIVERY.json为回执；BIT_FLASH同前缀_说明.md/_RELEASE.json含操作和资源来源。旧RL5/以太网R2保持。最终Git字节审计记录在docs/R22_ADJACENT_V6_GIT_AUDIT.json，是否通过以该回执为准。
- 当前分支codex/r22-adjacent-reacquire-v6，基线1972dea；工作目录D:/CodexWork/FPGA_R22_Relay_20261027。实施已获授权，不停在方案。新增8份生产源修改：停机交接下一队首、待处理EMPTY身份保留/停车提示限制、一次500ms电机关断重定位、同帧来源与候选/关联冻结诊断、RL6底部诊断和163bit显示邮箱。核心主计数、分类判据、相机增益修复、ADC/SDC原件保持。仍单排右数左补、窗口80..240/触发192/完整1000ms；无LED、V2高有效/板载5V。
- 生产冻结于E:/2026FPGA/.codex_tmp/r22_adjacent_v6_build_r1_20261028，636源/104硬件依赖；完整构建及严格审计完成，bit SHA7a6c18f56d90f0b2743d544a55bb4167882f4dbb930095b847f4372355ff20bd。Slice18672/21216=88.01%、ERAM98、DSP30、PLL5，SWNS+.001/HWNS+.020/双TNS0，49bound无忽略/20Gray/9邮箱/四键+SW3/V2无LED通过。不得改冻结源或已交付bit。目标独立名R22_RelayAuto_Left_V6_Adjacent_20261028.bit，不提前声称实板成功。
- 29项全新选定检查完成：12项final_units_r2（1/2/3/5/8连空穴、变速3/4/6/快10px帧、跨S2/S7连续7帧丢失后返回、持续缺失/错类别负例、23控制检查、2栅格106诊断字符），final_rgb2（RGB205帧3保持+163bit邮箱76次完整交付），final_second1（实际100MHz/100000000周期1秒），final_compat5，native1（V6/tol80、12RAW/24精确显示，未到停车线，不混称RAW停车通过），camera_gate1（实际307单元相机锥/2复位x126笔串行写入、非光学读回），7核心回归。全部输入SHA与冻结源一致；原r1修正前夹具不选最终证据。
- 额外高速压力40px穴距/突然24px帧出现主计数ID5类别顺序错误，第一次停车前，RL5与V6同输入同错误/同frame14/lead580；不是新停车逻辑引入，但不能声称任意高速。E:/2026FPGA/.codex_tmp/r22_v6_highspeed_boundary_20261028保存两版输入与失败日志，发布单独归档，绝不算通过；不放松编号/类别断言掩盖错误。
- scripts/publish_r22_adjacent_v6.py已核全部29项新选定检查/实际布线审计/636源码Git原始字节才发布，包含源码、报告、完整相机综合网表和旧拒绝负例/当前高速失败对照。docs/R22_ADJACENT_V6_FIELD_GUIDE.md包含S6/S7动作、底部RD解码、复测方法。原上游gap保护仍在，不允许用预测位置/错编号/错类别或跳过队首假装成功。
- 下一步用户保持原接线，烧RL6，先固定中低速空跑三连穴，拍完整上方RL6及底部RD；Q归零并继续送料才算连续成功。相邻穴在宽框内可连续停数秒但N逐个切换/Q递减；出现S7继续拍2秒，S4后拍3秒且不要先K3清诊断。无需用户自己解码。实物三连停车、不同速度重复性、光学画面及真实补件未验收，不声称±1mm。全部TD/ModelSim任务已结束，无额外构建/自动跟进。
- 只有本地文件/仿真/构建动作，没有烧录、接线、电机或继电器操作；无子代理。完成时须复制bit到E:/2026FPGA/BIT_FLASH并核SHA，写资源/来源，保持LATEST_READONLY.bit SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f。用户实测三连复现仍待进行。

# 最新三连空穴诊断（2026-10-28，以下为实施前分析记录）

- 新视频按上传序号：2a08…双连、a045…单穴、c6d4…三连，均RL5。单/双连最终S1F0Q00；三连2号约6.4sS3→7.4s队首3，3号7.5sS2/7.6sS3→8.6s队首4；4号8.8sS2X190、8.9s最后X145，9.1sS4F6/Q2/L6，余4和11号。用户说第二次不动，按编号实际前2/3均完成保持，卡在4号。用户已确认三连全程未操作/调速/碰料/遮挡/补件。
- 直接原因仍是150ms同ID位置未更新并锁定。145是最后测量且在80..240内；不能当故障时当前位置。队列容量32、本段只用4，右侧编号/入队已完成；不要把问题归为容量或继电器必须更换。
- 原始检测是否消失、四候选裁剪/±12预测保留失效、实际关联失败、上游gap阻止发布目前无法凭OSD唯一确定。先加同帧冻结诊断再针对性修。提议保留所有待处理身份、停车时限制旧速度预测漂移、增加下一队首交接（已在宽框内不盲目重启电机）、电机关闭时有界同ID重定位并重新完整保持；不得绕过上轮已失败的排序保护或用旧坐标完成。
- 本轮只有视频抽帧/源码读取/诊断文档；生产RTL未变，未启动构建、未生成新bit，旧RL5保留。证据E:/2026FPGA/.codex_tmp/r22_rl5_adjacent_field_20261028；持久选帧docs/evidence/r22_rl5_adjacent_20261028；完整分析docs/R22_RL5_ADJACENT_FIELD_ANALYSIS.md及JSON。下一步按用户后续指示实施诊断/相邻目标交接，当前不自动开始更大改造。

# 当前 RL5 跟踪/显示整理（2026-10-28，优先读取）

- 当前分支 codex/r22-brake-track-clean-ui，从 bcf29a4(RL4封存)开始。用户新视频8696…最后S4/F6，N004/Q02，最后有效X185在80..240内；PTS约5.333s S2→5.500s S4，未进入S3。用户确认未调速/碰料/补件；X185/V1不是故障时的新测量。
- 已复现并修复一个明确缺陷：STOP_POSITION左站不能按普通已计数轨迹规则提前回收当前query。四实际目标、同一漏检帧，旧RL4报F6；新源漏检1/2帧后同ID返回并完成三次完整1秒。持续缺失/不同类别仍F6，不增大150ms、不假造位置、不改控制器。
- 可见UI简化为右计数框+左黄80..240验收框+实际结果小框/分类；内部左ROI64..447/线256/目标160/触发192仍计算，只隐藏多余边线和特征十字。RELAY_CLEAN_UI=1生产默认，参数0保留旧显示，版本RL5。相机修复、按键、ADC/SDC、V2管脚无修改，仍单排，不恢复双排。
- 新用例tests/brake_track。r22_brake_faults_r2四例、clean_osd_r2、wide_r1四例、compat_r1五例和冻结工程七旧核心目前已PASS；原生RAW r22_brake_native_r1与完整TD r22_brake_clean_build_r1均已完成并PASS。门级相机启动r22_brake_camera_gate_r1已PASS 2复位x126笔。636源/104依赖已冻结，实际Slice18475/21216=87.08%、ERAM98/108、DSP30/40、PLL5/6；SWNS0.000/HWNS+.020ns、双TNS0。49最大延迟无忽略/20Gray/9邮箱/20bit命令/4键+SW3/V2无LED原审计PASS。bit SHA b88610ad095d5ee6b30444c542faa24bd65e21ed0c1f8ffc4a41484aa87c95ba，已封存并复制BIT_FLASH。不能称已过实板。
- 新现场证据/负对照/未解决压力失败在E:/2026FPGA/.codex_tmp/r22_rl4_f6_field_20261028，docs/R22_TRACKCLEAN_FIELD_ANALYSIS.json及FIELD_GUIDE.md记录。六目标候选压力场景还有上游未编号目标被裁剪产生gap_open从而抑制当前位置的边界；旧失败和修复后的该失败均保留，不算PASS，不宣称视频根因已完全复现或全部F6解决。旧弱RAW280边界不变。
- 已交付E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V5_TrackClean_20261028.bit，SHA b88610ad095d5ee6b30444c542faa24bd65e21ed0c1f8ffc4a41484aa87c95ba，与实际r1构建/发布原件相同；源码4fd5e86（功能07d95bd），未推送。scripts/publish_r22_trackclean.py已核23项全新选定检查+49最大延迟等原审计，完整release为releases/r22_relay_trackclean_v5_20261028及相邻ZIP，ZIP SHA4cef640f6dbd0745cc56e00924ad4dffcee29c06d529104f752c72559b75e194，1070载荷；全部1072个发布/ZIP索引路径及636源提交blob逐SHA核对通过，见docs/R22_TRACKCLEAN_GIT_AUDIT.json；不覆盖旧RL4/CamFix/V3/V2或只读R2。后续同速度同料带复测两穴，若仍F6采集左候选/排序，不能通过放松关联假装完成。
- 独立实验曾尝试跨上游gap发布实际队首位置并延长远端保留；虽六目标正例通过，删除上游目标的负例出现后续目标接错编号，因此已拒绝且未合入生产/bit，失败输入位于field_evidence/negative_and_boundary/rejected_station_gap_prototype。生产仍保留原gap保护。
- 本轮只有文件/仿真/构建操作，无烧录、继电器/电机或接线操作；无子代理。全部TD/ModelSim任务均已结束；不启动额外构建。

# R22 左补件继电器 V3 接续入口（2026-10-27，已交付）

## 当前宽窗口联调（2026-10-28，最新用户要求优先）

- 已交付RL4：E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V4_Wide_20261028.bit，SHA b5cc8c89b11da9895eb5406075ebcf76cd35f64c2f422a8cfe9e687e0add1e7b，与实际r1构建/发布原件相同；源码13724c3，分支codex/r22-wide-stop-window，未推送。
- r1构建/18项全新选定检查/真实布线审计均已结束并PASS：宽窗口65断言/7终点同RUN连续保持、真实双计数器变速582帧3保持+暂停继续+6SW3+单K3、宽框2完整栅格/颜色/94字符/3拍、生产100MHz整100000000周期1秒、5兼容检查、7旧核心回归、原生12 RAW/24精确显示、相机实际综合网表2复位x126笔串行写入。原生回放是默认tol8兼容性且未到停车线；宽tol80由专门控制/传送/显示测试验证，不混称原生RAW停车通过。
- 636冻结源/104硬件依赖，633源与CamFix相同；资源Slice18156/21216=85.58%、ERAM98/108、DSP30/40、PLL5/6；SWNS+.001ns/HWNS+.020ns/双TNS0。49最大延迟无忽略、20实际Gray、9邮箱、20bit命令、SW3/四键同步fanout、V2注册输出/无LED审计PASS。
- 完整原件releases/r22_relay_wide_v4_20261028及相邻ZIP；ZIP SHA2b99c5bdb238de6cffbbf2c0a29d3b10b3450c997c977c15ab484d54f78363df；987载荷、源码、实测截图/逐时状态图、所有新测试日志、布线报告、重构脚本已封存，BIT_FLASH同前缀_说明.md/_RELEASE.json。旧CamFix/V3/V2/以太网R2保持。
- 下一步用户以不同速度复测RL4，录像拍到至少两个空穴完整S1→S2→S3→S1，或出现F码后再拍3秒；先看宽框内停点能否连续处理，不以±1mm验收。若出现其他F码按现场原因处理，不能自动跳过错编号/丢目标装作成功。所有TD/ModelSim已结束；助手无实板/电机/烧录操作。

- 用户提供六段混合快慢速度视频，明确要求先尽量放宽补件范围，让多数情况停车1秒后继续下一穴；这项授权取代下文旧的“不放宽窗口”阶段限制。仍保持单排ROI，暂不恢复双ROI；宽窗口不宣称±1毫米精准补件已验收。
- 已逐帧抽取六段视频状态，末尾均S4/F8，按上传顺序停点X=131/137/145/169/139/121，均落在原152..168之外。第4段先在X157完成S3→S1，再在下一空穴X169报F8。不是因为一次完成后没有重新按键。
- 当前分支codex/r22-wide-stop-window，从0090662(含相机修复)开始。生产改动仅design_top_wrapper.v的默认RELAY_TOL_PX=80、传到显示的同名参数、classified_dual_page_osd.v和compact_inspector_osd.v；控制器/编号/分类/相机/引脚/SDC未改。
- 新验收窗口80..240（目标160±80），对比原±8宽10倍；保留触发192、提前32、稳定确认及完整1000ms保持，再弹出同一队首并继续。窗口边界距左检测边64/二次编号线256各16px，不能再扩大到检测边缘而丢失可靠定位。显示RL4及琥珀色虚线窗口；不是新增检测ROI。
- E:/2026FPGA/.codex_tmp/r22_wide_stop_field_20261028保存六视频SHA/元数据/每0.333秒状态图；范围覆盖已观测7个停点，不能称新版实板7/7已通过。先只处理已确认的F8窗口问题，保留错编号、图像中断、定位丢失等故障，不自动丢弃异常装作补件完成。
- 完整构建E:/2026FPGA/.codex_tmp/r22_wide_stop_build_r1_20261028已完成，冻结636源/104硬件依赖，TD/ModelSim软件操作；无烧录/电机/接线动作，无子代理。旧CamFix/V3/V2/以太网R2不覆盖。

## 当前黑图回归排查（2026-10-28，优先读取）

- 已交付独立修正版E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V3_CamFix_20261028.bit，SHA2c06e667cbf89039a63e9d788f5d1d07f72b195e23532ca1ae1d03336019677f；与实际r2构建/发布原件相同。源码提交701ea18，分支codex/r22-v3-camera-gain-fix，尚未推送。
- 完整r2构建已结束；严格49最大延迟/20实际Gray/9邮箱/20bit命令/SW3+四键同步fanout/V2输出/无LED审计全部PASS。Slice18171/21216=85.65%，ERAM98/108、DSP30/40、PLL5/6；SWNS+.002ns、HWNS+.020ns、TNS0。原V3/V2/只读R2保留。
- 发布原件releases/r22_relay_v3_camfix_20261028及相邻ZIP；ZIP SHA812de97fee80b7f65991cc391f859391cab2a73127c298d4bb63a3903b2be133。636源/104硬件依赖、986载荷、3项新相机检查+17项逐编译输入SHA复用检查均归档。只改一份生产源，其余635源不变；Slice打包数量不能独立证明功能删减，综合总单元旧49858→新49886（类型重映射/物理打包不同），不冒称整个综合网表除6单元外逐项相同。
- 下一步由用户先保持送料停止、不按K1确认实时画面更新，再测试运行键和停车；实板光学图像仍待确认。所有TD/ModelSim已结束，无硬件操作，不启动双ROI改造。

- 用户已同接线来回烧录确认：V2实时图像正常、V3仅OSD/ROI正常而相机底图黑；不能视为正常待机，CFG/FPS不是有效图像验收证据。
- 当前分支codex/r22-v3-camera-gain-fix，从119c276开始。仅生产源SC500GainTbl.v改为三个范围的同步译码，保持74有效表项/其余0/一拍延迟/原复位脚行为；tests/camera_gain_fix及scripts/check_camera_gain_fix.py新增真实串行总线检查。仍须实板确认图像。
- 第一次仅改case默认分支未解决综合网表错误，r1构建已停止并保留。完整构建E:/2026FPGA/.codex_tmp/r22_v3_camfix_build_r2_20261028已完成，冻结636源/104硬件依赖，635源逐SHA与V3一致。旧V3/V2/只读R2均不覆盖。
- 诊断E:/2026FPGA/.codex_tmp/v3_camera_black_20261028：旧V3实际综合网表相机锥回放曝光正确，但gain0338成为0000；已完成V2阳性对照(0338)及V3全部消费网驱动闭合检查，外部仅时钟/复位/SDA。修正r2实际综合网表305单元，两次复位的全部126笔串行写入均匹配正常V2，见r22_camfix_gate_r3_20261028；同一检查对旧V3在第125笔明确失败(0800而非0803)，见r22_camfix_old_v3_negative_r2_20261028。仅模拟ACK从机，不是传感器实物读回。
- 新RTL检查r22_camfix_rtl_20261028通过全部128地址x两种复位脚电平/相反地址顺序与原始表的等价性，以及两次复位x126完整I2C写入。独立小模块原case/default均正确0338，不能泛称所有ROM常量化都错。新检查初次gate运行因厂商Verilog模型在SV模式下缺timescale而加载失败；已分开编译并明确timescale，失败原件保留，未改期望结果。
- 既有RAW/17项测试未覆盖真实相机初始化串行总线，不能据其PASS判定此次黑图已解决；需补充启动I2C/实际综合网表验证和完整时序资源审计。本轮无烧录、电机或接线操作；保持单排布局/按键/引脚/停车参数。

## 最新用户决定（2026-10-28，优先于此前双ROI恢复建议）

- 用户明确：先由其把当前单排ROI跑稳定，再进行双ROI恢复；当前不启动双ROI改造或扩大检测布局。
- 当前阶段保持V3单排料道的右计数、左补件定位布局，集中验证识别/编号、按键暂停继续、精准停车、完整1秒保持和恢复；仍需实板数据，不提前宣称稳定或±1毫米已达标。
- 用户确认单排稳定后，再恢复原上下两块检测ROI并单独安排补件定位，重新评估缓存、资源和时序；不把当前布局误称为原双区功能全部保留。
- 本次仅记录阶段顺序，未修改RTL、按键、引脚、参数或任何已交付bit，也没有新仿真、构建、烧录或电机操作。下一步等待用户提供V3实测结果，再依据状态行、稳定X及速度分组分析。

## 约定

- 用户要求工程成功优先、先分析再修；人做实物操作/真值，助手做源码/仿真/构建/分析。本轮无实板/JTAG/Flash/电机动作，无子代理，不覆盖其他人的改动。
- 每个交付bit保留发布原件，额外复制E:/2026FPGA/BIT_FLASH并核SHA。只读R2 LATEST_READONLY.bit SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f保持，不能因日期新而替换。旧R22/V1/V2都保留。
- 继电器板载5V、3.3V HIGH直触发，无NPN；右J2第1脚=V2，第11脚5V/第12脚GND。原ADC/SDC未改，集成版无LED。
- 原R22分类/编号/中文/Logo保持。用户最新明确把四键用于运行控制，所以自动版原曝光/增益/WB按键让位；默认曝光1092、增益40。无证据不把软件/像素/原生RAW/实板混作通过。

## 分支与交付

- 工作区D:/CodexWork/FPGA_R22_Relay_20261027，分支codex/r22-relay-controls-v3，源码提交a79ac7c，父V2 e51cb15，原R22a1cceaa。最后发布归档提交以git log为准；未推送。旧E盘R19/独立诊断不改。
- 正式bit E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V3_20261027.bit，SHA9ca7905cf147cfc6d8d770738b03416e2a43601b3b8a1315f46bbf43edfd267e，与release/实际r2构建相同。
- 完整原件releases/r22_relay_left_v3_20261027及相邻ZIP，ZIP SHAf154216670ae80643ed2f43467aac54fb875b89aa54e39b7106efdab4ff12329；636完整冻结源、928载荷逐SHA/ZIP CRC已核。BIT_FLASH同前缀_说明.md/_RELEASE.json/_BOUNDARY.json。docs/R22_RELAY_V3_DELIVERY.json/FINAL_AUDIT.json保存回执。全部928发布载荷、ZIP及636源码的Git索引字节已逐SHA核对，见docs/R22_RELAY_V3_GIT_AUDIT.json。
- TD r2 E:/2026FPGA/.codex_tmp/r22_relay_v3_build_r2_20261027，636源/104硬件依赖，TD6.2.168116 seed2；Slice18538/21216=87.38%，ERAM98/108、DSP30/40、PLL5/6；setup0.000/hold+.018/TNS0。49最大延迟/20实际Gray Q/9组邮箱/SW3+4键同步fanout/20bit命令/V2输出/无LED均实际审计PASS。ERAM比V2少1来自固定增益40的SC500GainTbl常量化，层级已对比，不是删识别缓存。

## 原因及当前行为

- 新现场视频1c37c718…共9s/270帧/30fps，SHA5d3609e76a87bc90b7889f9bf637b556d9d58ed222d26c531202d90e924b1bfd。3.2sS2F0X171、3.4s稳定X143、4.4sS4F8；目标160/窗口152..168，停偏17px，1200ms合格等待超时，未进S3。不同于V1F6丢位置。文档docs/R22_RELAY_V3_FIELD_ANALYSIS.json；视频状态序列图在release/field_evidence。
- K1单击新RUN/计数+自动送料，重新编号并重置旧队列；K3单击清零并停止；K4停止保留结果；SW3上停下新RUN，每轮无需K3+K4。原V2队列非空拒绝新RUN的FA限制仅在明确新RUN操作时解除，故障本身不丢旧队列。
- K2按用户选择暂停/继续当前自动流程，保留编号和队列；待机可手动电机启停。暂停仍采样/检查关联，冻结到站和停车等待，HOLD恢复后重新位置确认并完整1秒。按住键仅一次，释放才可重触发，上电按住不启动。
- 20bit{mode,17bitcommand}同一稳定邮箱避免RUN/许可不同步；注册V2输出；OSD版本RL3。右向左，主计数640/左站256/目标160/提前32/触发192/窗口±8px。首次K1须首穴在右约X800、左侧无未编号料，否则FC；继续原RUN用K2。
- 用户说速度可能调整。固定提前32仅根据此次视频的标定初值，不是速度自适应；组内固定速度，每个速度分组测5次。没有反向纠偏、吸嘴或补件完成握手；填料/遮挡会改变原E关联，先空跑停车/确认/保持/恢复。

## 最终验证及未决

- 17项选定实际PASS：final_unit5、final_closed4、final_native1、legacy7。路径均E:/2026FPGA/.codex_tmp/r22_relay_v3_final_*_20261027。27键检查、65控制检查、实际双计数器585帧/六SW3重开/保留队首暂停、处理RGB202帧3保持、V3和V2兼容两个100MHz100000000周期完整1秒。原生12RAW10帧/24精确显示栅格/4ID P2E2/到站前队列等待；RAW没到停车线，不能称RAW停车闭环。旧7回归实际从r2冻结工程运行，不拿V2旧数目充本版。
- 原R22弱RAW280孔漏检边界未修，报告随新发布；原始失败/逐位回放在V2完整发布保存。V3分类及主编号相关源逐SHA对比V2相同，不把失败算PASS。
- 尚需人实测：每个固定速度5次，完整RL3状态行、稳定X、S3→S1和停车后至少3秒；六SW3轮次、K3单清零、K2计数/队列保留；载带平面尺子标定像素/mm，再判±1mm。实板停车重复性/保持、板载5V负载和真实补料尚未正式验收。
- 当前全部TD/ModelSim结束、无硬件操作或自动跟进。下一步收新bit现场视频，按稳定X与速度标定advance，不放宽窗口掩盖停偏。发布为校准候选，不冒称工程实板完成。
- 原未跟踪calibration*.txt/compact*.hex/region_cadence*.pgm及scripts/__pycache__为产物，勿stage全部或删除。releases稀疏路径用git add --sparse；保留-text原始字节并核Git索引SHA。
