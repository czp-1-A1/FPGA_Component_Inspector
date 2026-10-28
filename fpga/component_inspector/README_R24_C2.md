# R24最终交付版的验证入口

两区功能、TD重新准备和仿真命令沿用`README_R24.md`，完整交接说明为仓库`docs/R24_HANDOFF.md`。本候选另外显式排除了计数器RECOVERABLE模式下已被前序分支处理的后备分支，删除无用组合路径；分类阈值、编号行为、事件周期和时钟约束保持不变。

实际执行的652个源/测试/工具输入由`C2_FROZEN_INPUTS.json`冻结。`R24_FROZEN_INPUTS.json`可另外包含验证结束后增加的验证工具和文档，但不得改变任何已执行输入。当前必须使用`tools/verify_dual_region_c2.py SOURCE BUILD`核验；旧`verify_dual_region_r24.py`仅针对初版。

验证范围为本候选实际执行的12项测试（含5组旧新逐周期比较及完整RAW），加7项所有实际编译文件和45个冻结运行数据完全相同的历史测试。7项的执行目录、日志和输入身份均在`validation/r24/unchanged_test_reuse.json`，不声称在本候选重跑。完整RAW、实际Routed双角时序及全部约束审计已通过：SWNS+0.002ns、HWNS+0.020ns，STNS/HTNS均0；Slice18460/21216、ERAM101/108、DSP28/40、PLL5/6。bit SHA256为0ce9f60635aa00f2318eb04403e604f166e92a6770606ed323bddc0549f29e20。物理实现为seed2完整构建再经原厂post-route reroute ultra、relocation high收敛，完整日志和DB保留。尚未实板验收。

以太网需要同时接收ISP的两路逐号事件，并自行完成跨时钟、缓存和历史保存；顶层尚未接网络模块。内部计数器ledger不构成最终bit的任意历史查询接口。
