# V2已交付（2026-10-27，后续等待实板标定）

- 正式bit：E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V2_20261027.bit，SHA99d1593ffd97d127e2690d4fc9da816e93e8bac280bf7e768222f2f8ff9d03ed，与release原件/真实r3构建bit一致。资源Slice18972/21216=89.42308%，ERAM99/DSP30/PLL5，setup+.004/hold+.020/TNS0；所有49延迟、20 Gray Q、9邮箱、SW3、V2输出审计PASS。板载5V、3.3V HIGH、J2第1脚V2；无LED。
- 来源R22 a1cceaa，分支codex/r22-relay-left-v2，实现提交5b8d5a7/测试边界提交adddede，未推送。源码位置D:/CodexWork/FPGA_R22_Relay_20261027；旧E盘M1及以太网R2未替换。当前源码629项（628构建冻结+1后加native测试），发布1009载荷逐SHA/ZIP CRC全核；ZIP releases/r22_relay_left_v2_20261027.zip SHA09f9352bf7de703ac5ecf4aa0483fd352b9450a937abaa5ec0ed41f922d48514。
- 实际23项选定PASS：旧13，新控制/像素/RGB/默认100MHz完整1秒及最终LEFT/AUTO原生RAW正对照10；后者12帧、P,E,E,P四ID、两空队列在到站前>150ms持续送料、24精确显示栅格/22940469像素、OF/UF0。完整停车闭环另为RGB202帧/3次保持，不冒称原生RAW已到停车线或实板验收。
- 保留弱RAW280失败边界：source6形状5x3/亮点0原R22与本版608位结果完全一致，未改识别判据，未把失败算PASS；报告docs/R22_RELAY_LEFT_V2_WEAK_NATIVE_BOUNDARY.json和发布tests/retained_boundary。原基线RAW编译ISP为未加入类别校验的关闭分支，保留历史源码与等价证明；最终native_r2独立编译最终启用分支，不混淆版本。
- 交付/操作：docs/R22_RELAY_LEFT_V2_DELIVERY.json、FINAL_AUDIT.json、FIELD_GUIDE.md，BIT_FLASH同名前缀_说明.md/_RELEASE.json/_BOUNDARY.json。当前23条软件/布线通过不等于实板±1mm通过；先清晰料序低速空跑，从右引入首穴X800附近、左区清空，SW3上再下；旧队列人工核对后K3+K4全清。640计数/256左站编号/176触发/160目标，初始提前16/窗口±8像素，毫米未标定。
- 尚无吸嘴/补件完成握手；保持期间遮挡或将E改成P可能导致关联保护，先测试停靠1秒恢复。本版仅控制X；Y依靠导向并检查停住后漂移。后续据现场完整RL2 S/F/Q/N/X/L/V/W及毫米偏差调提前量，不放宽保护或把原始不确定性掩掉。
- 当前没有板卡烧录/电机操作、无子代理或新自动化。TD/ModelSim测试已完成，未推送。最终Git提交以git log为准；只有仿真输出可能仍未跟踪，勿清理用户其他工作。

# 原生LEFT RAW正对照已通过（2026-10-27 20:44）

- native_r2验证JSON已生成PASS：12源帧、24精确显示栅格/22940469像素、P/E/P序列共4ID（P2/E2）、两空队列在到站前>150ms继续送料，OF/UF0。23项选定测试已完成，弱RAW280边界单独保留未修复，不能混入通过数。当前进入版本化封装，只有发布脚本实际回执才确认BIT_FLASH交付。

# V2最终交付前断点（2026-10-27）

