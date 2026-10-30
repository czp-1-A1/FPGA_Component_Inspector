# R27B 双列计数代码与交接发布

分支：`r27b-dual-roi-20261030-handoff`；固定标签：`r27b-dual-roi-20261030-release`。

[完整工程、交接说明、正式bit与校验文件](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/r27b-dual-roi-20261030-release)。

主附件：`R27B_DualColumn_Code_and_Handoff_20261030.zip`（125880308字节），解压一次即可查看完整工程和双列对接说明。
SHA256：`2a4dc51449708d797bcea40dc4b4c102e05042a2ce1836cde04d7d9b1cf3070c`。

先读[双列迁移说明](../../docs/DUAL_COLUMN_HANDOFF_R27B.md)，工程入口为 `fpga/component_inspector/td_project/camera_to_dsi_display.al`。换机器按项目内 `tools/prepare_dual_region_r27.py` 准备新的英文路径。

当前两列各自001～300编号、分别统计总数/有件/空穴/复核和空穴号。ISP提供两路逐号状态事件；顶层网络端口连接、同拍双路采集、跨域FIFO、传输和长期保存由以太网队员对接。当前没有任意历史编号查询接口。

25项本版实际测试、Routed双角与约束审计通过；setup +0.101ns、hold +0.020ns、两项TNS=0。680冻结输入保持，归档逐载荷SHA及fresh解包核验通过。本次上传不修改RTL、不重新生成bit；实板验收仍HUMAN_PENDING。网络集成后需要重新验证资源、CDC、事件吞吐和物理时序。

补丁以本机R23单列为基线；若队员使用R19或已有网络修改，需按交接说明合并，不能直接当同一基线应用。
