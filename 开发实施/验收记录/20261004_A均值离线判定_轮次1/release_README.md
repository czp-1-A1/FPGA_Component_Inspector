# 离线均值判定准备版（2026-10-04）

镜像：camera_to_dsi_display.bit，1,789,539字节；SHA-256 `e9ae1233a592f5d500d8b30cabbcb17acbf82c6ed49ce1ead95be26e0282a707`。

已集成均值分类、帧新鲜度和独立RECENT状态行。交付默认CLASS_CALIBRATED=0，应显示RECENT UNCAL；保留512×256中央灰度观测框、框外彩色、EXP/GAIN和四键。正式单穴ROI、阈值、方向、光源/距离尚未标定，本版不输出实物分类。

ModelSim11项通过，TD6.2.168116最终构建：Slice14140（66.65%），31ERAM/8DSP，Setup/Recovery WNS0.199ns、Hold0.020ns、TNS0，STA95.06%；既有I/O/PLL/DDR约束缺口仍待处理。默认禁用比较逻辑被优化；未来启用必须重新TD检查。

本版未上板。用户自行下载后先检查画面、四键、统计和UNCAL，之后选单穴ROI并采同条件有件/空穴数据。结果为最近采集状态，不与DDR显示帧绑定；不能用于运动或逐穴NG。30分钟、实物准确率、固化/冷启动均未测。

完整说明：仓库开发实施/16_A均值判定与离线验证_实施说明.md；证据：开发实施/验收记录/20261004_A均值离线判定_轮次1.md及同名目录。回退版roi_statistics_large_20261003保持。
