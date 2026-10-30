# 双列计数对接交接说明（R27B，2026-10-30）

本文供原来接单列计数的队员迁移到双列计数使用。内容按实际 RTL 核对；网络发送、跨时钟缓存、上位机数据库仍由以太网队员实现。本文及配套差异包是补充文档，不修改已验收的冻结源码或原发布包。

## 1. 应该用哪一份工程

- 当前正式完整包：`R27B_EmptyStart_20261029_dd5cefc1_source_and_evidence.zip`。
- 当前正式 bit：`R27B_EmptyStart_20261029_dd5cefc1.bit`，屏幕版本为 `COUNT R27`。
- bit SHA256：`dd5cefc10120af57247d00113f4a5ce2066095b2d8b8b759e372ba46094ff3d3`。
- 完整包内源码入口：`fpga/component_inspector`；`build_evidence`、`unit_evidence` 为执行证据目录，迁移源码使用前者项目入口。
- 本机权威源码：`D:/FpgaWork/dual_roi_r27b_20261029/fpga/component_inspector`。
- 本文所称“单列基线”：本机保留的 `D:/FpgaWork/dual_roi_r23_20261028/fpga/component_inspector`。历史 R24 交接记录其基线分支为 `r23-present-trace-20261028`，提交 `6f2d91cff2280b8b4a53ae08c7fc74fe58406f7a`；本次差异按本机两目录实际文件字节生成，并附双端 SHA。

队员自己的单列版本如果是更早的 R19 或已经修改过的网络分支，不能把这份 R23 补丁直接当作该分支的精确补丁。优先在完整 R27B 工程上迁入已有网络模块；如必须在旧分支合并，按本文接口逐项迁移，保留对方自己的引脚、网络逻辑，再重新综合、布线和验收。

## 2. 双列的实际含义

这里的“列”对应屏幕上下两个有效框，不是画面左右两半。默认处理图像为 1280×720，两条料带沿 X 方向移动：

| 项目 | ROI1 / bank0 | ROI2 / bank1 |
|---|---|---|
| X 范围（左含右不含） | [400,880) | [400,880) |
| Y 范围（上含下不含） | [240,400) | [432,600) |
| 计数线 | X=640 | X=640 |
| 型号配方 | 3528 | 3528 |
| 编号 | 本列 001～300 | 本列 001～300 |
| 独立状态 | 总数、有件、空穴、复核、空穴号、方向、跟踪/恢复状态 | 同左，独立维护 |

坐标由 `inspection_region_config.v` 的比例参数决定，上表只对应默认分辨率；不要用于原始 1920×1080 RAW 坐标。该文件两区默认均为相同 3528 配方，本次迁移无需改器件型号。

每列 `TOTAL=PRESENT+EMPTY`；`REVIEW` 是有件中需要复核的子集，不能再次加到 TOTAL。同一段内 ROI1 的 001 与 ROI2 的 001 是两个不同对象。两列方向可以相反；局部反向、缺件观察和跟踪异常不共用另一列的运动状态。采集帧故障、配置取消、用户命令是共享条件，可能同时影响两列。

SW3 仍是两列共同开新段：先上拨稳定至少 20ms，再下拨；只触发一次，上电已下拨不会自行开始。KEY3+KEY4 持续约 1s 共同结束并清零显示。没有新增单列独立启动按钮。每列满 300 后结束该列计数；没有整卷无限编号承诺。

## 3. 哪些源码改了

以下路径均相对 `fpga/component_inspector/user_source/hdl_source/`。实际比对 R23 单列与 R27B，共 **9 个生产文件修改，无新增/删除 user_source 文件**。配套 `R23_to_R27B_production.patch` 是这九个文件的完整文本差异，`SOURCE_CHANGE_MANIFEST.json` 列出新旧 SHA、差异行数和未改文件数量。

