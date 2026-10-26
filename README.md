# FPGA载带智检与逐穴计数 — R19候选

成果分支：`lj4747-contest-work`；固定版本：`r19-robust-empty-20261025`。R19基于已经合入P03侧立复核的R18，增加运动小空穴形状容错，保留逐穴计数、局部恢复、原控制和资源优化。

**软件和实际布局布线通过；新现场反馈仍有常速空穴漏计，当前是待继续验证的候选，不能称实板稳定版。** 同一15穴/3空载带（正向空号002、008、015）慢速反馈正常，正常速度两向仍少计；另一聊天继续分析，冻结R19不边测边改。

- [R19完整交接](docs/R19_HANDOFF.md)
- [R19 bit](releases/r19_20261025/PocketCount_SW3_RobustEmpty_r19_20261025.bit)
- [完整源码与证据公开包](releases/r19_20261025/PocketCount_SW3_RobustEmpty_r19_20261025_github_full.zip)
- [SHA-256](releases/r19_20261025/SHA256.txt)、[烧录与复测](releases/r19_20261025/FLASH_AND_TEST.md)、[现场边界](releases/r19_20261025/FIELD_FEEDBACK.json)
- [源/改动清单](releases/r19_20261025/INTEGRATION.json)、[机器可读验证与资源](releases/r19_20261025/RELEASE.json)

|项目|R19结果|
|---|---|
|冻结源/依赖|559份精确源、101真实硬件依赖|
|软件与独立参考|112项通过：63本轮重跑、49实际编译/runtime/日志精确同SHA复用；26组独立参考|
|最终Routed|Slice18971/21216=89.42%；ERAM101/108；DSP27/40；PLL5/6|
|时序与约束|setup+0.060ns、hold+0.020ns、双TNS0；46max-delay/Ignored0、20实际GrayQ8ns、6邮箱/SW3通过|
|实板|慢速单次反馈正常，正常速度仍报告空穴漏计，持续分析中|

## 校验与异机复原

克隆到英文、无空格的短路径。校验及复原不自动综合或操作板卡：

```powershell
python -B scripts/r19/verify_r19.py --archive releases/r19_20261025/PocketCount_SW3_RobustEmpty_r19_20261025_github_full.zip
python -B scripts/r19/prepare_r19.py --work D:/FpgaWork/R19_replay/fpga/component_inspector --td D:/td6.2.1
```

TD根目录需包含scripts/DefaultFlow.tcl，参考实际版本6.2.178840；原SDC/seed2不放宽。校验会重算源/bit/归档/112日志身份和实际物理审计，读取26组参考结果；不会伪称重新运行RTL或布局布线。完整原始验证捕获和工作流在公开ZIP中。

SW4上检测/下计数，SW3先上再下新开段；K3+K4长按1秒清RUN、累计和空号。每段单向，反向测试每趟重新开段，300穴结束。TOTAL=PRESENT+EMPTY，待复核是有件子集。标题为DETECT R19/COUNT R19，中文类别、安路Logo、四模式、1920x1080 RAW10到720p60及参数控制保留。

公开ZIP仅移除本机手机输入路径清单，559源、bit、刺激/答案、112日志、原生/UI捕获与物理证据不改；与桌面原ZIP的SHA不同。P03、P02、R13原标签/发布与原Example均保留；旧版本校验应在对应固定标签运行。[P03交接](docs/P03_HANDOFF.md)仍可查阅。
