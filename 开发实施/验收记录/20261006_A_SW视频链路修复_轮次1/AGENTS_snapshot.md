# 载带智检仪 Codex接力入口

## 核心规则

- 两人轮流用各自Codex实现同一工程，额度不足时接棒；第三人独立测试。无固定专业分工，A/B/C仅表示阶段。同一时间只有一个实现端写入，接棒须确认前端已停止。
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

## 当前断点（2026-10-06，SW视频修复候选已冻结，待实物验证）

- **授权/目标**：用户批准修复 SW 版视频花屏，撤销立即交接要求，继续推进且接近额度上限时预留交接。软件修复/验证/bitgen已完成，本轮无更多 RTL 写入。保持1024×600、取样字体Logo/双ROI、四KEY与SW1/SW2四种组合；CLASS_CALIBRATED=0，正式分类与三类物料算法待用户观察后确认。
- **分支/基线**：hx1p35a-contest-work；HEAD f87ccf1c6a38e84b58a4f86cecd532a71ae56e89。既有未提交/未跟踪文件保留；未暂存、未提交、未推送。冻结工作区含207构建输入及534证据副本，不能只用HEAD续接。
- **先读当前记录**：开发实施/验收记录/20261006_A_SW视频链路修复_轮次1/验收记录.md；镜像操作说明为fpga/component_inspector/release/video_fix_20261006/README.zh-CN.md，实物表在同验收目录/上板记录表.md。此前交接目录与ZIP是最终input_armed修复前的历史WIP，不代表当前源。
- **修复源**：video_in/video_out、roi_sobel_view、isp/data96_128 packer、isp_top、design_top_wrapper、roi_observation_snapshot、experiment_osd、osd_ascii_rom、SDC及相关sim/TB/生成器。行准入/帧尾/完整证明与槽发布、跨VS排空、下溢黑余帧后恢复、健康撤销/新样本恢复及OF/VF/UF。最终Sobel SHA94e0e630cb270a1b5bec4a17bcb438454dc362a7d46c54cdc78ba1ee61ddfa55；input_armed在early FS清，真实有效pixel_sof置，此前旧AWB valid不污染新帧。修复前源在tmp/video_fix_before_20261006。
- **验证**：默认16测试日志明确PASS；最终Sobel复测PASS，未改RTL依赖的测试保留早期PASS。真实ISP九帧及逐packed字增强proof在tmp/roi_proof_after_sof_20261006最终PASS；四模式各两完整1024×600帧、总921600字/4915200显示像素及故障/4种旧模式pre-SOF测试在tmp/transport_resume_verify_20261006全PASS。实际AWB/vendorRAM/divider前后对照在tmp/awb_epoch_verify_20261006：旧版契约Fatal，四模式复现旧3拍残留污染；修复版Errors0，旧拍抑制、指针/RAM保持及各8192像素/1536字精确恢复。无force。旧失败/中断/监测误判日志保留，不当PASS。
- **最终构建/镜像**：tmp/video_fix_td_after_sof_20261006，TD6.2.168116/PH1P35MDG324 speed3，综合、phy_1、bitgen完成。Slice16251/76.60%，ERAM48，DSP8；setup+0.310ns/hold+0.020ns/TNS0/违例0，STA94.54%；新增6mailbox预算匹配且shadowed/ignored0，既有警告详见报告。release/video_fix_20261006/camera_to_dsi_display.bit为1789539字节，SHA256 1584f39b53f315c369feb41617539dbbb944b455ae3fe84a045d7824dcfac0d5。534副本及207当前输入SHA一致，manifest在验收目录。
- **未测/下一步**：用户烧录该冻结bit，先SW下/下RAW观察1分钟，再分别GRAY/EDGE/GRAY+EDGE稳定后比较OF/VF/UF与竖条/花屏/闪屏；之后复位/冷启动/30分钟。根据实物结果继续定位，不能先称实物修好或进入分类标定。DDR MC测试是行为模型，写字仅代表命令FIFO接受，不验证物理DDR/MIPI/DSI。不要盲目再运行生成器或改冻结镜像。
- **进程/设备/额度**：本轮ModelSim和TD CLI已结束；无JTAG、未动用户TD GUI（PID27224）。并行agent仅独立tmp只读审计/验证。用户自行删除定时续跑1-40-a，不重建。最近成功额度读数周已用80%/余20%、5h已用14%；收尾工具读额度失败，不把旧值称为实时。后续接近限额时先保存当前代码/证据/断点再交接。
- **旧镜像**：sample_ui_20261005 SHA ab23766b4b51c4df1d331fc14ad7f5bcc8a5ddeeeae3a2aedb8929cf04332ea1；问题sw_edge_20261005 SHA a43156b8fc076d7940e12b8f7ba46d026a3053466b759724bef79235570bcd8c，最终冻结复核未变。既有uii2c.v:148行尾空格未清理。旧release/Example未覆盖。