| 文件 | 单列到当前双列的实际改动 | 对接时的处理 |
|---|---|---|
| `design_top_wrapper.v` | 增加并默认开启 `ENABLE_DUAL_REGION_COUNT=1`；COUNT_BITS 从 256 扩为 512；统计视图、元数据和显示 CDC 按两 bank 处理；传递双列参数 | 必须同步迁移宽度、参数、CDC 和 DDR 元数据路径；在 `u_isp_top` 实例补接事件输出，当前生产顶层未连接这些事件端口 |
| `isp/isp_top.v` | 增加双路事件输出；按参数生成双列/单列计数流水线；两组恢复位置反馈；启用双列稀疏扫描；R27 增加同帧结果与完整帧证明的汇合 | 网络数据的首选接入点；保留原帧证明、取消和开段边界逻辑 |
| `classified_count_pipeline.v` | 原单列模块保留；同文件新增 `dual_region_count_pipeline`，实例化两个单列流水线；每列只接自己的候选；输出拼为 512 位；两列 ready 同时满足才发布帧包；包含 R26 开段 epoch 修复 | 不能只复制原单列 module；该文件同时定义两个 module，无需新增名为 dual_region_count_pipeline.v 的文件 |
| `classified_pocket_counter.v` | R24 时序收敛时为已被 RECOVERABLE 上游覆盖的后备分支显式增加 `!RECOVERABLE`，排除无效组合路径 | 保持现版；编号、分类事件语义保持，不能把该变化解释为新检测算法 |
| `frame_shape_search.v` | 增加双列参数和第二组恢复位置；两列分别选候选；R25 稀疏行扫描和队列读调度缩短密集双列处理；R27B 两层平衡比较并行选两列槽位 | 与 ISP 参数一起迁移；只换此文件而不启用实例参数，不等于完成双列优化 |
| `local_edge_surface_check.v` | R26 将表面灰度极值比较改为整数等价表达式，缩短组合路径；不改分类阈值和周期 | 当前可交付实现的一部分，应保留，不能与更早文件混搭后沿用本版时序结论 |
| `classified_dual_page_osd.v` | 增加双列参数；计数 live/frame 输入扩成 512 位并向渲染器传递 | 显示端及实例参数一起迁移 |
| `compact_inspector_osd.v` | 同时解析两个 256 位包；显示各列 T/P/E/R、空穴页与四个显示目标的本列编号；各列校验本轮次和帧归属 | 显示目标槽不是稳定编号；网络不要从屏幕文本/槽位反推事件 |
| `compact_template_rom.v` | 双列计数页模板和字段位置；版本文字更新为 COUNT/DETECT R27 | 与 OSD 同步，否则字段错位或显示旧版本 |

注意：“R27B 相对 R26 只改三个生产文件”指最近一次增量，即 ISP、FSS、ROM；**不是从单列迁移只需要三个文件**。

未改动的控制、配方、原图像通路和约束是否与队员分支一致，应通过 SHA/差异检查确认；本交接不替队员决定覆盖其网络侧修改。

## 4. 数据在工程里怎么走

```text
RAW / 完整帧保护 → 共享 ISP / frame_shape_search
                          ├─ ROI1 四候选 → 计数流水线0 → ROI1事件 / 256位包
                          └─ ROI2 四候选 → 计数流水线1 → ROI2事件 / 256位包

逐号事件（100MHz处理域）→ 待队员补接：双路接收/缓存 → 网络域 → 以太网 → 保存/查询
两列256位包拼512位 → 原帧元数据/DDR槽位/显示快照 → 双列OSD
```

共享一次图像检测，不复制两套全图 RAM。生产 recorder 候选为 608 位，每个候选 76 位，每列四候选；低 304 位为 ROI1，高 304 位为 ROI2。计数流水线隔离本列候选并把另一列候选清零，因此原单列“两个区域同时出现就冲突/C2”的限制不会阻止双列计数。

屏幕检测槽只有每列两个，共四个显示目标；内部计数候选每列四个。候选槽/显示槽排序会变化，不能当永久 ID。

## 5. 给以太网队员的逐号事件接口（最重要）

实际定义在 `isp/isp_top.v` 第 10～18 行；生产参数 `DUAL_REGION_COUNT=1` 时端口如下。全部属于 `post_clk`，当前为顶层 `S_process_clk` / 100MHz。复位为 `I_rst_n`，低有效。

| 端口 | 双列总宽 | ROI1 / bank0 | ROI2 / bank1 |
|---|---:|---|---|
| `count_event_valid` | 2 | [0] | [1] |
| `count_event_run` | 32 | [15:0] | [31:16] |
| `count_event_id` | 18 | [8:0] | [17:9] |
| `count_event_frame` | 64 | [31:0] | [63:32] |
| `count_event_kind` | 4 | [1:0] | [3:2] |
| `count_event_reason` | 8 | [3:0] | [7:4] |

