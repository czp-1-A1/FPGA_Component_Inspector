# D3 R51：固定网表的 CongestionHigh 布局评估

用户在R50停止并提交分析后回复“可以”，授权按既定方案继续。本次先做布局评估，确认有改善再从保存的布局数据库进入一次完整布线；若失败或连续恶化，保存证据并停止分析。

## 固定输入与范围

- 工程：`D:/CodexWork/FPGA_R22_Relay_20261027`，分支 `codex/r27b-dual-count-and-stop-d3`，输入代码提交 `38408179`；运行前HEAD `cc6cf2e5`（后者仅文档变化）。
- 工作目录：`E:/2026FPGA/.codex_tmp/d3_congestion_high_r51_20261031`。
- 直接复用R50的704个源文件、107个硬件依赖及综合网表，不重新综合。全部704个文件与生产目录及Git HEAD blob字节一致。
- 源清单SHA-256：`7eac9e2e0fe534d4bc2741662908654190b600b724f3b7cab4a05d04cfa20dec`。
- 综合网表DB SHA-256：`1419fe9a7a56b04307c298ed8b2351237d2f72ddb9dbaf9bbb3f983f661e83a2`。
- seed固定为4；时钟、SDC、IO、双列识别/计数/停车、各列32任务、逐列五连空报警、完整1秒保持和全部四种显示模式均不变。
- 唯一实验变量：物理实现策略从Default改为TD官方CongestionHigh，参数及官方文件SHA保存在 `PHYSICAL_STRATEGY.json`。这会改变布局/布线优化，不能称为“物理策略不变”。
- 原34项软件证据按实际编译输入、测试输入及输出SHA重新验证，`--require-production` 34/34通过；没有重跑未修改的RTL仿真。
- 不烧录、不修改板卡，不推送远端。本轮已结束，无新的可交付bit。

## 对照基线：R50的布局阶段

以下均来自保存的布局数据库及同阶段报告，不是最终布线结果。

| 指标 | R50 Default |
|---|---:|
| 实际Slice | 19994 / 21216，94.24% |
| ERAM / DSP / PLL | 105 / 31 / 5 |
| Setup WNS / TNS | +0.349 ns / 0 ns |
| Hold WNS / TNS | -0.284 ns / -82.542 ns |
| 最后一次估计拥挤top1 / top5 | 96.96% / 90.14% |
| 最后一次估计拥挤top10 / top15 | 85.83% / 82.90% |

`scripts/compare_d3_placements.py` 校验两个保存布局及报告SHA、同一源清单和综合网表，提取全部15个时钟组的setup/hold指标，并比较最后一次布局拥挤估计。估计拥挤降低只能支持是否值得尝试布线，不能证明已经可布通或通过最终时序。

## 执行与决策

1. `reuse_d3_synthesis.py --from-work <R50> --work <R51> --seed 4 --physical-strategy CongestionHigh --prepare-only`。
2. 复用同字节软件证据，运行 `verify_d3_full_candidate.py --work <R51> --suite-map <R51>/SUITE_MAP.json --require-production`。
3. `run_d3_staged_physical.py --work <R51> --stage place`，完成后比较实际面积、拥挤及各时钟组时序。
4. 若布局有实质改善，再从同一个保存的place DB运行一次 `--stage route`；若布局不值得继续，停止在布局阶段。
5. 若完整布线失败，或信号布线出现连续三次overflow与线长同时恶化，保存日志、进程和输入SHA后停止分析。

R50的31次未完成信号布线记录仍保存在原目录与 `docs/D3_R50_ABORT_REASON.json`，不能混入R51作为新结果。

## 实测结果：停止在布局阶段

**CongestionHigh没有提供足够收益，本次不进入完整信号布线。** 布局正常完成，exit 0，用时548.5秒；不是工具崩溃，也不是完整布线失败。保存了独立的place DB、日志和报告，未启动 `--stage route`，没有新bit。当前TD CLI任务为0，settings的阶段设置已恢复。

