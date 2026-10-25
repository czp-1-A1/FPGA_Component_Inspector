# P02 完整交接：供其他工程和 AI 沿用

> 本页固定记录P02及其标签。当前分支已增加P03侧立复核候选，最新入口见[P03_HANDOFF.md](P03_HANDOFF.md)，P03增量见[P03_PORTING.md](P03_PORTING.md)。P02实物反馈不外推到P03。

当前分支`lj4747-contest-work`采用P02有件/复核优化，用户在交付后反馈“测试正常”。基线为R13提交`06f2b2e44a02e571edc33e7fb24018f5f1b50cb9`；功能提交为 **`b549237f15aafd3e3979b53f9df88b6877651e27`**。原R13发布和冻结标签保留。逐文件修改及跨分支集成先读 [P02_PORTING.md](P02_PORTING.md)。

## 1. 哪一份是本轮成果

- 当前源：`fpga/component_inspector/`，504项冻结输入，以`P02_FROZEN_INPUTS.json`为准；100项实际编译/IP/约束依赖见`P02_DESIGN_INPUTS.json`。
- bit：[P02_PresentSurface_1092_40_r0_20261024_dfd2e5c8.bit](../releases/p02_20261024/P02_PresentSurface_1092_40_r0_20261024_dfd2e5c8.bit)，1789539字节，SHA256 `dfd2e5c8f7081f32f526be0b9e02e754649f1509d872e7cd12aac4ffba9199b8`。
- GitHub发布标签：`p02-present-surface-20261024`；[发布与完整工程包](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/p02-present-surface-20261024)。公开工程包85106059字节/1245项，SHA `cf36dc1e157821609fb12d917005326b66ee3bbee87ec1ea698472e5ae3ee78e`。
- [实际验证资料](../releases/p02_20261024/README.md)、[源差分与功能提交](../releases/p02_20261024/INTEGRATION.json)、[用户总体测试反馈](../releases/p02_20261024/FIELD_FEEDBACK.json)。
- 本机交付bit仍放`D:/fpga_download/`。公开工程包与原本机full.zip有不同的归档SHA：原始实物拍摄及其个人来源路径留在本机，公开包保留相同bit/504源、合成测试输入/光栅、日志、实际路由/约束证据和回退资料。

504冻结源中的历史README、P01指南、原交付收据及旧`current_*.json`是当时快照，可能写未上板、未上传或旧CAL语义。当前版本身份、用户反馈及发布状态以本页、FIELD_FEEDBACK、INTEGRATION和后续GITHUB_UPLOAD_RECEIPT为准。TD/ModelSim安装、厂商仿真库、有效许可证、板卡和运行进程不随Git传输。

## 2. 为什么改、实现了什么

停稳正常正面也全部复核。本轮P01真实读屏中，正常和背面均C8，说明两者的T100尺寸、比例、填充通过，均被外侧暗参考拦住；直接清原因位8会放过背面。内部目标绑定均值则有分离：正常四周最低/中心86.22%，背面74.49–74.79%，背侧72%。

P02新增内部表面证明：完整本帧缓存、32×32内窗可用、中心达到原前景阈值，且`5*min(L5,R5,T5,B5) >= 4*C5`。5表示逐2×2原生灰度截到5位再求均值；不是把拍屏亮度或显示的8位均值直接代入。T100有件reason[3]改为内部表面/完整性失败，原尺寸/比例/填充低3位保留，弱T80仍F复核，空穴/定位孔路径保留。

分类缓存覆盖完整双ROI及16px上下文，处理全部8个真实计数候选。独立P01只读诊断继续显示当前首有效目标的原因、来源、内部8位均值和原暗格；其中央小缓存限制只影响读数显示。原计数、源帧/槽位绑定、四种视图、按键、视频、字体/Logo、原测试/gold及完整SDC保持。

## 3. 数据链和关键契约

SC500 RAW10 1920×1080/PPC4，经原白平衡/去马赛克、2/3缩放至1280×720，100MHz处理域，HDMI720p60。传感器源FPS约26/27，不以HDMI刷新率代替。

默认上ROI为x[400,880)、y[240,400)，下ROI为x[400,880)、y[432,600)。每ROI显示2个目标，计数保留最多4个真实候选。76位对象编码、304位显示对象、608位计数候选和887位总元数据宽不变；`TOTAL=PRESENT+EMPTY`，REVIEW是PRESENT子集，最多300穴。F/GAP之后的编号语义仍按R13记录器契约。

原CAL的128位内容改为两个64位PRB记录，总元数据[629:502]；[630]仍为有效标记，计数[886:631]保持。发布等待分类/计数/只读探针完成，并使用原源epoch与DDR槽绑定。完整PRB位域和reason兼容变化见迁移说明；旧CAL固定空间均值解析器需同步修改。

当前SURFACE_ACTIVE依赖SURFACE_REVIEW、REVIEW_PROBE和REGIONS同时启用。若接收工程隐藏诊断界面或改ROI/PPC，需要保持分类灰度采集及完整性证明；新版本应重新冻结和验证。移植采用具名参数传递，核对新增参数对旧位置参数实例化的影响。

## 4. 其他电脑先校验，再复原

在仓库根目录使用Python3运行：

```powershell
python scripts/p02/verify_p02.py
python scripts/p02/prepare_p02.py --work D:/FpgaWork/P02_replay --td D:/AAA/FPGA.....YZW/doc
```

第一条只校验当前Git源、bit、30组软件证据、真实Routed时序/全部CDC约束及反馈身份。可加`--archive <下载的_github.zip>`检查完整包所有CRC/SHA/安全唯一路径及包内504源。

