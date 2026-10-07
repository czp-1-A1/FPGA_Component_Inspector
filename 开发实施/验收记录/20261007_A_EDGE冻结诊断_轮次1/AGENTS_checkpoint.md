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

## 当前断点（2026-10-07，按用户要求立即交接）

- 用户因额度不足要求停止本实现端并交接；不再继续功能开发。后续实现端先核对本文件、冻结交接文档和实际Git状态，确认此前实现端已停止。当前没有运行中构建/仿真/JTAG；两个只读agent已中断，第三个完成，用户TD GUI未操作。
- 实物反馈旧video_fix_20261006：RAW无花屏，EDGE冻结且返回RAW恢复；FR/SEC变化、VF增长，OF/UF不增长；GRAY时FR/SEC变化而OF/VF/UF不增长（GRAY移动画面未直接确认）。实物具体拒帧来源仍未知，不能称EDGE已上板修复。
- 新候选release：fpga/component_inspector/release/edge_diagnostic_20261007/camera_to_dsi_display.bit，SHA c3a1cce7d4a19d6750c0e6f3e36395a3c2f3d31901834a1b13a76f497a9230f8，1789539字节。冻结资料：开发实施/验收记录/20261007_A_EDGE冻结诊断_轮次1；交接入口交接说明.md。冻结脚本tmp/freeze_edge_diagnostic_20261007.py，执行结果见tmp/edge_diagnostic_delivery_20261007/freeze_result.json；若该文件缺失，先核对release/record是否已建立，再核对manifest，禁止直接覆盖重跑。
- 分支hx1p35a-contest-work，HEAD f87ccf1c6a38e84b58a4f86cecd532a71ae56e89；大量既有未提交/未跟踪文件保留。未暂存、提交或推送。不能只传AGENTS或仅checkout该HEAD；必须复制完整冻结源、release和验证记录及所需未跟踪文件。
- 本轮最小修改：Sobel删除逐行pipeline_idle门控，允许连续行（4行缓存容量不改）；新增16bit饱和LP最短Sobel输入行周期/WS最长信用等待；ISP每AWB early锁存上一epoch四位cache/config/lane/guard拒帧原因及LP/WS。OF mailbox扩16→52bit，OSD标志下显示ER/LP/WS十六进制；字体/Logo ROM哈希不变。ER0不证明完整帧发布，LP不是nativeCSI直接测量。保留1024×600、双ROI、KEY/SW组合、CLASS_CALIBRATED=0。
- 当前Sobel SHA377f6b3ff67cd3f11a744ce3cf0839576f78431754845eaba78cb014e4c3de11。本轮八个实现/验证文件差异在additional_tests/edge_diagnostic_validation_20261007/current_turn.diff；原文件备份tmp/edge_freeze_before_20261007。未改物料算法、标定、DDR仲裁或缓存容量；此前用户新物料算法仍要求确认再生成。
- 最新源验证：Sobel旧零行空闲FAIL、新11帧逐像素PASS；OSD四模式完整栅格PASS；LP/WS独立18场景、逐周期不影响视频PASS；52bit CDC原子/停钟/reset PASS；真实MC的RAW→EDGE→RAW和GRAY→GRAY+EDGE→GRAY全部帧逐字逐像素PASS，1000拍暂停完整PASS，2000拍暂停明确拒坏/保旧槽/下一RAW恢复。默认16项只重跑sobel_view/osd，未称全部重跑。
- 真实ISP/AWB：最终源13前缀mode/epoch/fault快照PASS，另1个native640有效+gap160/600行完整EDGE PASS，614400像素、guard/good成功，下一early ER0/LP800/WS0；同源gap32完整帧明确FAIL（累计几何不足），负例保留。没有实测nativeCSI行时序，不能当实物唯一原因。详见additional_tests/edge_freeze_awb_20261007/lifecycle_after_diag/RESULTS.md和final_diagnostics_manifest.json。旧39场景MC调查未找到实际gap384下RAW独过而EDGE独拒的窗口。
- 完整TD综合/place/route/bitgen结束；207冻结输入与工程哈希一致。最终setup+0.858ns/hold+0.020ns/TNS0/违例端点0；16397 slices(77.29%)/48ERAM/8DSP，STA94.53%。新52bit mailbox预算payload208/208、req/ack2/2，无覆盖/忽略；旧PLL/IO/例外约束告警保留，与旧版警告语义相同。最终审计tmp/edge_diagnostic_final_audit_20261007/final_audit.json。
- 下一条具体操作：按冻结README烧录新bit，确认Logo下ER/LP/WS；RAW→GRAY→EDGE→GRAY+EDGE→RAW各等2秒后移动载带观察10秒。如仍卡，取全屏ER/LP/WS/FR/SEC/OF/VF/UF并记录退回RAW恢复；根据实测再决定最小修复。当前不做材料灰度标定，无需固定载带位置。旧video_fix_20261006及其534证据未修改，旧bit SHA1584f39b53f315c369feb41617539dbbb944b455ae3fe84a045d7824dcfac0d5可回退。
- 不重建用户删除的定时任务，不新增线程或向其他线程发消息。交接本地文件完成后本端停止，等用户后续授权。