`valid[bank]` 为一处理时钟周期的有效脉冲，只在正式提交编号时产生。同拍两位可以都为 1，端口无 ready/反压。每列有效时读取该列全部字段；valid=0 时其他位可能保留旧值，不能当新事件。

`event_frame` 是源检测帧的身份，不是显示帧计数，也不保证等于事件输出当拍正在处理的最新帧；延迟提交时保留原记录帧。HDMI 重复显示同帧不会再产生编号事件。

状态解释：

| event_kind | event_reason | 下游业务状态 |
|---:|---|---|
| 2 | 0 | 有件 |
| 2 | 非0 | 有件复核，同时计入 PRESENT 和 REVIEW |
| 3 | 任意 | 空穴，计入 EMPTY；保留原原因位，不因非0就归为有件复核 |
| 0 或 1 | 任意 | 不属于当前正式 P/E 编号输出；若对接收到，作为协议/集成异常检查，不自行补号 |

reason 为 4 位原分类诊断掩码，不是单一枚举：bit0 尺寸、bit1 长宽比、bit2 填充，bit3 在本版启用表面判定时包含表面复核语义，其他分支可为侧边灰度参考。保留整个掩码，多个原因可同时成立；不要把所有非0都翻译成同一种物理缺陷。帧包里的跟踪原因 C1/C6 等与此分类 reason 是不同字段。

建议数据库键：`设备/上电会话 + ROI + event_run + event_id`；附带 frame、kind、reason。run 是内部 16 位轮次，上电复位且有回绕可能，不能作为跨设备、跨上电的无限唯一 ID。UI 显示 RUN 与内部 event_run 不总相同：清零可令显示轮次归零，但内部身份不按显示值回退。

例：ROI1/run7/id001/kind2/reason0 与 ROI2/run7/id001/kind3/reason0，必须保存为两条不同记录。上位机“复核”可直接计算为 `(kind==2 && reason!=0)`。

### 顶层需要补接的位置

当前 `design_top_wrapper.v` 的 `u_isp_top` 实例只连接 count_command/count_live，未接 count_event_*。队员在该实例所属的处理域新增以下线并连接端口即可取得事件；下面只是接线示例，尚未写入已交付 RTL：

```verilog
wire [1:0]  net_count_valid;
wire [31:0] net_count_run;
wire [17:0] net_count_id;
wire [63:0] net_count_frame;
wire [3:0]  net_count_kind;
wire [7:0]  net_count_reason;

// 添加到现有 u_isp_top 命名端口列表，注意与前后端口间的逗号：
.count_event_valid(net_count_valid),
.count_event_run(net_count_run),
.count_event_id(net_count_id),
.count_event_frame(net_count_frame),
.count_event_kind(net_count_kind),
.count_event_reason(net_count_reason)
```

采集端必须分别检查两位，不能写成 `if(valid[0]) ... else if(valid[1]) ...`。两路同拍时，可以各自写入一个 FIFO，或使用明确支持一拍接收两条记录的缓存。跨到网络时钟域应使用适合事件流的异步 FIFO；现有 `status_cdc` 用于最新状态邮箱，不能保证保留每一次事件，不能直接替代事件 FIFO。

FIFO 深度、包格式、网络确认/重发策略由网络队员按链路预算确定。队列满时应有可观测溢出记录，不能静默丢失后仍声称逐号完整。事件没有上游反压，网络拥塞不能通过拉低 ready 暂停这套计数器。集成后要重新验证吞吐和 CDC，不可把本文接线当作已实现网络功能。

## 6. 统计包、显示包如何由单列改双列

`count_live[255:0]` 为 ROI1，`count_live[511:256]` 为 ROI2。`frame_record` 也按相同顺序拼接。每列内部 256 位定义如下，ROI2 解码时统一加偏移 256：

| 本列位段 | 字段 |
|---|---|
| [31:0] | source frame ID |
| [47:32] | 内部 run ID |
| [50:48] | 跟踪状态：0 READY、1 ACQUIRE（屏幕 LOCKING）、2 RUN、3 LOST、4 DONE、5 HOLD、6 CHECK |
| [54:51] | 跟踪原因码，非分类复核掩码 |
| [55] / [56] / [57] | 方向有效 / 向右 / 选择的区域 |
| [66:58] | TOTAL |
| [75:67] | PRESENT |
| [84:76] | EMPTY |
| [93:85] | REVIEW |
| [129:94] | 四个 9 位槽位信息，见下方限制 |
| [201:130] | 当前页八个空穴 ID，低位第一个，每个 9 位 |
| [210:202] / [212:211] / [216:213] | 最近一次 ID / kind / reason |
| [222:217] / [223] | 空穴页号（从0开始）/ 包标记 |
| [239:224] | 生产 RECORD_ONLY 模式下的显示轮次 visible_run |
| [255:240] | 生产 RECOVERABLE 模式下的 16 位诊断信息 |

