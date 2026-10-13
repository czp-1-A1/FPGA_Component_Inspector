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

## 当前断点（2026-10-06，已交接）

- **目标/断点**：阶段A SW版视频花屏修复WIP；用户已批准修复、仿真、独立候选bit，现要求交下一队员。前root停止实现/构建，无活跃子agent。保持1024×600、取样字体Logo/双ROI、四KEY、四SW模式；CLASS_CALIBRATED=0，不做正式分类或新物料方案。
- **接棒第一步**：先读开发实施/验收记录/20261006_A_SW视频修复交接_轮次1/交接说明.md，再读tmp/sobel_fix_review_20261006/pre_sof_console.log与tb_pre_sof_tail.v。新early FS之后、真正pixel_sof之前残留4拍旧valid的专项已FAIL；核实真实AWB尾拍并最小修复，不能直接发布当前代码。
- **分支/基线**：hx1p35a-contest-work；HEAD f87ccf1c6a38e84b58a4f86cecd532a71ae56e89。大量既有未提交/未跟踪文件保留，不reset、不盲目重跑一次性实现脚本。未提交、未暂存、未推送，不称已同步。
- **本轮源修改**：video_in/video_out、roi_sobel_view、实际isp/data96_128 packer、isp_top、design_top_wrapper、roi_observation_snapshot、experiment_osd、osd_ascii_rom、SDC及相关sim/TB/资产。整行EDGE准入、短尾写、good/bad原输入证明、完整槽发布、跨VS排空、下溢余帧黑/下帧恢复、传输健康撤销有效性、OF/VF/UF页脚；当前early FS旧输入边界尚未修。修复前完整user_source/.al/.sdc/AGENTS在tmp/video_fix_before_20261006。
- **通过证据**：工程ModelSim16项日志均明确PASS（含真实ISP九帧及最新V字形OSD复测）；tmp/io_fix_review_20261006小/完整尺寸通过；tmp/full_transport_test_20261006四模式各两帧，921600实际MC写字、4915200显示像素逐值/地址通过，并通过停CSI、长ready暂停、响应跨VS和下溢恢复。MC为行为模型，写字指命令FIFO接受，不代表DDR物理完成；均未上板。
- **未完成/失败**：pre_sof_tail新刺激FAIL，见交接说明；额外真实ISP good/bad/packed内容proof中断于frame6，无最终PASS，需重跑tmp/sobel_fix_review_20261006/run_roi_proof.ps1。不能把原16项或四模式合成AWB测试代替这两个缺口。
- **TD状态**：tmp/video_fix_td_build_20261006补V前预构建完成，Slice16150/76.12%、ERAM48、DSP8，最终setup0.764ns/hold0.020ns/TNS0；新mailbox预算匹配且ignored0，vendor旧约束告警保留。最新V字形tmp/video_fix_td_final_20261006仅综合完成（setup1.872ns/hold0.114ns/TNS0），phy_1未运行。交接时最新207构建输入与工作区SHA一致；RTL再改后必须另建冻结目录重新综合/布局布线。
- **交接材料**：开发实施/验收记录/20261006_A_SW视频修复交接_轮次1/含交接说明、207输入源快照、前后10文件哈希、511副本manifest、16测试结果、专项通过/失败日志及TD报告，另有可转交zip。跨电脑须传实际文件，单靠Git HEAD不够。原花屏诊断与旧验收目录仍保留；uii2c.v:148既有行尾空格未清理。
- **下一操作**：修early FS旧valid→新pixel_sof边界；真实ISP proof和受影响回归完整PASS；冻结新207输入、重跑TD综合/布局布线及CDC/资源核对；生成新release/镜像SHA和验收记录，再用户上板先RAW、后四模式验证OF/VF/UF。当前无video_fix release，不能交预构建bit为已验收版本。
- **进程/设备/定时**：交接时无助手vsim/vopt/td_commands后台进程，无JTAG。用户TD GUI PID27224仍在，未操作或关闭。当前聊天定时续跑1-40-a已PAUSED，原计划保留，用户表示删除由其自行处理；避免自动出现第二实现端。
- **旧镜像**：sample_ui_20261005 SHA ab23766b4b51c4df1d331fc14ad7f5bcc8a5ddeeeae3a2aedb8929cf04332ea1；问题sw_edge_20261005 SHA a43156b8fc076d7940e12b8f7ba46d026a3053466b759724bef79235570bcd8c；交接时再次核对不变，旧release/Example未覆盖。
