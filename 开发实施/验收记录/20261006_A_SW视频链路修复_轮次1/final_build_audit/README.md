# 最终构建只读审计（2026-10-06）

构建：`tmp/video_fix_td_after_sof_20261006`；未修改工程、约束或发布目录。

- bitgen 已完成：`.bitgen.end.f` 存在，日志有 `Generate bitstream completely`；bit 为 1,789,539 bytes。
- bit SHA-256：`1584f39b53f315c369feb41617539dbbb944b455ae3fe84a045d7824dcfac0d5`。
- inputs.json 的 207 个唯一输入，冻结副本和当前工程的 bytes、SHA-256 全部吻合，0 缺失/错配。
- 最终 Routed/Both(Slow and Fast) 时序：setup WNS +0.310 ns、hold WNS +0.020 ns；setup/hold TNS 均为 0，违反端点均为 0；Period Check WNS +12.200 ns。
- 资源：Slice 16,251（76.60%）、ERAM 48、DSP 8；STA coverage 94.54%。

| 新增 mailbox 约束 | 预算 ns | Total / Dominated | Shadowed / Ignored |
|---|---:|---:|---:|
| u_transport_display payload → D_data | 19 | 68 / 68 | 0 / 0 |
| u_transport_display req → req_sync[0] | 19 | 2 / 2 | 0 / 0 |
| u_transport_display ack → ack_sync[0] | 14 | 2 / 2 | 0 / 0 |
| u_overflow_display payload → D_data | 19 | 64 / 64 | 0 / 0 |
| u_overflow_display req → req_sync[0] | 19 | 2 / 2 | 0 / 0 |
| u_overflow_display ack → ack_sync[0] | 8 | 2 / 2 | 0 / 0 |

约束覆盖报告：no clock=0、clock definition=0、invalid=0、combinational loops=0、no path=0、abnormal input delay=0。既有项仍为 dummy node=4、PLL/clock frequency mismatch=7、shadowed/ignored exception 分类=9、no input delay=39、no output delay=63、partial input delay=1；总体所有 exception 的 Ignored=0，但既有不同范围约束的 Shadowed 非零。六个新增 mailbox 预算无此问题。

综合日志 124 条警告（含 2 条 USR-6135 critical），布局布线日志 10 条警告（含 PHY-5060 mixed camera clock fanout 和 PHY-5079 local clock routing 两条 critical）。类型包括既有 IP/RTL 位宽、未连接/未驱动端口、DDR 加密 MC latch 与异步置/复位、FIFO RAM_STYLE，以及 PLL/clock routing；与先前修复预构建 `tmp/video_fix_td_build_20261006` 相比，忽略 `.v` 行号后的警告文本及计数完全相同，0 新增；未发现 ERROR/FATAL。

结论：本次审计未发现新的构建、约束匹配或 bitgen 阻塞，可冻结为待上板候选。既有厂商/旧工程 critical 警告及 STA 未满覆盖保留，不能据此声称已经上板验收。
