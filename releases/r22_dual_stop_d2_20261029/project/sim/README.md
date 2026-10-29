# ModelSim 仿真

主要仿真使用 ModelSim；Icarus 脚本保留作辅助验证。本机为 ModelSim SE-64 2019.2，工具目录 `D:/modelsim/win64`，安路库来自 `D:/AAA/FPGA.....YZW/sim_release`。

在 PowerShell 执行：

```powershell
./run_modelsim.ps1
```

也可以从仓库根目录执行 `./fpga/component_inspector/sim/run_modelsim.ps1`。参数 `-ModelSimBin`、`-TdSimRoot` 可指定另一台电脑的安装目录。脚本仅在当前进程缺少许可环境变量时继承已有的用户/系统配置，不更改许可配置、不打印许可内容。编译库、日志、波形都保存在本地 `modelsim_work/`，不修改工具安装目录。

每项测试使用独立库，避免按键测试的 I2C 替身影响实际总线测试。像素测试使用 TD 工程选中的根目录 AWB、真实除法器网表及原厂加密 ERAM 模型，带 `glbl` 和 `PH1P_PHY_GSR` 顶层。各测试记录顶层信号到 `wave.wlf`；脚本同时检查退出码、完整 PASS 标志及 Fatal/Error，避免 `$fatal` 后退出码为零误报通过。

2026-10-03 初次原工程结果：七项通过，像素接口测试失败。`signal_delay.v` 未连接 RAM B 口的 `web`，原厂模型读出全零。失败及诊断证据保存在 `20261003_ModelSim复核_轮次1`，不覆盖。

用户随后确认最小修复：当前 `signal_delay.v` 已显式连接 `web=0,dib=0`。当时默认命令的八项测试全部通过，没有启用强制覆盖。当前证据见仓库 `开发实施/验收记录/20261003_RAM只读端口修复_轮次1.md`。

下面的命令仅用于定位差异：

```powershell
./run_modelsim.ps1 -TieUnusedAwbRamInputs
```

它在测试台内强制 AWB RAM 的 `web=0`、`dib=0`，不更改 DUT 源码。诊断模式八项通过，但不能据此判原工程通过。原工程与诊断分别使用 `test_pixel_interface`、`test_pixel_interface_tied_inputs` 库，保留各自日志。完整证据见仓库 `开发实施/验收记录/20261003_ModelSim复核_轮次1.md`。

图形界面中，将工作目录设为本 `sim` 目录，运行 `do run.do` 查看当前默认测试波形。初次失败波形在历史证据目录。可选诊断入口保留供复现：先执行诊断命令后，运行 `set awb_ram_diagnostic 1` 再 `do run.do`；返回默认测试时设为 0。

2026-10-03新增roi_guard与roi_chain，当时默认共10项。ROI单元独立计算RGB参考，核对非4对齐边界、首末拍、异常拒绝和恢复；roi_chain执行真实RAW10 native→uial2axis→demosaic→AWB→打包/统计，共7帧1024×600，原厂RAM/GSR/真实除法网表，覆盖短行、长暂停、ready低、正常恢复。启动首帧因原demosaic学习行跨度产生回放超前而被拒绝，第二帧才有效；它不模拟物理MIPI、DDR和HDMI发送器。仅记录顶层信号以控制全帧仿真开销。

可只复测受改动影响的项目：

```powershell
./run_modelsim.ps1 -OnlyTests roi_guard,roi_chain
```

先执行该命令，再在ModelSim图形界面中 `do run_roi.do` 查看全帧波形。完整证据见 `开发实施/验收记录/20261003_ROI灰度统计_轮次1.md`。OSD测试生成的PPM与预览PNG为仿真布局，不是相机实物照片。


2026-10-04新增classifier，默认共11项。该测试使用非四像素对齐的16×8人工ROI，直接核对SUM=5120/10240/5335/7680、MEAN=40/80/41/60；测试两种极性、等值及0/255、框外/亮点干扰、暂停/短帧/配置/FS取消、未标定/重新启用/复位与恢复，并核对27位CSI→显示邮箱。最近调参统计在native FS后保留，分类必须等新样本。roi_chain在真实RAW/ISP统计参考之外验证人工T=110（不写入交付阈值）的PRESENT/EMPTY/WAIT。OSD验证UNCAL/WAIT/PRESENT/EMPTY字样和VS快照。

受影响测试：`./run_modelsim.ps1 -OnlyTests osd,roi_guard,classifier,roi_chain`。需要单独查看人工测试波形时，先运行脚本，再在ModelSim中加载`test_classifier.tb_classifier`；WLF位于modelsim_work/classifier/wave.wlf。此批不使用强制覆盖。交付版CLASS_CALIBRATED=0，单穴ROI、阈值、方向和光学条件仍待现场标定。完整说明见仓库开发实施/16_A均值判定与离线验证_实施说明.md。

2026-10-05新增roi_core，该批默认共12项。生产统计改为[472,552)×[260,340)的6400像素，大观测框保持512×256。roi_core独立参考验证SUM/MEAN/MIN/MAX、框外全黑/全白不影响小框、255满量程和气泡；roi_chain仍用真实7帧RAW/ISP，独立参考改为6400像素。OSD逐像素验证80×80青框、大框灰度、框外彩色、CYAN说明、同步及ENABLE=0两级旁路。受影响测试可运行`./run_modelsim.ps1 -OnlyTests osd,roi_core,roi_chain`，全部回归使用默认命令。完整实现说明见仓库开发实施/18_A单穴80x80取样_实施说明.md；实际阈值仍未标定。


2026-10-05取样界面批次：当前默认14项，新增display_state及stop_recovery。保留原12项；roi_chain另外检查真实ISP的完整记录发布/异常撤销。display_state使用真实28位邮箱和classifier，不依赖强制覆盖，验证正常FS保持、atomic记录、无效/配置/配方/停流/恢复和旧内容。stop_recovery直接停CSI时钟、保留独立50MHz监测和HDMI时钟，将1秒窗口缩为1000参考拍，测试两端停流相位及恢复新采样要求。定向命令：

```powershell
./run_modelsim.ps1 -OnlyTests display_state,stop_recovery,osd,roi_chain
```

OSD为三拍延迟；完整1024×600及六种1024×96状态条逐像素与独立Python布局参考比对，检查字体/Logo、双框/灰度/框外彩色、状态优先级和整帧快照；参数检查65535和前导空白。输出osd.ppm与osd_state_0..5.ppm。它们是仿真图，不是实物画面。辅助Icarus入口已接入小ROM，但本轮主要验收仍用ModelSim。

字模和Logo生成脚本generate_osd_assets.py依赖Pillow、本机微软雅黑/Consolas和原Lab3 Logo（输入SHA在osd_assets/manifest.json）。生成33个中文字和32个ASCII，无完整字库。生成的3个Verilog ROM已是综合输入，不需要在别台电脑重新装字体或运行生成器。要复刻原素材请核对输入SHA；布局参考由render_osd_reference.py生成，需在运行OSD测试前保留osd_assets/reference.hex和state_0..5.hex。生成脚本也会写experiment_osd.v，仅在有意再生成时运行。