- 最终硬件：E:/2026FPGA/.codex_tmp/r22_relay_left_build_r3_20261027，628冻结源/104依赖，TD6.2.168116 seed2；bit SHA99d1593ffd97d127e2690d4fc9da816e93e8bac280bf7e768222f2f8ff9d03ed，已完成布线。实际Slice18972/21216=89.42308%，ERAM99/DSP30/PLL5；setup+.004/hold+.020/TNS0；49约束/20实际Gray Q/9邮箱/新旧SW3/V2/无LED全部PASS，physical_verification.json已落盘。audit脚本补了两处UTF8读取，源码硬件未动。
- 13旧回归+9新软件测试实际已过（signature_r2和support_r1），完整RGB202帧/6ID/3保持和V2默认100MHz100000000周期通过。新额外原生RAW测试native_r2仍运行：最终生产LEFT/AUTO分支、RAW360清晰空穴、12帧目标4个P/E/2空队列/到站前>150ms继续送料，以verification.json是否存在为准；当前日志11帧已total4/P2/E2、送料持续。独立新增测试台不在628构建源中，完整发布源629。
- 保留失败边界native_r1：镜像RAW280弱反光孔在source6只剩5x3/T100亮点0/不圆，source7计数延后，不能算PASS。精确原R22 detector+surface（仅改模块名）与新版本回放该源帧结果608位完全相同；weak_replay_r2证据和docs/R22_RELAY_LEFT_V2_WEAK_NATIVE_BOUNDARY.json。保持原识别判据；新RAW360作为停车运输的清晰正对照。原右向RAW测试台答案未动，新镜像P4在source9中心636尚未越过左滞回线，正确source10才过，新测试明确该差异。
- 原基线RAW在后加类别核对时尚运行；其ISP差异仅关闭的AUTO_RELAY/LEFT生成支路，发布脚本保留实际r2历史ISP并逐字证明其余一致；新native_r2则编译最终开启分支的冻结字节。不冒称所有早期日志使用最终ISP。
- Git已提交5b8d5a7a862817e79b1ac3d92eef70c11a03ecf4；后续仅附加原生测试/文档/审计脚本编码修正未提交，没有改628硬件源。当前未推送、未烧录、无子代理。新的bit尚未复制BIT_FLASH，发布脚本受native_r2验证门控，不能提前宣称交付。
- 下一步：等native_r2结果；若正常通过，23项选定PASS与已知弱边界分别记录，提交最终测试/指南后运行scripts/publish_r22_relay_left.py --work ...r3。预计文件R22_RelayAuto_Left_V2_20261027.bit，原件/ZIP保留且额外复制E:/2026FPGA/BIT_FLASH并验SHA，保护LATEST_READONLY.bit。发布后核验所有载荷/Git字节，更新本入口和交付JSON/资源/提交，无需硬件操作。
- 首轮人工：清晰已能识别的料序，第一穴位X800附近从右引入，左区清空；SW3上再下，旧队列先人工核对再K3+K4全清。目标160/提前16/±8px不是毫米已达标。先空跑停靠1秒恢复；手/吸嘴遮挡或填成P会改变原关联，实际补件动作与握手尚未实现，不能称自动补件成功。当前需实板±1mm/1秒/板载5V验收。

# V2进度更新（2026-10-27，最终源码已冻结，尚未交付）

- 当前codex/r22-relay-left-v2，父799ca6b，无推送。新增pocket_relay_stop_v2.v和双门控编号、32项队列、15秒到站等待、到站后150ms实测过期、完整1秒保持。启动S5要求640线下游及左站无未编号目标；原R22下方ROI改为同上方料道左侧64..447，右区448..831，二次编号256/触发176/目标160。人工设置右向左。
- 新增全局300项P/E类别历史与左站顺序比对，左站事件核对通过后才允许同编号位置停车；不同类别错位停止。同类穴位完全漏检不能凭计数证明排除，必须已知料序验收。新控制器41项故障断言已通过。
- 原R22 local_edge_surface_check灰度缓存原只覆盖X384..895；左布局显式改为X48..847/Y224..415，保留Sobel强度/暗背景判据。实际5幅全1280x720像素测试证明两ROI分类、六候选头保留、空区启动均过；新UI双完整栅格94字/3拍/帧冻结已过。预测只用于候选保留，停车位置仅同源帧实测。
- 完整RGB闭环202帧/6个全局ID/3个空穴保持/54帧未到站运输等待已过，V2默认100MHz的100000000周期保持已过。加类别核对后的最终四项重跑位于E:/2026FPGA/.codex_tmp/r22_relay_left_signature_r2_20261027；V1三项+新像素/UI最终重跑位于.../r22_relay_left_support_r1_20261027，以各verification.json是否完成为准。
- 当前最终TD构建.../r22_relay_left_build_r3_20261027，628冻结源/104硬件依赖/seed2。r1旧候选setup-0.342且源码已更新，不可交付；r2未带类别核对，setup+.001/hold+.020、ERAM98/DSP30，但源码已更新也不可交付。r3通过后需scripts/audit_r22_relay.py --left-v2 --work ...；49max-delay/20Gray/9邮箱/新旧SW3/V2/无LED不放宽。
- 原13项实际回归含一项原生RAW MODE1正在sim/run_modelsim.ps1运行（临时目录E盘），日志.../r22_relay_left_legacy_20261027.log，具体输出sim/modelsim_work；不把原V1三MODE/历史144项充作本次重跑。新布局闭环是处理RGB，不声称左布局原生RAW闭环实板已过。
- docs/R22_RELAY_LEFT_V2_FIELD_GUIDE.md及FIELD_FEEDBACK.json已写；新发布脚本scripts/publish_r22_relay_left.py尚未运行，需最终物理+13旧/9新=22实际测试通过、源码匹配、提交实现后才能运行。目标新bit R22_RelayAuto_Left_V2_20261027.bit，额外复制BIT_FLASH并核SHA；原V1/以太网R2不改。最新code/仿真/构建状态以文件回执为准。
- 无硬件操作、无烧录、无子代理。仍待实板±1mm/1秒和板载5V负载测试。现在有自己的ModelSim/TD进程；不得误停用户其他进程。下一步先检查进程回执、完成STA和仿真、审计、Git提交，再版本化发布新bit。

