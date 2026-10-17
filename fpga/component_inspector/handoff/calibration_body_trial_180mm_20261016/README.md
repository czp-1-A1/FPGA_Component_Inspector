# 180mm白色3528有件尺寸下限候选

用户已离开板卡，不能补拍；本轮继续离线修正已有证据支持的部分。此包是**有件下限候选，空穴/定位孔及整套180mm标定尚未完成**。保留CAL32/631位记录及全部帧保护，未提前关闭辅助，不替换正式发布指针。

候选：candidate/V12_CAL180_body_trial_1092_40_20261016.bit，1789539字节，SHA256 cb0a2636b2512c36140b96bd1b01229029ae80457efc457a4203bcc00dc95cda。界面应显示 **180MM BODY TRIAL** 和 **OUT32 CORE16**。固定同一白色3528/载带、180mm/EXP1092/GAIN40/WB100/100/灯3档。

旧CAL64有件36×44/46、A1456/1516，换内部为18×22/23、A364/379。只改两区body Lmin26→22、Smin20→18（直接取实测最小）；上限39/36、review43/38、空穴/孔/暗参考全部保留旧值。未据两点推断公差或重新教入零尺寸。分类前景100、Sobel80、有效区/四结果、视频/迟到同槽/VS与SDC不变。

新CAL32空穴前景0/0，定位孔0/4，T100不能获得完整孔形状；未推断T80的几何。这个版本可能仍显示NO TARGET/UNCERTAIN，不能用于承诺空穴检出。后续实物可用时再检验两区有件及混合/空穴/孔/背景；必要时补同门限数据，不能混T100有件和T80孔当作同一掩码配方。

5项针对性软件测试PASS：cal180_body、local_wait、calibration_chain、regions_osd、regions。新专项7帧19记录包括精确实测W/H/A合成连通形状、同输入旧下限反事实（旧判不确定）、双区、框边/奇偶相位错位、中心越区、零前景与单格不判空穴、低于下限及取消清旧。合成几何不冒充原生实物准确率。真实ISP/DDR四视图11输出栅格10945150精确像素、OFUF0，5帧实际CAL字段另经独立NumPy重算PASS。

TD6.2.168116实际构建r1，最终测试r2；二者353输入仅新测试夹具文件不同，全部生产RTL/IP/SDC逐字节一致，manifest分别f4d3ae46fb12f787e9044fd5dbfabbce66e9eee664acd63a2ba4da0c4f6bc2d0 / cc7425ff9cf324562a28a118913cebb8e6181be410821bb6592e9b84e663b11c。r0正确复现旧规则失败；r1测试夹具36×46起始行未对齐2×2导致尺寸不符，r2只修夹具摆放、保留原1516面积预期并增加奇偶相位用例。所有失败/清单/差异保留在history，不覆盖冻结轮次。没有把r1失败当通过，也未重烧同一源码。

TD双角Routed setup+0.105ns、hold+0.020ns，TNS0，STA92.85%；Slice16849/21216（79.42%），ERAM94、DSP26、PLL5。SDC未改，40max_delay全匹配/ignored0、20Gray逐位主导8ns且非负slack。该约束统计为22条匹配/主导路径，不能机械等同20个逻辑位；额外检查了21个物理末端引脚的29条报告数据/控制路径，均8ns且正slack，完整路由STA无违例。保留历史相机输出本地路由、PLL/DDR反馈及I/O覆盖边界，不宣称零警告或所有外设时序已证明。

审计装载尝试也保留：原脚本从work启动时TD相对XML报错；未初始化时get_regs/绝对报告路径尝试没有有效输出，均未作为最终验收。最终v3在实际phy_1目录装载项目、初始化时序、用相对报告路径，日志无ERROR/空目标，实际44份报告单独核验。未改变RTL/约束/镜像来通过审计，history/audit_loader_attempts仅为过程失败证据。

无上板/Flash、Git提交或推送。现有32和64候选包不动。用户回到板旁后的复测是未完成项；独立物理验证后，再按67计划关闭CAL、恢复正常502位并重新构建。SS12—SS110新PDF仅在活动仓库归档备用，没有混入本型号或启用第二型号。

```powershell
python -X utf8 scripts/verify_candidate.py
python -X utf8 scripts/replay.py --action verify
python -X utf8 scripts/replay.py --action prepare --work D:/body180_replay --td-root D:/AAA/FPGA.....YZW
python -X utf8 scripts/replay.py --action sim --work D:/body180_replay --td-root D:/AAA/FPGA.....YZW --modelsim-bin D:/modelsim/win64
python -X utf8 scripts/replay.py --action build --work D:/body180_replay --td-root D:/AAA/FPGA.....YZW
```

prepare目录必须全新、ASCII且无空格，工具路径按机器调整。新建后在工作目录运行audit_routed.tcl核对实际约束；replay的正WNS检查不能代替完整审计。独立NumPy参考脚本和实际trace位于source_snapshot/sim与validation/reference_input。