旧早期文档写 [255:224] 保留为零，**不适用于当前生产 recorder 模式**。不要照旧文档丢掉当前的显示代际/诊断信息。

四个 9 位槽位按低位顺序对应 ROI1 槽0/1、ROI2 槽0/1。每个 bank 只使用本区那两个实际显示 ID；LOCAL_RECOVERY 的 raw 包可能借用非活动区槽位携带 uncertainty_from，顶层 `count_record_view.v` 在默认 REPORT_NUMBER_GAPS=0 时会屏蔽这些非活动区信息。因此网络逐号记录应使用事件，不能把 raw 槽位所有非0数都当成已编号器件。

COUNT_BITS 应从 256 变为 `256*(1+DUAL_REGION_COUNT)`。生产默认原检测/诊断部分 631 位，加 512 位计数扩展，共 1143 位；参数改变时必须按公式算，不要在其他模块硬写 1143。计数扩展位于 `frame_metadata[ORIGINAL_META_WIDTH +: COUNT_BITS]`。

原 DDR 槽位、源帧 epoch、迟到元数据绑定和 VS 快照仍需保留；显示帧标签用 frame_record，同期总数用 live_record，二者不能随意互换。两列 frame_record 只有两个 ready 都为真才作为完整帧计数包发布；逐号事件本身不要求两列同拍发生。

若上位机要实时看到 LOCKING、LOST、清零和每列汇总，仅接逐号事件不够，因为无新编号时也会变状态。应另采集两列状态快照、轮次/清零状态；最新状态可以用邮箱式 CDC，与必须逐条保存的编号事件分开处理。当前接口没有新增网络 clear/start 专用通知，网络端不要凭“长时间没收到事件”推断结束或归零。

## 7. 每个编号的状态到底有没有记录

有：`classified_pocket_counter.v` 正式 EMIT 时同时更新计数、写 `ledger[total] <= {recorded_kind,recorded_mask}`，并输出逐号事件。ledger 为 300×6 位，地址 0 对应 ID001；本轮有效范围为地址小于 total。空穴另维护 300 个 9 位 ID。双列各有一份计数器状态。

但是：`classified_count_pipeline.v` 当前把 ledger_address 接为 511，ledger_data 接 unused_ledger，未向顶层提供任意历史查询，综合可能裁掉未被使用的 ledger。**仿真里能检查内部 ledger，不代表现有 bit 可通过以太网补读历史 001～300。**

已有的是“编号提交时提供状态”的检测接口；持久化、断网缓存、上位机按号查询属于网络/记录系统。队员从启动前接收并保存事件，就能知道每个已收到编号的有件、空穴、有件复核状态。若需要中途接入后补齐历史，必须另做板端可查询存储/回放接口或持久数据库，本轮未实现。没有正式提交的候选、CHECK/uncertainty 区段也不能擅自推断为已确认编号。

## 8. 为什么还要带上 R25～R27B 修复

1. R24：双列隔离、双统计包、双路事件和双列 OSD。保持共享检测器，不是另造一套分类器。
2. R25：密集双列分析会超出源帧预算，增加保守稀疏扫描与队列读调度。保持阈值、坐标和正式分类答案，不放宽真实帧故障保护。
3. R26：SW3 开新段时关闭前一 epoch，只允许同拍或下一个源 FS 建立新轮；不接收上一段残留结果。表面比较做整数等价时序优化。
4. R27：空画面分析很快，search_new 可能早于完整帧证明；旧逻辑丢掉一次性脉冲，下一帧误报 C6。当前保存 pending，等同源帧证明后仅接收一次；FS、取消和坏帧会清掉 pending，不能跨帧借证明。
5. R27B：四槽高距离选择先在两列并行计算，再选 bank，平衡最大值比较；保持首个空槽、相等时最后槽和 prefix worst 语义，缩短实际关键路径，不增加检测周期。

