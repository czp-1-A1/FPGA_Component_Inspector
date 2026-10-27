# R23动态有件诊断接棒

当前分支`r23-present-trace-20261028`，父为R22 `a1cceaa9b5a37ff31b7f84a77c00042b027208d0`。`fpga/component_inspector/`包含精确636冻结输入，与已交桌面镜像一一绑定。**R23是被动诊断版，尚未修复现场正常有件移动误复核，也没有R23实板验收反馈。** R22正常速度稳定的用户反馈只属于R22。

## 获取及验证

```powershell
git clone --single-branch --branch r23-present-trace-20261028 https://github.com/czp-1-A1/FPGA_Component_Inspector.git FPGA_R23
cd FPGA_R23
python scripts/r23/verify_r23.py
```

最终manifest SHA256：`075d48c42753f488ce0d2ae15761c3bad189022175190368261d2b503a1c5ae2`。
镜像`PocketCount_SW3_PresentTrace_r23_20261027.bit`，SHA256：`103ea4c37393f6eaf71a91c7740eaa14544e7d2e1b6c0fbc2cf98d25dafd93d7`。
完整包`releases/r23_20261028/PocketCount_SW3_PresentTrace_r23_20261027_full.zip`，SHA256：`77c4eedc21c8ce5f0fe9142dd3a30165571e865eec40945855aad2fdb9a7e8e0`。
同目录有烧录说明、SHA、交付回执、最终/实际执行manifest、综合复用证明、独立归档核验和FIELD_FEEDBACK。文件名冻结日期20261027，实际交付/上传为20261028，不改旧文件名。校验器只读标准库验证636源、4884载荷、151日志、102依赖等身份与原验证证据，不是重新构建或实板通过。

## 当前问题与实现

用户报告R22正常速度计数稳定；正常平放件移动时偶发“有件/待复核”切换，晚间更明显，静止或早上可能恢复正常。早上视频2个复核确为异常摆放。尚无足够像素证据认定具体灰度/Sobel/弱路径为根因；不要整体放宽阈值、强制移动件正常或牺牲真实异常检出。

R23仅在原RAM/原读拍旁观灰度及四个有符号Sobel核。PRESENT_TRACE默认0、生产顶层1；同ROI优先实际复核P，否则最后测量正常P，绑定X排序后的最终公开槽。复用128位CAL同源DDR/迟到/VS链，不加图像RAM或FSM读拍。弱路径未测显式标记。两页DETECT R23/COUNT R23底栏增加PTRACE/SUM/G9，中文类别、Logo和主要位置保留。生产7文件local_edge_surface_check/frame_shape_search/ISP/top/3compactUI及仿真派发有变化；原counter/pipeline/局部恢复/控制/灰度缓存/SDC及旧260bench答案原字节保留。旧R22灰度+局部Sobel算法继续有效。

修前观察器漏选相邻复核P的scene16失败已保存，修后公开输出和FSM严格等价R22。实际151合同执行candidate_r1 manifest`152202701bd6fb143b8f7184739aa6715c5d0fe1de8cf218fbc00888d7b9b4bb`；最终candidate_r2只改非执行独立参考`tools/check_present_raw.py`报告变量名，所有RTL/bench/runtime和实际编译/日志逐SHA匹配，不能声称执行了不同生产输入。

## 验证及边界

151软件合同、53独立参考全PASS；独立解包重算53参考、4884载荷/636源/151日志/102依赖及物理审计通过。含14native/4761846拍R22严格等价、12902400像素/40signedkernel、39请求/567753拍、4幅720p3686400像素0差异、四模式44RAW源帧/148实际对象/16真值事件。所有失败及复测留证，仿真不代表现场准确率。

原SDC/seed2最终Routed Slice19010/21216=89.6022%，ERAM101/108、DSP27/40、PLL5/6；setup+0.002ns、hold+0.020ns、双TNS0。46maxdelay匹配Ignored0、20实际GrayQ8ns/31物理路径、6邮箱和SW3完整扇出审计通过。时序余量很小，改RTL必须重新冻结验证；综合17944是中间值，既有DDR/PLL/I/O告警保留。

## 跨机复原

TD6.2.178840、ModelSim10.5、Python3，独立像素参考需要NumPy/Pillow。选择新的全英文无空格目录，不能覆盖已有工作区：

```powershell
python fpga/component_inspector/tools/prepare_portable_project.py --source fpga/component_inspector --manifest releases/r23_20261028/frozen_inputs.json --work D:/FpgaWork/R23_replay --td D:/td6.2.1
```

TD入口`td_project/camera_to_dsi_display.al`；该步骤只重定位工程描述符并检查102依赖，不等于重新仿真/布线。完整ZIP保存所有原日志、独立工具和参考捕获；`workflow_scripts/`含原机D盘路径，仅作证据，跨机先复原再适配，不能盲跑历史调度工人。旧scripts/r22等只验证各自旧冻结，不能用于当前R23树。

## 下一步现场数据

使用同一R23镜像，EXP1092/GAIN40/WB100/100锁定，固定灯和相机；SW4上拨检测页。拍正常平放件“静止3秒→常速移动→静止3秒”，再拍真实异常件同速对照，两段均保留全上下栏PTRACE/SUM/G9与目标框。ROI/SLOT绑定同源公开槽，弱路径M0不能当实测。根据真实触发门再做最小修复，保护空穴、计数、局部恢复与真实异常。

SW3先上再下开段；K3+K4长按1秒全清RUN/累计/空号；每趟独立计数清零重开。同RUN回退重走不当作独立准确率。已知15穴5空正001002008013015、反001003008014015用于回归，不用已知节距/真值补数。

## 接棒保护

先核对分支/HEAD/暂存及未跟踪文件。单实现端写入，验证冻结与开发隔离，旧R22及其他分支/release/Example保留，无强推。生产端已停止，无所属仿真/TD工人；未操作板卡/JTAG/Flash/用户TD窗口，无子代理。r23临时跟进已删除，r12继续暂停。当前上传新分支/固定标签，实际提交以Git HEAD和远端校验回执为准。
