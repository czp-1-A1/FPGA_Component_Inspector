# ModelSim 仿真

主要仿真使用 ModelSim；Icarus 脚本保留作辅助验证。本机为 ModelSim SE-64 2019.2，工具目录 `D:/modelsim/win64`，安路库来自 `D:/AAA/FPGA.....YZW/sim_release`。

在 PowerShell 执行：

```powershell
./run_modelsim.ps1
```

也可以从仓库根目录执行 `./fpga/component_inspector/sim/run_modelsim.ps1`。参数 `-ModelSimBin`、`-TdSimRoot` 可指定另一台电脑的安装目录。脚本仅在当前进程缺少许可环境变量时继承已有的用户/系统配置，不更改许可配置、不打印许可内容。编译库、日志、波形都保存在本地 `modelsim_work/`，不修改工具安装目录。

每项测试使用独立库，避免按键测试的 I2C 替身影响实际总线测试。像素测试使用 TD 工程选中的根目录 AWB、真实除法器网表及原厂加密 ERAM 模型，带 `glbl` 和 `PH1P_PHY_GSR` 顶层。各测试记录顶层信号到 `wave.wlf`；脚本同时检查退出码、完整 PASS 标志及 Fatal/Error，避免 `$fatal` 后退出码为零误报通过。

2026-10-03 原工程结果：七项通过，像素接口测试失败。`signal_delay.v` 未连接 RAM B 口的 `web`，原厂模型读出全零。这个失败尚未修复，默认命令会明确失败。

下面的命令仅用于定位差异：

```powershell
./run_modelsim.ps1 -TieUnusedAwbRamInputs
```

它在测试台内强制 AWB RAM 的 `web=0`、`dib=0`，不更改 DUT 源码。诊断模式八项通过，但不能据此判原工程通过。原工程与诊断分别使用 `test_pixel_interface`、`test_pixel_interface_tied_inputs` 库，保留各自日志。完整证据见仓库 `开发实施/验收记录/20261003_ModelSim复核_轮次1.md`。

图形界面中，将工作目录设为本 `sim` 目录，运行 `do run.do` 查看原工程失败位置。先执行诊断命令后，可运行 `set awb_ram_diagnostic 1` 再 `do run.do` 查看诊断波形；返回原工程时设为 0。

本轮不生成新位流。后续经确认后，先显式连接未使用的 RAM 输入并重跑无强制覆盖的原厂模型测试，再实施检测专用帧对齐及完整性保护。
