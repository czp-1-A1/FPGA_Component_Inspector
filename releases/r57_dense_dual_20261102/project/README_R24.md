# R24：两个有效区独立计数

生产顶层默认同时处理两个原有3528有效区；两区分别从001编号，独立统计总数/有件/空穴/复核及空穴号。总数=有件+空穴，复核是有件子集。保留R23分类与检测页诊断，计数页同时显示两区统计和四目标编号。完整接口/范围见仓库docs/R24_HANDOFF.md。

重新准备全英文工程（目标目录必须不存在；TD目录下须含scripts/DefaultFlow.tcl）：

```powershell
python tools/prepare_dual_region_r24.py --work D:/FpgaWork/R24_replay --td D:/AAA/FPGA.....YZW/doc
```

复原目录TD入口为`td_project/camera_to_dsi_display.al`。先运行syn_1/build.tcl，再运行phy_1/build.tcl，沿用完整SDC、器件speed3和seed2。仅在源/完整路由时序/约束审计通过后才能交付bit；`tools/finalize_dual_region_r24.tcl`须在保存路由前快照后、从项目根执行。此脚本沿用厂商post-route优化，任何时序未满足都会拒绝交付；不能改SDC放宽要求。

```powershell
./sim/run_modelsim.ps1 -OnlyTests two_region_count,two_region_ui,two_region_detector
python tools/check_two_region_ui.py sim
./sim/run_modelsim.ps1 -OnlyTests two_region_raw
python tools/check_two_region_raw.py .
```

仿真默认使用本机ModelSim和原厂ERAM库，可用脚本参数指定安装位置。旧单区模块实例默认兼容；测试内部路径在single_region生成域，原金标/分类阈值不变。R23检测器诊断回归会自动准备输出目录。

源文件以R24_FROZEN_INPUTS.json逐SHA冻结。验证状态、通过项及bit身份以validation/r24/verification.json与release回执为准。仿真/布局布线均不代表实板验收。以太网队员可接收ISP双路逐号状态事件，网络发送/长期保存仍由对方实现。
