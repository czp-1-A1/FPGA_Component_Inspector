# 180mm3528显示编号稳定版

修复已复现的竖放目标X排序交换导致编号/卡片上下跳；每区沿用近邻显示编号，显示当帧结果，丢失时清除。去掉左下最近采样及固定黄16框。保留器件检测框/各自结果，识别阈值和视频读取不改。

烧录文件candidate/V12_POSE180_STABLE_IDS_1092_40_20261016.bit，SHA256 `16bd8beb593b1bf43f2eb4bfea3d3b58d1f5dbc1adca66644874a30e4f8b0e1e`；本机短路径 `D:/fpga_download/3528_stable_ids_16bd8beb.bit`。固定180mm/1092/40/WB100/100和原照明。屏幕标180MM STABLE IDS，请重新选择本次新文件。

358冻结输入、3项当前显示回归/9完整栅格、新TD路由及实际约束资源审计通过；原r5十项/27FPS为上版证据，未冒称本轮重跑。setup+0.126/hold+0.020ns，Slice83.69%，ERAM104/108，DSP26/40。物理效果待新版实板复核。OBSERVATION_GUIDE.md说明显示规则和边界。

scripts/verify_candidate.py核验完整包、旧版源重建、失败复现和来源ZIP。scripts/replay.py可verify/prepare/sim/build；prepare使用全新ASCII无空格工作目录，--td-root D:/AAA/FPGA.....YZW，sim加--modelsim-bin D:/modelsim/win64；build后仍需从工作目录执行audit_routed.tcl。候选未烧板/Flash/提交/推送，正式发布和旧r5保持。