第二条只新建英文短路径工程，复制504源、重定位GUI/运行描述符、核对100依赖并固定seed2，不自动综合、仿真或烧录。目标目录必须不存在。`--td`指向包含`scripts/DefaultFlow.tcl`的目录：本机TD安装的该目录位于TD/doc，而不是安装根。原通用准备工具默认seed1，直接使用会偏离本版验收设置，采用本页封装入口。

## 5. 完整构建与物理验收

实际本机工具为TD **6.2.168116**、ModelSim SE64 **2019.2**，厂商仿真库`TD/sim_release`。从新工程依次在`td_project/camera_to_dsi_display_Runs/syn_1`、`phy_1`目录调用TD的`td_commands_prompt.exe build.tcl`。cwd必须是对应运行目录，原错误cwd失败已保留在验证包。

PHY完成后回新工程根目录：

```powershell
& D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe tools/classified_audit_routed.tcl
python tools/verify_classified_physical.py .
```

只以实际Routed、Slow/Fast双角、非负setup/hold、TNS0和完整约束审计判通过。当前bit的最终结果：Slice18266/21216（86.10%）、ERAM103/108（剩5块）、DSP28/40、PLL5/6；setup+0.005ns、hold+0.020ns，双角TNS0。44显式+2继承共46条max-delay匹配/Ignored0，20Gray位主导8ns/扇出、6邮箱/SW3及coverage全部通过。

保持原SDC SHA `4a248232348e0f5338472dab5a8c275f1edb100354049be7df62ef1d88972a51`和seed2。原R13来自另一个TD版本，不能把跨工具面积差当算法收益。不同电脑或新移植版本重新构建时必须重新验收，不能继承本bit的时序结论。

## 6. 软件验证及复跑入口

已通过：新模块26请求/105个5位均值精确对照；8完整RGB帧、64记录、280参考均值、36个预期质量位变化，关闭新参数2506968拍记录/探针/ready与P01一致；启用P02的70帧计数序列（140观测、4次跨线含空穴、暂停/独立CSI停钟）；7帧合成RAW真实模块链（WB取消、60个诊断均值、120个5位参考均值用于24个判据、12538000像素/13完整光栅、OF0/UF0）；原24项相关回归；P02/原默认界面各4幅720p、3686400像素零差异。

原72项未全部重跑。新模块0warning，新RGB36、新计数24、原生链245条继承端口/厂商warning保留，均0error；完整包保存失败和复测，未改原gold或放宽目标。合成RAW经过实际模块的仿真不等于手机视频原始输入重放。

新工程中运行原生链/界面：

```powershell
./sim/run_surface_tests.ps1 -OnlyTests surface_raw_chain
./sim/run_surface_tests.ps1 -OnlyTests surface_ui
python sim/surface/verify_surface_ui_pixels.py
```

独立单测、RGB和启用新判据计数的测试台为`sim/surface/tb_present_surface_check.sv`、`tb_surface_detector.sv`、`tb_surface_counting.v`。在该目录创建独立ModelSim库：先用普通`vlog`编译当前present_surface_check、present_review_probe、empty_candidate_probe、inspection_region_config、frame_shape_search、classified_count_pipeline、classified_pocket_counter及本目录frame_shape_search_p01；再用`vlog -sv`编译这三个测试台，逐个`vsim -c work.<tb名> -onfinish exit`运行至各自PASS。旧RTL不可统一强制-sv，计数器使用了旧Verilog合法标识符。

原24项名单为regions、pose180、field180、cal180_holes、classified_counter、classified_controls、classified_pages、classified_image、classified_page、classified_observed_page、classified_empty_guard、classified_empty_leading、empty_candidate_probe、hold_recovery、local_recovery、local_stream、local_capacity、local_missing、local_ambiguity、tail_recovery、ordered_handoff、compact_ui、line_ram_equivalence、hd_pins；入口`sim/run_modelsim.ps1 -OnlyTests <字符串数组>`。每个验证副本独立运行，保持冻结源，避免边测边改。

完整包附六幅postRGB PGM与两套各四幅UI HEX，可用`tools/verify_surface_native_rasters.py`独立重算24个质量位/60个8位诊断均值。原默认UI参考脚本和输入也随包保留。源内P01/P02软件汇总脚本记录了原验证目录，其绝对路径属于当时运行环境；跨电脑优先用仓库级verify_p02检查归档，再在自己的新工程复跑测试，不把原绝对路径日志当新结果。

## 7. 上板操作及边界

SW4上检测/下计数；SW3先上再下开新段；K3+K4长按1秒清RUN、所有数量、空号、首错和GAP。详细仍遵循R13计数/恢复契约，当前工程不控制电机。

本轮验证条件为同型号3528、约180mm成像、EXP1092、GAIN40、MODE0、WB100/100L。用户按正常、背面、短侧、长侧、背侧提供P01真值，在收到P02后总体反馈“测试正常”；未提供新的逐速度、逐光照、逐姿态统计或板上回读SHA。后续移植需保存自己的实物真值，确认正常放行、异常复核、ROI内移动及与计数的结合。

## 8. 回退与发布状态

原R13位于`r13-compact-resource-20261023`标签和`releases/r13_20261023/`。其verify_r13.py针对历史R13源，当前P02工作树不应通过R13源SHA校验；可在该标签的新checkout运行原校验。P01/R13回退bit在公开工程包rollback/，本机D:/fpga_download也保留。

本分支通过普通提交推送发布，未强推、未合并其他队员分支。功能提交为建议移植单元；发布说明/校验器和上传回执另有后续提交。最终远端提交、标签与Release资产核对结果见`releases/p02_20261024/GITHUB_UPLOAD_RECEIPT.json`，它不自引用自己的提交SHA。
