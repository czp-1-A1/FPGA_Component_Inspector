# R24最终交付版检查点（2026-10-28）

用户要求在最新R23上改两列同时检测。当前采用本目录C2实现作为R24最终版本，工程在fpga/component_inspector；原R23、R24初版以及旧R20/R21/R22保留。本轮不提交/推送、无上板、未操作用户TD GUI、无子代理、无以太网实现。

两原有3528有效区各自001编号，独立总数/有件/空穴/复核/空穴号、运动/恢复状态。SW3开段/清零共用。原灰度/Sobel分类、阈值、区域配方和SDC不变。ISP输出两路逐号事件供网络队员接收、跨域和保存；顶层未连接以太网，内部ledger不构成最终bit任意历史查询接口。每区为本段相对编号001..300。

实际执行652输入C2_FROZEN_INPUTS.json SHA d726f624132ea610b5d2010648f50f765dbc3b151e26de44ffce88ee23f19e9e；最终R24_FROZEN_INPUTS.json共654，只另加专用验收器/README，SHA af9915f0910895ef0dc427e4d01b350323bc190e8db3b26a762b2124935123c1。所有652执行输入逐项未改。236生产输入8份RTL改动/228不变，差异和源身份见validation/r24。

软件12项本候选实际执行（含5个旧新计数器逐周期比较和完整RAW）+7项每个实际编译/45运行输入相同的历史测试复用均通过。不得声称7项重新跑过或有限miter是完整形式化证明。完整C2 RAW于12:20:54过：12 native源帧/11结果/1晚WB取消，两列各P/E/E/P的001..004事件在源5/7/8/9，最终各T4/P2/E2/R0；24完整显示栅格+部分22940160精确RGB像素，OF0/UF0，重复显示无多计；独立844800实际像素/全部8事件通过。

最终实际build为D:/FpgaWork/dual_roi_r24_c2_verify_20261028/fpga/component_inspector。TD6.2.168116、speed3、seed2完整综合/布局/路由后，原厂post-route reroute ultra及relocation high+自动reroute收敛。strict finalizer重新导出bit，Routed双角SWNS+.002/HWNS+.020、STNS/HTNS0；46maxdelay无忽略、20实际Gray Q路径、6邮箱/SW3/覆盖数值审计全过。最终Slice18460(87.01%)、ERAM101、DSP28、PLL5。无频率/相位/SDC修改。时序余量较小，必须实板确认现场表现。

最终bit R24_DualROI_20261028_0ce9f606.bit SHA256 0ce9f60635aa00f2318eb04403e604f166e92a6770606ed323bddc0549f29e20。源码专用验证器tools/verify_dual_region_c2.py已对654源、12新+7复用日志/独立参考及真实物理审计通过。旧verify_dual_region_r24.py只针对初版，不作当前验收器。

原R24初版14软件/RAW过但seed2/reroute/seed3全部负时序，拒绝交付；C1只有短测试，不采用。C2 seed2原失败DB/报告和优化前快照保留。C2 seed3在主候选全部审计通过后停止（owned CLI PID69572，父命令明确c2_seed3_physical_console.log）；未完成、不认定通过或失败。无任务后台工作需要继续。所有失败/未选实验见validation/r24/failures、alternatives及原目录。

打包工具D:/FpgaWork/package_r24.py、独立复原工具D:/FpgaWork/verify_r24_restore.py绑定当前654源和实际build。发布状态以releases/r24_20261028/RELEASE.json、PACKAGE_VERIFICATION.json、SHA256.txt为准。只有CRC/全部载荷SHA/源与已执行输入身份/软件及物理证据/独立RAW和UI参考/fresh TD准备全部过后，才复制独特命名bit/zip到D:/fpga_download。复原不声称又跑一整轮综合布线，也不代表上板。后续改动必须新冻结/新验证，不复用已改变输入的旧通过结果。

现场移动有件误复核仍是原R23未解决问题；有限合成RAW OF0UF0不能称现场掉帧已修复。完整功能、以太网事件接口与复现说明见docs/R24_HANDOFF.md及验收记录。

## 发布完成

独立归档复原已通过，1560载荷全部CRC/SHA、654源、12本版测试+7身份复用证据、真实布线/约束证据、844800 RAW像素/28416 UI标签像素与fresh 102项TD依赖准备均核验通过。最终bit及源码证据zip已复制D:/fpga_download，SHA与PACKAGE_VERIFICATION.json一致。zip SHA256 2f5f7ce1a620071019013b22e8926b6ec2a7dabee440e4596800f857580b40c4。归档中AGENTS为打包时检查点，此段为发布后更新；冻结源与归档未改。无后台本任务进程，无实板验收。
