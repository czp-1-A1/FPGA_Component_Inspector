# R57 双列同时检测与小字体修复（待实板验收）

基于 R56 提交 `fd794186da46b5914bb6faed817fc1d2da0e903b`，本版修复两列及补件区同时有密集目标时检测超时、整帧无框，以及第二列中文被裁切的问题。

- 检测器按同一内存字内四邻域相连像素合并处理。九组密集场景的候选、分类、坐标与原 R56 一致；最慢耗时由 2.09294 ms 降至 0.99050 ms。完整 1920×1080 RAW 双列测试在证明后 1.04221 ms 接收同帧结果；同夹具原 R56 第二帧到期无结果。
- 精简界面采用 16×16 中文和原 8×16 ASCII，重排双列统计及标签，第二列七字的 112 行完整显示。屏幕版本为 **INSPECT D3 R57**。
- 本版 21 项实际 RTL 测试通过，独立比对 540672 个文字区 RGB 像素；最终 Routed setup +0.048 ns、hold +0.020 ns，双 TNS 为 0。严格约束、CDC、四键、停车和报警审核通过。
- 最终资源：Slice 18135/21216（85.48%）、ERAM 101/108（93.52%）、DSP 31/40、PLL 5/6。

## 下载与源码

- [R57 发布页](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/r57-dense-dual-small-ui-20261102-release)：bit、完整工程与验证包、说明、校验表、验证回执和实际 RTL 界面预览，共 6 个附件。
- [源码分支](https://github.com/czp-1-A1/FPGA_Component_Inspector/tree/r57-dense-dual-small-ui-20261102)；生产工程为 `fpga/component_inspector/`，TD 入口为其中的 `td_project/camera_to_dsi_display.al`。
- 冻结交付快照为 `releases/r57_dense_dual_20261102/`，包含完整 `project/`、脚本、夹具、日志、综合网表和物理审核报告。移机与重建命令见其中的 `README.md`，命令从该目录运行。

bit：`R57_DenseDual_SmallUI_20261102_796c5216.bit`  
SHA-256：`796c5216dae90fe10cd74d9f798104a818644bbfd54ca6b2f29fb585b900d020`

完整工程包：`R57_DenseDual_SmallUI_20261102_796c5216_source_and_evidence.zip`  
SHA-256：`d019a3d7bf3111634f658862a4e5c70a8af5f685902678185dd4e0ad6ed81c49`

## 改动范围与验收

生产代码仅改 `user_source/hdl_source/frame_shape_search.v`、`compact_inspector_osd.v` 和 `compact_template_rom.v`；其余 701 个冻结输入与 R56 原字节一致。完整差异见交付快照中的 `R56_to_R57.patch`。两列独立编号、总数、空穴号、复核记录及原按键、停车、报警规则保留。

实板验收仍为 **HUMAN_PENDING**。烧录后确认 **INSPECT D3 R57**，先单列，再让两列及补件区同时出现目标，核对识别框、各自从 001 编号、各自总数/空穴号/复核和底部文字；随后验证 K1～K4、第五空穴报警和共用电机停机。

本版使用独立分支和新标签发布，未合并到 main，R56 交付保留。冻结 ZIP 保持上次本地交付原字节；其中 `github_uploaded=false` 及“未自动上传”描述是打包时状态，当前发布状态以本发布页为准。仿真与物理审核通过不代表实板光学或停车精度已经验收。
