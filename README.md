# FPGA载带智检与逐穴计数 — P03当前入口

成果分支：`lj4747-contest-work`。P03在已接受P02基础上补充“有件侧立”复核，保持有件身份及原计数、按键、视频行为。**软件和实际布局布线验证通过，P03实物验收待反馈。**

**接手先读：[P03完整交接](docs/P03_HANDOFF.md)；其他最新工程沿用，读[改在哪里、加了什么、实现了什么及迁移方法](docs/P03_PORTING.md)。**

P02检查边缘不能太暗，新增侧立会出现边缘明显亮于中心却放行。P03保留全部P02条件，再比较未取整的中心/边缘累加值；全部8个真实有件候选共享判据，只改质量原因位。生产RTL只改present_surface_check.v和P03标题，没有增加图像缓存、端口或元数据位宽。

## 下载与复用

- [P03 bit](releases/p03_20261025/P03_Standing_1092_40_r0_20261025_21d1004f.bit)
- [GitHub预发布/完整源码与验证包](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/p03-standing-review-20261025)
- [P03功能提交 9d459688](https://github.com/czp-1-A1/FPGA_Component_Inspector/commit/9d4596885b29559f0bb5ed873464c6964cc53b1a)：已有P02的工程可作为独立移植单元
- [前置P02功能 b549237f](https://github.com/czp-1-A1/FPGA_Component_Inspector/commit/b549237f15aafd3e3979b53f9df88b6877651e27)：从R13等旧基础接入时先合P02，再合P03
- [可机读改动表](releases/p03_20261025/INTEGRATION.json)、[最小两文件补丁](releases/p03_20261025/P02_TO_P03.patch)、[实际验证证据](releases/p03_20261025/README.md)

bit SHA256：`21d1004fc74505ae7b5ee0c05aadc9c07cb780a2dd0fd763115b3796def060db`。本机bit统一放`D:/fpga_download/`。公开包保留相同526冻结源/bit、100硬件依赖和合成验证资料；手机原始视频、照片和个人源路径留本机。

## 其他电脑复原

```powershell
python scripts/p03/verify_p03.py
python scripts/p03/prepare_p03.py --work D:/FpgaWork/P03_replay --td D:/AAA/FPGA.....YZW/doc
```

TD目录必须包含scripts/DefaultFlow.tcl，准备工具只复制/重定位并保留原seed2，不自动构建或烧录。源码/bit/证据校验不等于重新综合或实物通过。接收工程自己的功能不能被覆盖，迁移后重新跑功能、资源、实际路由与实物验证。

## 当前验证与资源

|项目|P03结果|
|---|---|
|输入身份|526静态源，100真实硬件依赖；相对P02两处RTL/三处路径变化，其余499父源逐SHA保持|
|软件|39单元请求/170精确均值及和；9RGB帧72记录；70计数帧140观测；原24项相关回归（非原72全跑）|
|完整链路|8合成RAW源帧/28判定/70探针均值，14623282像素，OF/UF零；两套各3686400像素UI独立参考零差异|
|实际Routed|Slice18385/21216(86.66%)；ERAM103/108(余5)；DSP28；PLL5|
|时序/约束|双角setup+0.010ns、hold+0.020ns、TNS0；46max-delay/Ignored0、20Gray/6邮箱/SW3通过|
|现场|P02用户反馈“测试正常”；P03新增侧立效果待实物反馈，发布为候选预发布|

## 操作与历史

SW4上检测/下计数；SW3先上再下开新段；K3+K4长按1秒全部清零。TOTAL=PRESENT+EMPTY，REVIEW是有件子集，最多300穴。1920×1080 RAW10/PPC4缩放至1280×720，HDMI720p60，源FPS与显示刷新率不同。计数/失联恢复沿用R13契约。

[已接受P02](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/p02-present-surface-20261024)与[原R13](releases/r13_20261023/README.md)标签/发布均保留。当前工作源为P03；P02/R13固定源码校验请在对应标签的新checkout运行。冻结的历史README、旧CAL字段和current_*.json不能代替当前P03交接与FIELD_FEEDBACK。
