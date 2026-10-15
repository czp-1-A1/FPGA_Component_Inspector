# 载带智检仪 Codex接力入口

## 核心规则

- 三人轮流用各自Codex实现同一工程，额度不足或需要换人时接棒；无固定专业分工，A/B/C仅表示阶段。同一时间只有一个实现端写入，接棒须确认前端已停止。独立测试必须使用冻结的代码/镜像，与当前写入端隔离，不得边测边改答案。
- 先核对Git分支、HEAD及未提交/暂存/未跟踪文件，再从下方断点继续。默认续接同一任务分支，不重做已验证工作，不覆盖他人改动，不盲目拉取、重置或强推。
- AI负责实现与分析，人负责实物操作、真值和现场复核。只有一块板；验收冻结代码与镜像，不能边测边换。测试端不修改答案或事后降低目标。
- A：步骤1—4，Lab 1视频→视场→固定ROI正常/空穴→处理视图、Logo、结果与冷启动；B：步骤5—6，运动、编号与失锁恢复；C：步骤7—8，NG队列、停车与复检。可选算法不阻塞A。
- 以Lab 1的1024×600配置起步；改RTL前核对实际像素接口、PPC、同步和CDC。每次集成检查本机资源、完整约束与布局布线时序，同时验证视频。
- 无证据不判通过；未测、仿真、编译、上板和人工复核分别记录。上板绑定提交/工作区快照、TD版本、镜像SHA-256与证据；输入帧率不能用HDMI刷新率代替。

## 工程目录

开发工程统一放 `fpga/`，本机完整路径 `D:/BaiduNetdiskDownload/HX1P35A_Contest_202606/FPGA_Component_Inspector/fpga`。工程目录及其依赖文件使用英文/ASCII命名、无空格、相对引用；其他电脑的仓库父路径也需全英文。当前候选底座为 `fpga/component_inspector/`，TD入口 `td_project/camera_to_dsi_display.al`；保留例程内部布局，不要求套用之前的空目录骨架。原始Example保留不动。

## 按需读取（均在开发实施目录）

| 任务 | 文件 |
|---|---|
| 阶段顺序/通过条件 | `00_分阶段开发与逐级验证路线.md` |
| 测试记录 | `01_阶段验收记录模板.md` |
| RTL实现 | `02_FPGA资源预算与代码优化规范.md`、`04_FPGA接口与异常处理约定.md` |
| 架构/接力细节 | `03_系统框架与Codex接力协作流程图.md` |

只读本轮相关章节。最新用户决定优先于旧分工；示意图不代表源码已实现。

## 强制交接更新

每完成一个可接续小步骤及结束本轮前，直接更新下方断点，不等额度耗尽、不重复询问。仅保留当前有效摘要，历史详见Git或独立记录，不在本文件累积长日志。

摘要必须包含：目标与断点、分支/代码基线、改动文件、验证及证据、未决事项、下一条具体操作、运行中进程/设备、提交/推送状态。测试详表放 `开发实施/验收记录/日期_步骤_轮次.md`，失败与复测分别保留。

交接需包含代码、必要未跟踪文件与证据，不能只传本文。按授权提交/推送，不混入无关暂存文件；成功推送才可称已同步。接棒端核对工具依赖、实际文件与日志；Git不传未提交文件、进程或聊天。意外断额度时由人保存改动，接棒端恢复实际断点，WIP不当作稳定版。

## 当前断点（2026-10-15，V10视频优先发布验证完成，准备上传）

