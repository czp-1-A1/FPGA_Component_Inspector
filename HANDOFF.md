# 当前交付：R27B 双列计数（2026-10-30）

当前分支 `r27b-dual-roi-20261030-handoff`，固定发布标签 `r27b-dual-roi-20261030-release`。

- [完整代码、交接说明和正式 bit](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/r27b-dual-roi-20261030-release)
- [单列转双列的改动清单与以太网接口](docs/DUAL_COLUMN_HANDOFF_R27B.md)
- [构建、时序和烧录验收](R27_DELIVERY.md)
- [发布包与 SHA](releases/r27b_20261030/README.md)

工程目录 `fpga/component_inspector`，两列独立编号/统计。逐号事件已提供，网络实现由对接队员负责。25项本版仿真及Routed审计通过，实板验收待人工完成。以下原内容保留为历史版本说明。

---

# R24最新双列工程交接（2026-10-28）

当前交付版本为R24，基于R23提交6f2d91c。两个原有3528有效框同时检测，各自从001编号，独立总数/有件/空穴/复核/空穴号，提供ISP双路逐号事件供以太网队员接入。网络协议、跨域缓存和长期保存由队员实现。源码、测试及实际完整RAW/布线/约束审计已通过，实板尚未验收；现场掉帧和移动误复核仍待验证。

- 当前分支：`r24-dual-roi-20261028`；固定发布标签：`r24-dual-roi-20261028-release`。
- [完整工程、bit与校验文件](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/r24-dual-roi-20261028-release)。
- [双列功能、以太网接口与验证范围](docs/R24_HANDOFF.md)；[下载/准备/核验步骤](releases/r24_20261028/README.md)。
- 工程目录：`fpga/component_inspector`。重新准备ASCII路径后打开`td_project/camera_to_dsi_display.al`。654冻结源保持已验证字节；完整证据包放发布附件，旧版本保留。


---

以下为此前交接记录（当前版本以以上R24入口为准）。

# 当前R23接棒

先读[docs/R23_HANDOFF.md](docs/R23_HANDOFF.md)，再运行`python scripts/r23/verify_r23.py`。本版为动态有件被动诊断，未宣称修复误复核或R23实板通过。
