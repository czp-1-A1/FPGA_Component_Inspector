# D3 计数器 CHECK 长链优化记录

用户在审阅 R44 停止分析后明确要求执行。本次不删双列识别、独立计数、编号停车、各列五连空报警、完整 1 秒保持、按键控制或四种显示，不改 IO、时钟、SDC，不操作实板。

## 改动及其依据

R44 的 **placed 报告**中，100 MHz 同域前 10 条 setup 路径均进入下列计数器 `armed` 写回。第一条为 `negative[1] → armed[26]`，13 级逻辑、数据路径 9.010 ns、slack +0.770 ns。这是布局线索，不是已经取得的最终布线失败路径；R44 没有保存 route DB。

隔离候选只改 `observed_classified_pocket_counter.v` 的两个精确枚举代码块：

1. 在原有 `READ_CHECK` 周期寄存该帧的 gap step、方向、退役锚点许可、守护距离，以及 gap step 与 LINE_X 的有符号偏移。
2. `CHECK` 仍使用同拍 RAM 已读出的**当前轨迹**。将当前轨迹的 `old_x + missed_dx` 与预先计算的偏移相加／相减，得到原有的 signed 14-bit `counted_distance`。

没有新增 FSM 状态或等待周期。原件 `classified_pocket_counter.v` 的 SHA-256 仍为 `67dfbdd7f139eb275decc48d6fd19e64965679ad352b3a291a0675a09401394c`。704 份冻结输入相对 R44 仅这一份观察副本不同。

### 为什么没有提前读取旧轨迹

`track_word` 在 `READ_CHECK` 的上升沿才更新，所以该沿其他顺序语句看到的仍是上一条轨迹。新增寄存器严格只取帧参数，不取 `track_word`、`old_x`、`missing`、`missed_dx` 或 `old_id`。这些当前记录量仍在 `CHECK` 使用，避免跨轨迹串值。

帧参数在 `READ_CHECK → CHECK` 之间保持不变。原 FSM 的 reset、start、finish、frame_bad、busy/sample 冲突优先级原样保留：取消的读取不会越过这些优先级执行一次 CHECK；后续 CHECK 仍须经过新的 READ_CHECK。

### 数值语义

原式将各个中间位置写入 signed 14-bit wire。重排后的式子保留同样的 14 位模运算，没有缩窄比较精度。守护距离仍以原有的 signed 32-bit 表达式计算后寄存。

`check_d3_check_prepare_math.py` 针对实际 LINE_X=640，穷举全部 16384 种聚合轨迹余数 × 8192 种 signed 13-bit gap step × 两种方向，共 **268435456** 个比较。聚合轨迹余数覆盖实际 `old_x + missed_dx` 的全部可能值及其超集；新旧 signed 14-bit 距离全部相同。因此与任意相同的 signed 32-bit 守护距离比较也相同。此项是算式穷举，不宣称完整计数器形式验证。

## 验证及证据位置

- 隔离原型：`E:/2026FPGA/.codex_tmp/d3_check_prepare_r45_20261031`。
- 冻结综合：`E:/2026FPGA/.codex_tmp/d3_check_prepare_synthesis_r46_20261031`，704 源／107 硬件依赖；manifest SHA `c0fb63f7b3de3bda0d0022ae9b1d83698295c77b0c1fad55b1981b54e07abc11`。
- 布局检查：`E:/2026FPGA/.codex_tmp/d3_check_prepare_physical_r47_20261031`，原 seed4／Default／时钟／约束，复用 R46 完全相同的 SYN DB。使用官方 `opt_place` 阶段边界先停在布局，尚未批准结果等同最终布线通过。
- 13 项双列原计数逐拍公开输出对照、变速停车、暂停／继续、相邻空穴、独立报警与重新运行均 PASS。
- 13 项像素、排名、缓存、距离选择、按键、记录、定位保护、四显示精度与真实 100 MHz 的 100000000 周期完整 1 秒检查均 PASS。
- 新增 `tb_d3_check_prepare`：六种参数配置、两方向、32 个 RAM 地址、3 万组原件／候选实际 READ_CHECK/CHECK 配对，覆盖不同的旧／新 track_word、signed 边界、reset/start/finish/frame_bad/busy 取消，比较写回 PASS。这是白盒边界测试；真实完整流程仍由上述 13 项对照覆盖。
- 三项字体／OSD 和一项 ID RAM 读口沿用逐份 SHA 完全相同的已编译输入检查，已重新核验。
- R46 实际 SYN 网表相机闭合控制锥：两次复位 ×126 次完整 I2C 初始化写入 PASS；不是传感器光学回读。
- R46 实际 SYN 网表确认字体全部 64 个 INIT 块及两列独立 9-bit 地址 ID ERAM，PASS。
- 数学证明、观察副本全文精确逆变换、输入不变量及 suite-map 保存在 R47。完整 RAW/DDR/display 的两项 native 检查须使用本候选重新运行后，方可将它称为 34/34；不沿用旧候选 native 结果。

## 初步资源结果

同样综合阶段的 Slice 估算为 **21375 → 21265，减少 110**；LUT 27419 →27375，FF 23417 →23479，ERAM 105 不变。综合估算不是最终实际 Slice，也不是资源或时序验收。实际布局、路径及后续是否继续 route 的结论另追加。

## R47 布局结果：未进入完整布线

官方布局阶段正常完成，耗时 394.9 秒，源与策略／约束均未改动；保存了 place DB。实际结果为：

