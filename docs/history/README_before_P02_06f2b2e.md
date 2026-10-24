# FPGA载带智检与逐穴计数 — R13交接入口

当前Li47分支：`lj4747-contest-work`；冻结标签：`r13-compact-resource-20261023`。

**其他AI接手先读：[R13完整交接说明](docs/R13_HANDOFF.md)，再读根目录[AGENTS.md](AGENTS.md)。**
`main`与其他队员分支不代表此R13。历史README、旧手册中的K1+K4启动、K3+K4仅结束、遇单穴丢失全局停止等描述不是R13操作规范。

R13是单条同型号载带在固定ROI内，直接复用有件/空穴分类结果，按源帧关联、过线去重并保存总数、类别与空穴编号的FPGA工程。相机1920×1080 RAW10/PPC4，经白平衡、去马赛克、2/3缩放到1280×720，HDMI 720p60；相机源FPS与HDMI刷新率不同。

## 直接下载

- [R13 bit](releases/r13_20261023/PocketCount_SW3_CompactResource_r13_20261023.bit)
- [完整冻结源码、验证日志、路由与约束证据ZIP](releases/r13_20261023/PocketCount_SW3_CompactResource_r13_20261023_full.zip)
- [烧录与验收说明](releases/r13_20261023/PocketCount_SW3_CompactResource_r13_20261023_烧录与验收.md)
- [SHA-256](releases/r13_20261023/PocketCount_SW3_CompactResource_r13_20261023_SHA256.txt)
- [交付回执](releases/r13_20261023/PocketCount_SW3_CompactResource_r13_20261023_交付回执.json)

bit SHA-256：`2350b5985afa679df3d8bfd1a5fa2aba9f355468f284704d10dd46beeda402a7`。

## 当前结果与边界

| 项目 | R13最终结果 |
|---|---|
| 冻结输入 | 471项，manifest `243651b68a39160cfb81efe91b11836bcb32109750ecd29793530fca1bc98c65` |
| 软件 | 72项既定回归；25重跑、47逐SHA复用真实旧结果；另有行RAM等价、四幅720p UI逐像素和动态RGB专项 |
| 独立参考 | 10套native RAW、86源帧RGB、44源帧字段/真实像素编号绑定 |
| 最终Routed | setup +0.002ns；hold +0.020ns；双角TNS均0 |
| 约束 | 46 max-delay匹配/Ignored0、20 Gray位8ns、6邮箱/SW3扇出通过 |
| 资源 | Slice19708/21216=92.89%；ERAM87/108；DSP28/40；PLL5/6 |
| 现场 | 2026-10-23用户反馈R13上板测试“没问题”；未新增逐速度、逐排列量化验收记录 |

本轮资源优化释放18块ERAM，Slice低于90%的目标未达到。高速空穴漏识别仍是待量化问题；软件通过、用户总体反馈均不代表任意速度/物料保证。后续R14五项微优化均未采用，不属于R13。

## 操作

SW4上拨检测页、下拨计数页；只切显示，计数基于同一分类链路。SW3先上拨再下拨开始新段；上电时保持下拨不会自动开始。K3+K4长按1秒清RUN、全部数量、空号、历史首错及GAP。最多300穴。

TOTAL=PRESENT+EMPTY；REVIEW是有件中的待复核子集，不再相加。`GAP FROM`以后R号表示记录顺序，不能当作已确认的物理穴号。

## 接手快速校验

在ASCII、无空格目录使用Python3.12运行：

```powershell
python scripts/r13/verify_r13.py
python scripts/r13/prepare_r13.py --work D:/FpgaWork/R13_replay --td D:/td6.2.1
```

第二条只创建新工程、核对98项目/IP依赖并固定已验收seed2，不自动综合或操作板卡。TD6.2.178840、ModelSim SE64 10.5、厂商仿真库与有效许可证需本机安装。工程入口是新目录中的`td_project/camera_to_dsi_display.al`。完整构建/测试/接口契约见[交接说明](docs/R13_HANDOFF.md)。
