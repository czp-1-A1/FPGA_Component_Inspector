# FPGA载带智检与逐穴计数 — P02当前入口

当前成果分支：`lj4747-contest-work`。P02在R13基础上优化“有件/待复核”，用户本轮反馈 **“测试正常”**。

**接手先读：[P02完整交接](docs/P02_HANDOFF.md)；让其他最新工程沿用，读[逐文件改动与迁移说明](docs/P02_PORTING.md)。**

本轮确认正常和背面都触发原周边暗参考复核，不能简单清除该位。P02改用器件本帧内部表面证明，覆盖双ROI全部8个真实计数候选；原尺寸/比例/填充、弱T80复核、空穴/定位孔、计数、按键、视频与源帧/DDR绑定保留。

## 下载与复用

- [P02 bit](releases/p02_20261024/P02_PresentSurface_1092_40_r0_20261024_dfd2e5c8.bit)
- [GitHub发布/完整工程与验证包](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/p02-present-surface-20261024)
- [功能提交 b549237f](https://github.com/czp-1-A1/FPGA_Component_Inspector/commit/b549237f15aafd3e3979b53f9df88b6877651e27)：建议作为其他分支的移植单元
- [改动/依赖清单](releases/p02_20261024/INTEGRATION.json)、[烧录及字段说明](releases/p02_20261024/FIELD_GUIDE.md)、[验证证据](releases/p02_20261024/README.md)

bit SHA256：`dfd2e5c8f7081f32f526be0b9e02e754649f1509d872e7cd12aac4ffba9199b8`。本机bit统一放`D:/fpga_download/`。

## 校验与新目录复原

```powershell
python scripts/p02/verify_p02.py
python scripts/p02/prepare_p02.py --work D:/FpgaWork/P02_replay --td D:/AAA/FPGA.....YZW/doc
```

TD参数应指向包含scripts/DefaultFlow.tcl的目录。准备只创建新目录、重定位描述符、核对100依赖并保持seed2，不自动构建或烧录。TD/ModelSim与许可证需本机安装。

|项目|P02实际结果|
|---|---|
|源/依赖|504冻结输入，100硬件/IP/约束依赖|
|原相关回归|24项通过，未称全部原72项重跑|
|新专项|26请求/105均值；8 RGB帧/全部8槽；70帧计数；7合成RAW帧；两套各3686400像素UI参考|
|实际Routed|Slice18266/21216(86.10%)；ERAM103/108；DSP28；PLL5|
|时序/约束|双角setup+0.005ns、hold+0.020ns、TNS0；46max-delay/Ignored0、20Gray/6邮箱/SW3通过|
|现场|用户收到P02后总体反馈“测试正常”，未新增速度/光照量化矩阵|

## 操作与历史

SW4上检测/下计数；SW3先上再下开新段；K3+K4长按1秒全部清零。TOTAL=PRESENT+EMPTY，REVIEW是有件子集，最多300穴。相机1920×1080 RAW10/PPC4缩放至1280×720，HDMI720p60，源FPS与显示刷新率不同。计数/失联恢复详细契约沿用R13。

[原R13发布](releases/r13_20261023/README.md)及`r13-compact-resource-20261023`标签保留回退。当前工程目录已是P02；旧R13校验应在原标签checkout运行。历史默认参数、旧README/CAL字段和current_*.json不能代替当前P02交接。
