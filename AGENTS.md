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

## 当前断点（2026-10-17，用户因额度不足要求立即GitHub交接，WIP未发布）

- 分支lj4747-contest-work，基线4556e9a；最新用户明确授权上传交接。本轮仅保存、提交和正常推送，不烧板/Flash，不切正式或临时交付指针。提交/推送结果以GitHub分支及交接回执为准；交接代码随本提交完整保存。
- 接力入口fpga/component_inspector/handoff/video_jitter_wip_20261017/README.md，HANDOFF.json为逐项状态；完整360输入、所有必要测试、失败轮次manifest+delta可重建、实际路由报告、21节奏测试/原视频分析和未发布bit均已纳入。scripts/verify_handoff.py核验逐文件SHA与负轮次重建；scripts/replay.py在新ASCII路径可直接prepare/sim/build。
- 冻结最终r15 manifest ed7cc98129abbd4bac0f92ccdae1fa18a5c34c579efccc321b0de1c26cbf34cf；实际构建r13 manifest7de1a3676fe09bc426ea288d52f5cee980782d38beda7fc09b8b818a9ed95ef1，生产代码逐字节相同，仅2个测试的独立行周期参考/测试变量清理不同。不要把测试only变更误认为换了未构建RTL。
- 仅5生产文件：zhenghe删除前帧行时长，以当前写入信用读；matrix空拍保持邻居；line_buffer首行完成按实际末写/读请求valid；signal_delay信用及首读；awb按有效组计EOL。识别阈值、3528/180mm/1092/40/WB100/原照明、四目标ID/UI/CDC/SDC/RAM/DSP不变。
- 旧生产r3 14813组/57957像素错（处理x1199..1279所有行，数量proof仍好）；r4 RAW独立真值1736错；r7/8变快截断643行；r11快慢probe复现；r12 RAW正确而行valid错26400组。负轮次全部保留；原首帧必坏断言改为首帧必须完整正确，坏尾/短帧仍拒绝。r13独立行周期参考误将气泡当行首、r14测试残留变量编译错误均保留，r15修测试计数参考，未降低像素/类别真值。
- 当前r13完整静止FHD前5帧均720行/172800字/差0，最后第6帧待最终PASS；21节奏切换/额外间隔全PASS；27FPS/四视图/13栅格12538001精确DDR像素、OF/UF0通过；HDMI/缩放/WB5项通过。最终状态以HANDOFF.json保存时刻为准。
- 新TD6.2.168116双角路由与独立实际约束审计通过：setup+.105/hold+.020ns、TNS0、STA92.94%，Slice17753/21216=83.68%，ERAM104/108、DSP26/40、PLL5/6；40max_delay匹配ignored0、20Gray位和全部20物理扇出8ns正余量。无新图像RAM，资源超80%不扩功能。历史相机/DDR/PLL/I/O覆盖边界仍在，不称全接口或现场抖动已验收。
- 未发布bit SHA c093c98bc5b59003c663a10f7c66e8c3a7d5600e30c583a5d16262630b969acd在candidate_unreleased；屏幕标题仍180MM STABLE IDS，必须按文件/SHA识别，不能当旧16bd8beb版。旧交付指针/正式current_codex_build未改。
- 下一步先读本机tmp/base_jitter_creditfix_r13_20261017/work_repeat/sim/modelsim_work/base_picture_repeatability/console.log和r15 safety.log/err。最后已知原生vsimk PID12360（完整6帧）/51284（安全余项），有限测试可继续，进程/本机tmp不随Git传输；新机按README重跑缺项，必须明确PASS且无Fatal/Error，ModelSim原生exit0不能替代通过。全测试后执行original_workspace_scripts/audit_video_credit.py（需按归档恢复轮次路径）完成组合审计，再打完整已验证发布包并更新候选；最后用户实板RAW/GRAY+EDGE复核。不要先标完工。
- 手机视频已原字节归档SHA a2070931...，拍摄/OIS/摩尔纹混入；用户确认RAW也抖是真值。仿真只证明行尾/节奏相关错像素，不能证明所有现场全图抖动同因。不要继续重拍分类标定或改阈值来掩盖视频问题。
- 根build_console.log/transcript、fpga/异常标定、fpga/测试及测试.zip为既有本机未跟踪原件，本次不混入；前次已归档标定来源保持。本轮用户请求优先立即交接，未开始新的独立工作或自动任务。

- 保存时测试状态：raw_timing_probe=PASS；base_picture_repeatability=PENDING_OR_INCOMPLETE；field_chain=PASS；hd_pins=PASS；hd_scaled_guard=PASS；hd_resize=PASS；manual_wb=PASS；fixed_wb=PASS；frame_tailproof=PASS；isp_metadata_stop=PASS；isp_writer_stop=PASS。