- 目标/现场：用户新图DA FRAME EXP V9/RAW仍黑，P5B W1C200、LP0CF0、FPS26 CFG1、VF0203、OF/UF0，V9现场FAIL_BLACK。V10软件与完整构建通过，尚未上板；不能声称物理黑屏全部根因闭合。同一3528/载带、全1024×600、最多双对象、无算法区域框；SIZE/ASP/FILL/REF非标定质量分类。
- 分支/基线：lj4747-contest-work，HEAD36ef39f2e75be99904c02a5a9a9c9ef693e2da1c（远端同），本轮改动尚未提交；V9源码2f7a891/bit b954f61a…d26268保留，现场失败。根build_console.log/transcript不加入。
- 实现：仅video_in、wrapper、experiment_osd三个生产文件变化（215生产输入已冻结并核对）。LOCAL_SEARCH开启VIDEO_FIRST，完整像素立即发布零结果，随后仅同writer_epoch/同completed slot补全一次迟到元组，新FS/坏帧取消；reader仍VS原子快照，不改正在显示的帧。DB FRAME EXP V10；模型/阈值/原生完整性/连续100MHz/SDC不改。运行器增加3测试条目并恢复原EOL/BOM，规范化文本与实际冻结测试运行器相同；不重跑无功能变化测试。
- 复现：tmp/video_first_v10_v9_repro_20261015旧215输入复现小帧P5B；tmp/video_first_v10_v9_cadence_repro_20261015旧215输入在26FPS/行间停钟/full-frame复现P5B W1C200 complete1 good1 bad0 ready0 wait1239663，到38.459ms仍不发布。该反例用WB取消模拟缺结果，不推定现场WB变动；P是累计seen，不能当同拍证明。r1错误cap断言失败原源/日志保留，cap实为上次完整画面状态，修正夹具仍严查短/坏/epoch隔离。
- 验证：最终tmp/video_first_v10_r4_20261015全部20项ModelSim及独立24图PASS。7帧实RAW10/校正/ISP/vendor ERAM，native LP738加行间停CSI、连续域LP0CF2、起点26FPS，四模式、亮背景、WB无结果活视频；13完整栅格/8025234逐像素DDR参考比较，OFUF0。独立384像素检查迟到tuple仅VS可见、active slot保护、一次补全。原停钟/帧尾/模式取消/额外RAW/epoch/显示/guard回归保持。r2/r3前序成功夹具及源日志也归档。
- TD：6.2.168116 syn/phy结束，Routed双角setup+.122ns/hold+.020ns/TNS0，Slice14420/21216=67.97%、ERAM72/108、DSP20/40、STA92.76%。38显式+2厂商40 max_delay全部匹配ignored0；20逻辑Gray位/20物理路径经路由DB逐位绑定，8ns全部实际主导。SDC字节同V9，未松约束；告警125/12与V9相同，无新增类别，保留历史DDR/PLL反馈/I/O未延迟告警与完整时钟分析。
- 发布/归档：release/video_first_v10_20261015/camera_to_dsi_display.bit，1789539字节，SHA e9542e0612e7491e5ff7305cc263a3898c4d8eef32320a126e7c3dc189470cef；顶部DB FRAME EXP V10。current_codex_build指V10 PENDING，previous_v9_onsite=FAIL_BLACK。60_A3528视频优先发布_V10黑屏修复与上板说明.md；验收记录/20261015_A_V10视频优先发布_轮次1含V9照片、215完整源/20日志/24参考/TD/失败历史/重放输入，2170项347759616字节全SHA核对。原V9/V8/V7 bit SHA不变。构建source_commit=null是实际事实，随后上传回执另绑提交。
- 下一步/进程/提交：所有本轮ModelSim/TD/查询已结束，无JTAG/Flash。下一步显式暂存新源、镜像、说明及完整档案，运行tmp/verify_stage_v10.py核对Git暂存字节后提交/上传既有分支；Git HTTPS上轮不可达，官方Git Database API已可用，本机GCM凭据只在内存、force=false，Windows长路径需core.longpaths=true。本轮上传成功前不称同步。之后写独立上传回执/核对远端HEAD，等待人工烧录DB V10、RAW/四模式/复位/双目标及P/W或M、VF/OF/UF照片；没有新反例不重复已过软件/TD。
