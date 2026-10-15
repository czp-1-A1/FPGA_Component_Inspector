# V11 本机续接验证（2026-10-15，轮次9）

结论：软件及最终双角路由时序通过，物理视频与220mm识别配方待用户现场验证。

## 基线与修改

原跨机包声明分支lj4747-contest-work、基线da195838d8a1df052edeaa86f60312d32eeedf9a/V10；包不含.git，本机未创建或伪称检出该分支，未提交/推送。其他旧Git仓库分支不同且有既有改动，未切换、清理或覆盖。

原包586项SHA全部通过。原冻结341项加独立字体参考1项共342项，冻结清单SHA为85756e59128f068ae62876b59837a7c67635430eac23d8bd802ac3920e8237eb。

r9冻结输入342项（生产文件222项，含RTL/IP/约束等），清单SHA为9e271eb2588dbfb10a6b73b6a1e9d7325542e83bd46f22ec214fd19ef043f268。源清单绑定r9/source_snapshot，实际执行副本为r9/fpga/component_inspector；开发副本同源校验通过。

唯一生产RTL变化：roi_frame_guard的Y_BITS默认值最小10位，保留小帧旧接口；1080行仍为11位，覆盖1024..1079。COUNT_BITS仍按总像素数。无流水延迟、跨域接口、阈值、算法或测试期望变更；小帧增加的寄存器高位由工具优化，生产仍同位宽。资源差异含TD版本/映射变化，不能宣称此修改优化了生产资源。

## 固定目标与工具

1920×1080全视野RAW10→真实ISP→双线性2/3→1280×720双目标/四模式→720p60逐行输出。保留V10先发布完整视频、同帧同槽迟到补全、VS原子快照及WB取消结果后视频继续更新。220mm配方不以比例推定通过。

本机TD6.2.178840、ModelSim10.5、Python3.12.14/NumPy2.3.5；原机TD168116/ModelSim2019.2。验证输入冻结后未改RTL/测试，未靠修改期望消除失败。无实物操作、JTAG或Flash。

## 失败与复测

| 轮次/项目 | 结果 | 证据及处理 |
|---|---|---|
| 原r8小帧roi_guard复现 | FAIL保留 | r8_repro/sim/modelsim_work/roi_guard：输出2位接旧10位，ROI case1 valid0/count0 |
| r9兼容复测 | PASS | r9/compat_smoke：原roi_guard与FHD hd_guard两项，未改测试 |
| 原跨机TD脚本本机执行 | FAIL保留 | r9/syn_1/replay_build.log：doc/scripts/DefaultFlow.tcl本机不存在；独立入口选本机scripts路径，保留冻结build.tcl |
| 原独立参考解析器本机执行 | FAIL保留 | reference_portability_failure.json：PowerShell5.1日志UTF16，旧解析器强制UTF8导致No records；仅改BOM编码读取，参考算法/期望不变 |
| 本机修复跨机脚本实际复跑 | PASS | portable_prepare_check逐项解析342文件及内部依赖；参考实际18图通过；完整syn/phy通过 |
| 约束摘要初版解析器 | 诊断失败后修正 | TD178840将6条物理别名约束打印为无数字续行；现继承相同路径组计数，仍严格要求38显式+2厂商=40，未降低目标 |

## 最终冻结仿真

全局运行器退出码0，原厂ERAM模型，未强制AWB RAM未用端口。完整28项最终总PASS。