| 项目 | R44 原生产优化 | R47 偏移预计算候选 | 变化 |
|---|---:|---:|---:|
| 实际 placed Slice | 20124 /94.85% | 20258 /95.48% | +134 |
| 普通逻辑 Slice | 14836 | 14842 | +6 |
| 进位运算 Slice | 3217 | 3277 | +60 |
| 只有寄存器的 Slice | 1527 | 1595 | +68 |
| DRAM Slice | 544 | 544 | 0 |
| placed FF | 23078 | 23134 | +56 |
| placed setup WNS | +0.770 ns | +1.049 ns | +0.279 ns |
| placed hold WNS | -0.272 ns | -0.281 ns | -0.009 ns |

ERAM105、DSP31、PLL5 不变。新 100 MHz 首条路径转移到 FSS 的 RAM 读出至 state_bank 写回，10 级、8.731ns。这证明布局中的主导路径发生变化；不证明最终布线可收敛。

**R47 不采用，不进入 route。** 它改善了布局 setup，但增加实际 Slice，并越过工具 95% 拥挤警告线。寄存器数量远未满，并不能保证新增寄存器不占 Slice：新增进位运算和只有寄存器的布局单元抵消了综合估算收益。这也是本次坚持测量实际布局、未依据 SYN 估算直接跑完整布线的原因。

`REJECT_REASON.json`（工程及 docs 各一份）记录报告、源 manifest、DB 和进程证据。空白 RAW 的两帧 native 检查已 PASS；长 native 在第 2 帧后因候选被资源门槛拒绝而主动取消，仅停止该任务专属的 vsimk39496 和 wrapper35712，旧进程未动。没有完整 native PASS，没有 34/34，没有 bit，没有正式源替换。

## R48 精简后续

先向用户说明上述成本，再缩小至 **每列 gap_step13 位 + retire_anchor1 位**。删除偏移预计算、方向副本和 32 位守护距离副本，保留原有的距离算式、位宽和阈值；仍利用原有 READ_CHECK，没有新增 FSM 状态。

隔离 R48、冻结综合 R49。新的六配置 3 万组边界配对及 13 项双列实际流程对照均 PASS。未对它宣称 R47 的整链 native 或算式重排穷举结果。下一步先测它的 SYN／实际布局，不将失败的 R47 源合入生产。

## R50 实际布局收益及完整实现门槛

精简版 R49 SYN 估算 21360（原 R43 为 21375），28 个新增 FF、额外进位单元 1。R50 复用该 SYN DB，采用相同 seed4／Default／时钟／SDC，官方布局阶段正常完成 460.7 秒：

| 项目 | R44 | R50 精简版 | 变化 |
|---|---:|---:|---:|
| 实际 placed Slice | 20124 /94.85% | 19994 /94.24% | -130 |
| 剩余 Slice | 1092 | 1222 | +130 |
| 普通逻辑 Slice | 14836 | 14919 | +83 |
| 进位运算 Slice | 3217 | 3218 | +1 |
| 只有寄存器的 Slice | 1527 | 1313 | -214 |
| DRAM Slice | 544 | 544 | 0 |
| placed FF | 23078 | 23105 | +27 |
| placed setup WNS | +0.770 ns | +0.349 ns | -0.421 ns |
| placed hold WNS | -0.272 ns | -0.284 ns | -0.012 ns |

ERAM105／108、DSP31、PLL5 均不变。Slice 是全工程实际放置统计；寄存器专用 Slice 减少、普通逻辑 Slice 增加，说明整体打包发生了变化，不将全部收益归因于某一个逻辑表达式。相对更早 R37 的 20565，当前放置合计减少 571。

原先领先的 counter `negative → armed` 长链已不是 100 MHz 首条路径；首条转到 FSS `ramread16 → reason_bank[47]`，10 级、9.431ns。**全局布局 setup 余量比 R44 小，布局 hold 仍为负；这不是时序验收通过。** 本候选有实际资源收益，因此继续以同一 place DB 做一次完整 route／bitgen，不重新放置、不换 seed，不放宽时钟或约束。

冻结 manifest SHA：`7eac9e2e0fe534d4bc2741662908654190b600b724f3b7cab4a05d04cfa20dec`；SYN DB SHA：`1419fe9a7a56b04307c298ed8b2351237d2f72ddb9dbaf9bbb3f983f661e83a2`；place DB SHA：`ba68f6407f244fb4e9acd3632430067e4514eef24114d400759941a73ce85512`；area SHA：`c57dc85d47aeb6b9b6e20cc165d6b6168a7fc1e540a6836b250934a658f12664`。

R50 工程：`E:/2026FPGA/.codex_tmp/d3_check_minimal_physical_r50_20261031`。已通过原计数对照13项、units13项、边界1项、精确同源复用字体／OSD3项及ID读口1项、实际 SYN camera1项（闭合300个综合单元、两次复位×126完整I2C写），以及两个完整 native 检查。长 native 用时26分13秒，12帧RAW／24帧精确显示／22940160像素，OF=0、UF=0。

**严格 lossless-v6-check-prepare 34/34 PASS，`--require-production` PASS。** 通过后仅将 R50 的观察副本复制到正式工程，逐 SHA 核验所有704份正式输入与冻结候选相同；原 R27B 计数器不变。`docs/D3_R50_SOURCE_ADOPTION.json`、`D3_OBSERVED_COUNTER_PROOF.json`、`D3_SOFTWARE_VERIFICATION.json` 保存收据。R47 偏移候选没有采用。

目前完整 route 尚在运行，没有物理或实板验收。只有最终 route setup／hold、49条约束／20 Gray／9 mailbox／按键与双报警到注册 V2 审计通过后才可发布 bit；完整实现若失败，先停下保存证据并分析，不盲目开启下一轮。
