# 180mm白色3528照片阈值试验版

代码已按最新人工状态样本调整；图片原件已完整归档。固定同一器件/载带、180mm、EXP1092、GAIN40、WB100/100及原照明，保留大视野和两有效区/各2结果。

烧录文件：candidate/V12_POSE180_1092_40_20261016.bit，1789539字节，SHA256 `c8a5a49ec50263b2bf4d53ad009dc6e4d5c756837fe8951a1b5ee5e1f583e0df`。本机已校验短路径：`D:/fpga_download/3528_pose_c8a5a49e.bit`。在烧录工具中重新选择此绝对路径，避免旧相对路径打不开。屏幕标题为 **180MM POSE TRIAL**。

正常下限44/36→40/32、填充85%→80%；另设侧立/翻面等有件复核容差，并用既有T80通道保留低灰主体。有件与复核分开，FIT CHK/REVIEW不表示完整质量合格。大小孔分离保持；粉色32标定框移除，黄色16核心保留。穴内偏移已取消。GRAY+EDGE原视图保留，未新增逐对象Sobel投票。

同一冻结357输入/10项回归、27FPS完整模块链路、独立CAL/孔参考和真实TD路由约束审计通过。setup+0.100/hold+0.020ns，TNS0；Slice81.14%、ERAM104/108、DSP26/40。现场准确率和异常覆盖仍需同工况实板复核；手机拍屏不是原生输入回放。详见validation/ACCEPTANCE.md及build_evidence。

标定来源：calibration_sources/3528_180mm_1092_40_calibration_sources_20261016.zip，含最新21图/2视频及历史CAL/标尺/旧异常/3528原规格书；原件哈希和CRC全部核验。来源包保留参数制定时r4记录；r5仅改等价地址步进，所有阈值/人工真值不变。最终代码身份见source_snapshot/inputs.json及handoff.json。

先运行scripts/verify_candidate.py核对本包。重放入口scripts/replay.py：verify；prepare需全新ASCII无空格目录，--td-root D:/AAA/FPGA.....YZW；sim需--modelsim-bin D:/modelsim/win64；build后再从工作目录执行scripts/audit_routed.tcl。冻结来源、10项日志、实际报告和r0—r4失败/替代记录均在包内。

下一步同工况观察正常有件、侧立/翻面、有件空穴混合、只含定位孔、整条载带倾斜。此包未烧板/Flash/提交/推送，正式发布及旧镜像保持。
