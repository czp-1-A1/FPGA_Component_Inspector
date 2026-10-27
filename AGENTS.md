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