所以不要只拷双列 wrapper 却保留旧单列 ISP 的结果脉冲/epoch 接收方式，也不要关掉 C6 来掩盖集成后的处理超时。

## 9. 推荐迁移顺序与验收

1. 解包正式完整工程，新建独立目录。先确认不带网络的 R27B 能按原方式准备和编译，再迁入队员网络代码。保留原器件、引脚、时钟和完整 SDC；原 bit 的通过结论不自动覆盖新网络构建。
2. 若采用差异合并，用配套九文件 patch 和 SHA 表逐项审查；先确认基线，处理已有网络修改冲突。同步所有参数和位宽，不只替换检测器。
3. 在 `u_isp_top` 接出两路事件；处理域先完成双路采集，再跨网络域。协议增加 ROI 字段，并按本列 run/id 保存，两个 valid 同拍必须保存两条。
4. 上位机按 kind/reason 分类，用独立快照显示 T/P/E/R 和运行状态；新段、清零、断网和重连必须有明确处理策略。
5. 跑与改动相关的双列计数、显示、完整帧/取消、SW3、事件双路并发回归；加网络 FIFO、CDC、拥塞及丢包可见性测试。
6. 完整综合/布线、双角 setup/hold 和全部 CDC/约束审计通过，再烧录联调。

现有项目内的基本双列测试入口（在项目根执行；ModelSim 和原厂库路径按本机配置）：

```powershell
./sim/run_modelsim.ps1 -OnlyTests two_region_count,two_region_ui,two_region_detector
python tools/check_two_region_ui.py sim
```

这只是集成冒烟入口，不代表完整 R27B 25 项验收。当前完整测试清单和实际日志身份见 `validation/r27/verification.json`，测试调度见 `sim/run_modelsim.ps1`。与集成尤其相关的已有目标还有 `restart_epoch`、`switch_recorder_controls`、`empty_result_proof`、`empty_native`、`frame_metadata`、`sparse_equivalence`；`empty_native` 为完整 RAW 链路测试，运行开销大于短回归。正式工程准备示例（目标目录须不存在）：

```powershell
python tools/prepare_dual_region_r27.py --work D:/FpgaWork/R27B_network_integration --td <实际TD安装的doc目录>
```

当前 R27B 已通过 25 项本版实际仿真、独立参考与 Routed Slow/Fast 审计：setup +0.101ns、hold +0.020ns、两项 TNS=0。Slice 18913/21216（89.14%），ERAM 101/108（93.52%），DSP29/40，PLL5/6。这些是纯检测计数交付的资源，网络集成后需要重新评估，不能当作网络版本的余量或验收。

现场联调验收表：

| 场景 | 应验收的结果 |
|---|---|
| 两列已知 P/E/复核序列同时运动 | 各自 001 起，按本列顺序；T=P+E，R仅包含有件复核；空穴 ID 与实物一致 |
| 两列同拍提交 | 下游两条都收到，ROI/run/id/kind/reason/frame 无串列 |
| 一列空缺或反向 | 不凭周期补号；局部异常不混用另一列运动状态，另一列仍按有效输入工作 |
| 静止/重复显示帧 | 不重复编号、不产生额外网络记录 |
| 空画面 SW3 重启 | 视频采集正常时等待/LOCKING，无结果先后次序引起的假 C6 |
| SW3 中途开新段/组合键清零 | 两列清晰分段，无旧帧结果混入，无旧 run/id 覆盖新记录 |
| 真实坏帧/配置取消/采集停止 | 保留故障保护，不能为保持计数而伪造确认事件 |
| FIFO拥塞、网络断开再恢复 | 无静默丢失；若要求历史补齐，要验证具体缓存/回放能力，不能以当前内部ledger作保证 |

原交付的实板验收仍是 HUMAN_PENDING；本文不声称已验证网络，也不声称所有现场 C6 原因均已消除。

## 10. 队员最少需要带走什么

完整 R27B 源码验证包、本文、`R23_to_R27B_production.patch` 和 `SOURCE_CHANGE_MANIFEST.json`。补丁用于审阅迁移，不替代完整工程/IP/测试/约束。从单列转接时最关键的是：**两列独立身份、512位统计包、双路同拍无反压事件、正确处理域，以及实时保存事件而不是读取屏幕或假定已有历史查询。**
