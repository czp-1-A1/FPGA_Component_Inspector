# D 1080p30 HDMI格式色条（诊断，待上板）

TD易失下载根目录D_1080p30_HDMI.bit，AL为td_project/avi_fhd30.al。
人工操作唯一板卡；保留旧Flash。旧相机/TPG/A/B/C及失败证据均保留。

相对实物失败C，D保留色条、1920×1080、2200×1125、正HS44/VS5，
VS首尾与HS前沿对齐、74.25/371.25MHz目标、同一PLL源码与PHY和TMDS引脚。
增加HDMI视频前导/保护带、数据岛前后保护带和每帧一包AVI（RGB16:9、
默认量化、VIC34、不重复像素，HB82 02 0D、PB2D 00 20 00 22 00…）。
这是格式识别的受控对照，独立布局仍可能改变物理时钟质量，未证明故障根因。
没有相机、DDR或音频，不构成完整HDMI认证或采集30fps验收。

规范参考：https://fpga.mit.edu/6205/_static/F23/common_files/week04/CEC_HDMI_Specification.pdf
作者交叉核对：https://github.com/hdl-util/hdmi/blob/master/src/packet_assembler.sv
量化默认依据：https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/drm_edid.c
控制间隔至少12拍（普通控制＋8拍前导），视频2拍保护带，数据岛2+32+2拍。
视频前导只在下一行有活动图像时发送，包括帧尾接第一行。

运行前冻结接收参考及源码：反解三个实际串行引脚，连续两个完整帧，
每帧2475000符号/2073600 RGB像素/1080行；检查全部边界、正同步相位，
控制间隔/前导/保护带、每帧一次AVI、所有4子包BCH、头BCH及AVI校验和。
PASS为严格5:1理想PLL＋厂商ODDR模型；真实PLL全链及板上频率未测。
TD6.2.178840完整综合/P&R/bitgen，最终WNS/资源见diagnostic.json，
setup/hold TNS0、违例端点0；相关像素至串行路径分析，原PHY-5016告警保留。
复位及4个TMDS外部板级预算仍开放，不能称所有物理路径闭合。
15项预冻结输入、9厂商模型SHA、6项生成构建输入和原始日志均归档。
原25相机测试本轮未重跑，ISP数值参考/物理DDR/实际采集尺寸FPS仍未测。

用户确认C仍输入不支持、B色条可显示但信息菜单看不到读数；其他设备
实际1080p30能显示的用户陈述保留。D仅待人工验证色条/输入不支持。
阶段2人工门槛未通过；不启用EDGE，不改30fps目标或分类UNCAL。
rollback.bit SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65
为仓库旧候选，不声称就是用户可用Flash。人工易失下载回退，不固化覆盖旧Flash。
