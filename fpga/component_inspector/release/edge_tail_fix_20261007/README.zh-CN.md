# EDGE帧尾修复候选

源码提交：`43a3da6cf36da923835f4e7fb5f03e3bdb5c779f`，分支`lj4747-contest-work`。本机TD6.2.178840，PH1P35MDG324 speed3。

本目录`camera_to_dsi_display.bit`，1789539字节，SHA256：

`bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65`

安全行边界之后框外图像直通，缩短边缘模式帧尾延迟。旧RTL停CSI反例不发布，新EDGE/GRAY+EDGE在相同驱动下完整发布；逐像素、真实ISP及MC读写回归通过。综合/布局布线完成，setup+1.384ns、hold+0.020ns、TNS0；STA覆盖94.59%，原DDR PLL和I/O约束告警仍需后续核对。207输入清单与源码提交匹配，见build_inputs.json及manifest.json。

**实物未复测，不能据软件结果宣布板上冻结已解决。** 本次图像与原诊断界面相同，ER/LP/WS无法单独区分新旧bit，必须确认实际下载文件及SHA。旧`edge_diagnostic_20261007`已被用户判EDGE冻结失败，保留作历史对照。

人负责下载与实物操作；在TD下载器选择本目录bit，沿用现有器件/JTAG方式。保持相机/光源/EXP/GAIN/距离，按RAW→GRAY→EDGE→GRAY+EDGE→RAW测试：每模式稳定2秒，再移动载带10秒，记录开始/结束OF/VF/UF及画面是否持续更新，切换期增量与稳定后增量分开。ER非0或冻结时保留失败，回RAW记录恢复。WS可能包含尾部credit-low等待，本轮MC通过时WS457，因此WS非0本身不判故障。

详细操作/结果填写`开发实施/验收记录/20261007_A_EDGE上板复测_轮次2.md`。测试期间固定本镜像与源码，不边测边改。短试验不替代连续30分钟视频与冷启动；CLASS_CALIBRATED=0，分类未测。