# V2当前断点（2026-10-27）

- 当前分支codex/r22-relay-left-v2，父799ca6b；用户已确认改为屏幕右向左、左侧补件。V1现场F6未完成保持，不视作通过；第六次无法启动原因未证实。
- 正在实现右计数640/左站二次编号256/停车160，共用图像RAM和分类器；启动先核对两门间无料，再保持两个编号前缀一致。运输等待与150ms位置过期分开，保留严格故障停止。
- V1冻结包/bit不改；下一版需要实际仿真、TD布线、时序/CDC/IO审计和新SHA后另名交付。当前不得烧录或称V2已通过。
- 人工设置送料反向；软件不会操纵三档机械开关。板载5V/3.3V HIGH/V2=J2 pin1和无测试LED保持。

# R22自动继电器停车接续

## 当前规则

- 当前用户授权直接接自动空穴停车，触发线/提前量后续实测；继电器5V来自开发板，3.3V HIGH触发、不加NPN，V2=右J2第1脚；集成版不加测试LED。
- 新bit原件/发布包保留，额外复制到E:/2026FPGA/BIT_FLASH并核对SHA；不得替换已连通以太网R2的LATEST_READONLY.bit，也不得覆盖不同SHA的旧同名文件。此项替代上游其他机器桌面约定。
- 人工操作实物，助手只做源码/仿真/构建/分析；只有一个实现端，原R22生产端已在交接中确认停止。无证据不判通过，不放宽SDC、删旧功能或改测试答案。
- 保持原R22识别/计数/编号/中文/Logo，独立分支实现停车；不把候选保留预测、显示排序或历史事件帧当实时位置。未标定±1mm、未上板不称通过。
- 每完成可接续步骤更新本入口：基线、改动、证据、未决、下一步、进程、提交/推送。详细说明见docs/R22_RELAY_AUTO_FIELD_GUIDE.md。

## 当前断点（2026-10-27，R22自动停车联调bit已交付，现场标定待测）

