# V11 r9 约束与工具告警审计（2026-10-15）

冻结原包r8使用TD6.2.168116；本机r9使用TD6.2.178840。r9唯一生产RTL变化是小帧Y坐标最小10位，生产1080行仍为11位。SDC逐字节与原r8一致，没有放宽时钟、跨域预算或例外。

本机最终路由：双角setup +0.117ns、hold +0.020ns，STNS/HTNS为0，工具STA覆盖率92.89%。Slice14724/21216=69.40%，ERAM94/108、DSP26/40、PLL5/6。资源变化包含工具版本与映射差异，不能归因于坐标修复带来优化。

## 约束与Gray逐位映射

- 路由DB独立重开后导出 `audit/exceptions.timing`、`constraint_coverage.txt` 和20个 `gray_*.timing`；执行入口 `audit_routed.tcl`，退出码0。
- 38条用户显式max-delay与2条厂商FIFO max-delay都须匹配非零路径，Ignored=0。较宽clock-to-clock约束被更紧的对象约束覆盖属于Shadowed，单独列出，不能当Ignored。
- TD178840将6条共用物理寄存器的别名约束打印为没有数字的续行；按同一物理路径组继承数值后，38条显式命令逐条都能在报告中找到，合计仍严格要求40条，不把34个数字行误当6条约束丢失。
- 异步处理FIFO的write/read各10位经get_regs逐位解析，8ns约束对20条路径全部主导，shadowed0/ignored0。逐位报告包括8.000ns预算、真实数据延迟、正slack、逻辑网名与物理cell。
- bit9等于二进制指针最高位，因此综合别名为write_bin/read_bin[9]；低位Gray寄存器会与其他寄存器共用物理slice。不能只按物理cell名字推定缺位；本轮同时核对get_regs映射及每条报告的Gray源/目的逻辑net标注。
- 20条实际数据路径延迟最大1.099ns，远小于8ns预算。自动核验记录在 `verification.json`；该文件须待全部28项回归结束后生成通过状态。

## 告警比较与解释

不是零告警版本；保留全部原始日志。

逐条比较基线是本次实际交接的冻结r8完整报告。包内V10只提供旧bit和文字摘要，本机没有da19583 Git对象或V10原始TD日志，因此不声称完成V10→V11的逐条告警差分；该历史证据缺口明确保留。本轮发布依据为实际r9完整约束覆盖、逐位CDC预算、最终路由及全部回归，不能用旧文字摘要代替这些新报告。

| 项目 | 原r8 | 本机r9 | 解释/证据 |
|---|---|---|---|
| no-clock/clock-definition/invalid-constraint/loop/no-path | 0 | 0 | 最终check_timing报告 |
| PLL/clock buffer检查 | 7 | 7 | 沿用DDR时钟元数据不一致；HDMI新PLL未报频率不匹配 |
| dummy node类别数 | 4 | 2 | 工具映射/诊断归类改变，辅助常量端口等仍保留明细 |
| shadowed/ignored constraint类别检查数 | 10 | 4 | 最终40条max-delay的Ignored仍为0；20位8ns全部主导 |
| 无input delay / 无output delay / partial input delay | 39 / 63 / 1 | 39 / 63 / 1 | 继承原工程I/O约束边界；不能声称100%端到端板级时序覆盖 |
| USR-6001 No clocks matched | 0 | syn12 / phy6 | 本机新增类别，出现在早期start_timer、厂商IP约束导入/时钟重命名前；最终时钟表具备MIPI/DDR/HDMI时钟，全部40条约束匹配，no-clock及invalid-constraint均0，不是被遗漏的最终约束 |
| PHY-5060 mixed clock/data fanout | phy1 | phy1 | 相机24MHz时钟反馈结构，原工程已存在；原始表格保留 |
| PHY-5079 local clock routing | phy1 | 0 | 本机工具最终路由未报此类；完整clock分析保留 |
| USR-6135 PLL feedback local network | syn2 | 0 | 原机综合阶段报告，本机未报；不以告警消失推定实板验证通过 |
| HDL/SYN警告类别与次数 | 原值 | 相同 | 未驱动/被优化端口、既有位宽等全部保留，不改警告级别或屏蔽 |

最终时序覆盖与历史DDR/PLL/I/O边界均随包披露。物理MIPI、DDR、HDMI、冷启动和温度/供电影响仍由用户现场验证；220mm几何/阈值没有新真值样本，不判标定通过。
