# 冻结输入复现

不要运行旧日期的保存脚本，也不要向任何已冻结release输出。新建ASCII路径的空目录，将本证据的source_snapshot内容复制进去，保持user_source、td_project、sim的相对结构；按manifest核对198输入及.al哈希。

ModelSim使用SE-64 2019.2和TD6.2.168116的sim_release；sim/run_modelsim.ps1的默认命令运行12项测试，不能用诊断TieUnusedAwbRamInputs替代。工具路径不同可传ModelSimBin/TdSimRoot，许可采用当地已有配置。

TD复现时，在新的td_project/camera_to_dsi_display_Runs目录建立syn_1和phy_1，将本证据td下各阶段的settings.cfg、camera_to_dsi_display.prj、build.tcl复制到对应新目录。先在syn_1执行：

```powershell
& 'D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe' build.tcl
```

确认.opt_gate.end.f存在且没有error标记后，再在phy_1执行同一命令。参数是build.tcl本身，不加-f。保留两阶段新的stdout日志，确认.bitgen.end.f、最终bit、pr.timing及constraint_coverage.txt。不同机器/布局运行可能得到不同bit哈希或余量，应记录自己的结果；本证据身份以原manifest为准。

目录内Python脚本记录本轮编辑/隔离/冻结步骤，硬编码20261005目录且初始化脚本禁止覆盖已有目录；它们不是让接棒端重复改动当前工程的入口。现场下载使用release/roi_core_80_20261005中的已冻结bit。