- 分支codex/r22-relay-v1，父origin/r22-local-edge-20261027=a1cceaa。新工作目录D:/CodexWork/FPGA_R22_Relay_20261027；旧E:/2026FPGA/FPGA_Component_Inspector仍codex/relay-stop-v1/R19，不覆盖旧M1/J2诊断或只读R2。
- 创建完整E盘副本因空间不足失败，Git自动回收了失败目录；无用户文件被清理。改用D盘稀疏worktree，排除不需要的开发历史/机械文件，仅影响新副本；用户随后清理E盘，实际构建位于E盘新目录。
- R22改前615源/3874归档载荷/144日志/102依赖身份校验PASS：E:/2026FPGA/.codex_tmp/r22_identity_20261027.json。R22原bit SHA a07bd753296d320c495f234669477563f1f34cdc60af87089575b3bc1bad4df2；原冻结包不改。
- 新模块pocket_relay_stop.v：8个EMPTY编号队列、同内部RUN查询新帧实测位置、目标线触发、3帧静止/窗口确认、1000ms合格保持再恢复；坏帧/失锁/方向/过期/越位/漂移/队满故障停止。SW3上撤销许可，下沿用原新RUN；旧待处理ID不能因重开RUN静默丢弃，原K3+K4全清用于明确确认。
- 计数器/流水线增加默认关闭的实测查询旁路，APPLY采实际cx/cy，PUBLISH仅在整帧可信RUN无gap时发布；ISP接停车控制，top加V2输出及同步SW3许可/32位显示邮箱。OSD右上增加RLY状态/队首/实测X与目标/触发线；新IO=1，无LED。原判定、编号算法不改。
- 初值处理图1280x720、向右、目标X760/提前24/窗口±8px/漂移2px；这些不是已标定毫米值。接口和接线详见现场指南。
- 新软件检查已实际通过：控制器2055检查、真实编号流水线35061检查/29个同ID实测位置/1事件1完成，以及默认100MHz完整100000000周期/1秒保持。证据E:/2026FPGA/.codex_tmp/r22_relay_unit_r5_20261027；早期编译问题及修复r1～r4保留，未改旧bench答案。
- 完整候选r2冻结618文件、103硬件依赖、12文件差异，实际TD6.2.168116/seed2完成布线；Slice19429/21216=91.57711%（比R22新增413）、ERAM101/DSP27/PLL5，setup+0.005/hold+0.020ns、双TNS0。49条max-delay全匹配/ignored0、20条实际Gray Q、9组邮箱、原/新SW3同步链及V2输出均数值审计通过：E:/2026FPGA/.codex_tmp/r22_relay_build_r2_20261027/physical_verification.json。r1为准备目录碰撞的失败记录；原R22工具6.2.178840，未复用其时序结论。
- 原R22选定15项真实回归全过，包括三种MODE原始输入/精确RGB/27fps节拍，原计数/局部恢复/清零/SW3/UI；加新增控制器/编号流水线/默认1秒/UI双完整栅格/连续队列5项，共20项实际执行。未改旧bench答案，未将原R22历史144项算作本候选重跑。
- 交付releases/r22_relay_auto_20261027/及ZIP，621完整源/813载荷逐SHA核对；bit R22_RelayAuto_V1_20261027.bit SHA94a8a431c9ca4f6da5b2c55bff78a392c1cb8af0ccad0e754fc9180bbe436ba6，工程原件与E:/2026FPGA/BIT_FLASH副本一致。ZIP SHAd81095b8efca312a7ad9bd5d296bada6ddcdbeed33133fb5970873014665f24d。原R22回退bit也复制到BIT_FLASH，原已连通以太网R2不替换；docs/R22_RELAY_AUTO_DELIVERY.json记录完整路径。
- 下一条人工上板：先核对R22画面/供电，再SW3上约0.1秒后下开新RUN；固定向右，记录已知空穴ID、断电位置、最终X及F码/S2→S3→S1。初值目标760/提前24/±8px尚未换算毫米；如F8，保持停止并据最终X调整提前量，不能放宽验收目标。
- 当前无运行中TD/ModelSim，无板卡/JTAG/Flash/继电器/电机操作，无子代理；最终提交状态以Git为准，未推送。±1mm、实际1秒稳定保持、板载5V负载和视频实板回归待测。详表开发实施/验收记录/20261027_R22自动继电器停车_软件布线交付.md。

## 原R22上游冻结交接（历史参考）

## 当前断点（2026-10-27，R22上传供另一AI接棒）

- 目标：本分支r22-local-edge-20261027发布R22精确615源、bit/完整证据包和可携验证入口；用户最新反馈“稳定性不错，正常速度没问题”，高速仍待验证。详见docs/R22_HANDOFF.md和releases/r22_20261027/FIELD_FEEDBACK.json。
- 基线：上传父277bcbda44cc1ca73e4dde5c7322169e5572ea7c，主工作分支和旧R19/P03/R13保留；R22生产冻结candidate_r6 manifest 8e81b47dcd40d88b461aae525e946d5c41bd175691bc66f896b9dc34989541bf，非父R19的临时增量。原Example保留，当前工程fpga/component_inspector。
- 改动：局部四向Sobel复用同一灰度RAM，候选保留/孔排角色/灰度暗背景联合；P03保留，弱边缘P只置复核；原计数/恢复/元数据/控制/ROI/SDC及中文/Logo保持。两页R22。
- 验证：144实际软件、46独立参考、615源/144日志/102依赖和3874归档载荷核验；最终Slice89.63047%/ERAM101/DSP27/PLL5、setup+.001/hold+.020/TNS0，46maxdelay/20Gray/6邮箱/SW3审计通过。源码615SHA与bit/ZIP在release目录。用户正常速度反馈不替代所有边界实板验收。
- 下一条：先核对branch/HEAD/status，再python scripts/r22/verify_r22.py；同冻结镜像采高速正反、首末和连续空样本定位剩余问题。跨机TD工程按R22_HANDOFF可携重建，不盲跑原机绝对路径脚本或旧版本验证器。
- 进程/设备：本聊天生产端停止、无仿真/TD/自动跟进/子代理，无板卡/JTAG/Flash/用户GUI操作；r12保持暂停。当前隔离上传工作区D:/CodexWork/r22_github_upload_20261027，普通新分支推送，禁止覆盖其他分支/强推。提交及推送结果以实际Git/远端回执为准。