| 同阶段指标 | R50 Default | R51 CongestionHigh | 变化 |
|---|---:|---:|---:|
| 实际Slice | 19994，94.24% | 20183，95.13% | +189 |
| 剩余Slice | 1222 | 1033 | -189 |
| LUT所占Slice | 14919 | 14910 | -9 |
| 进位所占Slice | 3218 | 3218 | 0 |
| 寄存器独占Slice | 1313 | 1511 | +198 |
| 分布式RAM所占Slice | 544 | 544 | 0 |
| FF | 23105 | 23178 | +73 |
| ERAM / DSP / PLL | 105 / 31 / 5 | 105 / 31 / 5 | 不变 |
| Setup WNS | +0.349 ns | +0.226 ns | -0.123 ns |
| Setup TNS | 0 ns | 0 ns | 不变 |
| Hold WNS | -0.284 ns | -0.284 ns | 不变 |
| Hold TNS | -82.542 ns | -82.041 ns | +0.501 ns |
| 估计拥挤top1 | 96.96% | 95.39% | -1.57个百分点 |
| 估计拥挤top5 | 90.14% | 89.10% | -1.04个百分点 |
| 估计拥挤top10 | 85.83% | 84.99% | -0.84个百分点 |
| 估计拥挤top15 | 82.90% | 82.02% | -0.88个百分点 |

15个时钟组逐项核验，约束周期一致。100MHz组setup从+0.349变成+0.226ns，MIPI字节时钟从+2.377变成+1.524ns，HDMI像素时钟从+2.076变成+2.045ns；各组setup仍满足，hold仍需最终布线修复。不能把“setup为正”或早期时钟布线的overflow=0当作完整签核。

本轮判断依据是取舍：仅获得1.57个百分点的top1拥挤估计改善，却消耗189个实际Slice、使占用超过95%，并损失setup余量，不足以支持再花整轮时间尝试完整布线。这**不证明R51一定布不通**；它说明在当前资源余量和已见证据下，不选择这份布局继续。

资源增量可以精确拆成：`+198寄存器独占 -9逻辑LUT +0进位 +0分布式RAM = +189 Slice`。物理优化后FF还增加73个，说明实现阶段的优化和打包能改变资源，综合网表相同不保证placed Slice相同。仅凭总表不能把198个独占Slice逐个归因于复制、搬移或哪一条网；本次不做没有网表对应证据的推断。

## 保留与下一步

生产RTL继续保留R50已通过34项检查的版本，没有采用任何R51源码修改（本轮也没有RTL修改）。R51作为独立实验保留，四种显示、双列识别/计数/停车及五连空报警均未裁剪。三个受保护BIT_FLASH文件SHA均与运行前一致。

下一步仍建议先做可独立验证的小范围RTL优化，优先核查FSS参考暗度比较的长组合链。本次R51最差placed路径仍是 `ramread16_syn_117.clkb -> reason_bank_reg[63]`，10级逻辑，9.554ns，其中cell 4.925ns、net 4.629ns。与R50的同类路径一致，但仍是**布局估计线索，不能称为R50实际非法布线的确定根因**。

候选方法是利用已有REF_WAIT周期准备dark_word为0..4时的比较结果，REF_CHECK仅用新RAM结果选择；不增加FSM周期、不读取旧RAM数据，完整保留9位及32位表达式语义、阈值相等行为和上下文参考。这仍需原FSS逐像素/逐候选对照、边界检查及实际面积评估，不能先承诺减少Slice或解决全部拥挤。具体只读依据见 `D3_R50_PLACED_FSS_PATH_ANALYSIS.md`。本次没有实施该RTL方案，也没有开启下一次构建。

## 证据

- `docs/D3_R51_PLACEMENT_COMPARISON.json`：两个保存布局和输入SHA、面积拆分、所有15组setup/hold、拥挤快照与差值。
- `docs/D3_R51_PLACEMENT_DECISION.json`：停止在布局的决策、软件/源码状态、源与SYN/place DB和报告SHA、受保护bit SHA、无route/bit/后台任务核验。
- R51目录的 `FIXED_NETLIST_EVALUATION.json`、`PHYSICAL_STRATEGY.json`、`EXACT_SYNTHESIS_REUSE.json`、`SOFTWARE_VERIFICATION.json`、`PLACEMENT_RESULT.json` 保留原始回执。
- `STAGE_PLACE.json`中的 `seed_strategy_clocks_constraints_changed=false` 仅表示分阶段驱动没有再改已经准备好的R51配置；R50到R51的策略改变已在前两份回执中明确记录，不表示两次物理策略相同。