| 测试 | 结果 | 原始证据 |
|---|---|---|
| process_bridge | PASS | evidence/r9/sim/modelsim_work/process_bridge/console.log、compile.log、transcript.log |
| frame_search | PASS | evidence/r9/sim/modelsim_work/frame_search/console.log、compile.log、transcript.log |
| frame_osd | PASS | evidence/r9/sim/modelsim_work/frame_osd/console.log、compile.log、transcript.log |
| shape_snapshot | PASS | evidence/r9/sim/modelsim_work/shape_snapshot/console.log、compile.log、transcript.log |
| shape_model | PASS | evidence/r9/sim/modelsim_work/shape_model/console.log、compile.log、transcript.log |
| frame_tailproof | PASS | evidence/r9/sim/modelsim_work/frame_tailproof/console.log、compile.log、transcript.log |
| frame_stop | PASS | evidence/r9/sim/modelsim_work/frame_stop/console.log、compile.log、transcript.log |
| frame_process | PASS | evidence/r9/sim/modelsim_work/frame_process/console.log、compile.log、transcript.log |
| shape_osd | PASS | evidence/r9/sim/modelsim_work/shape_osd/console.log、compile.log、transcript.log |
| video_fallback_display | PASS | evidence/r9/sim/modelsim_work/video_fallback_display/console.log、compile.log、transcript.log |
| frame_wait_metadata | PASS | evidence/r9/sim/modelsim_work/frame_wait_metadata/console.log、compile.log、transcript.log |
| video_metadata_fallback | PASS | evidence/r9/sim/modelsim_work/video_metadata_fallback/console.log、compile.log、transcript.log |
| writer_epoch | PASS | evidence/r9/sim/modelsim_work/writer_epoch/console.log、compile.log、transcript.log |
| wb_epoch | PASS | evidence/r9/sim/modelsim_work/wb_epoch/console.log、compile.log、transcript.log |
| observation | PASS | evidence/r9/sim/modelsim_work/observation/console.log、compile.log、transcript.log |
| display_state | PASS | evidence/r9/sim/modelsim_work/display_state/console.log、compile.log、transcript.log |
| roi_guard | PASS | evidence/r9/sim/modelsim_work/roi_guard/console.log、compile.log、transcript.log |
| video_first | PASS | evidence/r9/sim/modelsim_work/video_first/console.log、compile.log、transcript.log |
| video_late_display | PASS | evidence/r9/sim/modelsim_work/video_late_display/console.log、compile.log、transcript.log |
| frame_cadence | PASS | evidence/r9/sim/modelsim_work/frame_cadence/console.log、compile.log、transcript.log |
| hd_resize | PASS | evidence/r9/sim/modelsim_work/hd_resize/console.log、compile.log、transcript.log |
| hd_guard | PASS | evidence/r9/sim/modelsim_work/hd_guard/console.log、compile.log、transcript.log |
| hd_scaled_guard | PASS | evidence/r9/sim/modelsim_work/hd_scaled_guard/console.log、compile.log、transcript.log |
| hd_osd | PASS | evidence/r9/sim/modelsim_work/hd_osd/console.log、compile.log、transcript.log |
| hd_search | PASS | evidence/r9/sim/modelsim_work/hd_search/console.log、compile.log、transcript.log |
| hd_chain | PASS | evidence/r9/sim/modelsim_work/hd_chain/console.log、compile.log、transcript.log |
| hd_pins | PASS | evidence/r9/sim/modelsim_work/hd_pins/console.log、compile.log、transcript.log |
| hd_pll | PASS | evidence/r9/sim/modelsim_work/hd_pll/console.log、compile.log、transcript.log |

HD完整链路为7帧真实RAW10/行间停钟/异步100MHz处理，固定30FPS源起点；四模式、WB取消零结果活视频、亮背景和同槽迟到元组全部通过。10个完整显示栅格、9790262像素独立DDR对照，OF=UF=0。独立两遍连通参考核对13幅HD搜索图及5幅实际处理图，共18图，双方框/分类/原因/排序/主字段全部匹配。真实厂商PLL74.25/371.25MHz/5:1通过；理想PLL隔离的两帧引脚数字仿真1843200像素/1440行通过，不能代替实板信号完整性。

将实际hd_osd.ppm无缩放转换为1280×720 PNG并目视：顶部完整字模、右下双框/类别/原因、底栏均在画面内。该图是OSD夹具，底栏IN1024×600/FPS27等由测试注入，不是实际V11相机测量；实板输入几何/FPS待现场记录。图像原始PPM和PNG均随证据保存。

## 综合、路由与约束

syn/phy均退出0。最终Routed/Both(Slow and Fast)：SWNS+0.117ns、HWNS+0.020ns、STNS/HTNS0；工具覆盖率92.89%。Slice14724/21216=69.40%，ERAM94/108、DSP26/40、PLL5/6。

SDC与r8逐字节相同。38显式加2厂商max-delay命令全部匹配非零路径，ignored0（本机有6条物理别名续行归组）。20个Gray位逐位绑定get_regs及真实逻辑net/物理cell，8ns对20路径全部主导、shadowed0、ignored0；最大数据延迟1.099ns，全部正slack。逐位报告、完整例外、时钟分析与check_timing随包保存。

不是零告警。保留历史DDR PLL元数据7项、I/O未延迟39/63及partial input1、相机时钟反馈混合fanout等。新USR6001仅在初始start_timer/IP约束导入前出现（syn12/phy6），最终时钟具备、no-clock/invalid-constraint等0、全部40约束有路径；不能当作最终漏约束。详细对比见constraint_audit.md及verification.json。

## 镜像与交付门槛

本机最终bit：1789539字节，SHA256 `1c94e3b20ee0bbec708385b8b3254239ae20abfe2fb01a35da387854050a2e4d`。交付脚本在全部上述门槛通过后才打包，逐文件核对ZIP载荷，再核对桌面副本SHA；路径/ZIP哈希/文件数以delivery_receipt.json和桌面交付回执为准。保留旧V10bit SHA e9542e0612e7491e5ff7305cc263a3898c4d8eef32320a126e7c3dc189470cef及原r8包，不覆盖旧镜像。

用户现场下一步：按烧录说明先SRAM下载此冻结候选，核对DC FRAME EXP V11、全视野/焦点/720p60逐行、四模式/框位置、曝光增益WB、冷启动和停CSI恢复；分别记录视频通过与220mm配方通过。当前实物未测、校准未通过、没有将有件当作已标定正常。用户管理板卡，助手未改变设备、网卡、用户GUI、JTAG或Flash。
