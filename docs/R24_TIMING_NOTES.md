# R24物理候选记录

所有候选沿用原器件、speed3、时钟和完整SDC；未放宽约束。负时序候选没有进入交付目录。

| 候选 | 实际Routed建立/保持余量(ns) | 处理 |
|---|---|---|
| 原双列seed2 | -0.257 / -0.116 | 拒绝 |
| 原双列独立ultra reroute | -0.248 / -0.116 | 拒绝 |
| 原双列seed3 | -0.412 / +0.020 | 拒绝，报告保留 |
| C1提前寄存critical界限 | 未跑完整物理/RAW | 只做隔离试验，未采用 |
| C2 seed2完整路由 | -0.293 / +0.020 | 拒绝，留存原DB |
| C2 post-route reroute ultra | -0.231 / +0.020 | 继续优化 |
| C2再经relocation high及自动reroute | +0.002 / +0.020 | 最终采用，双角TNS0及全部约束审计通过 |
| C2 seed3 | 未完成 | 主候选通过后停止，未认定通过或失败 |

原seed2最差建立路径为第二区计数器pitch→match_step→critical界限→轨迹控制；C2用逻辑包含关系排除RECOVERABLE模式下已被前序分支处理的后备分支，删除无用DSP路径。没有改变分类阈值、计数答案或事件周期。C2重新综合后DSP为28，原版29；最终Routed资源为Slice18460、ERAM101、DSP28、PLL5。

原HDMI保持违例的5个隔离ECO移动均为Successfully moved0，不能当作修复。慢速显式relocation优化已停止，也不是验收通过。原完整RAW12源帧/11结果/1取消已过，但不能代替C2完整RAW重跑。失败报告见`validation/r24/failures`及原工程目录。

只有实际Routed双角SWNS/HWNS非负、STNS/HTNS均为0、46个max_delay/20个Gray位/6组计数邮箱/SW3同步与覆盖审计通过，才允许最终bit归档。独立复原只重算归档身份、参考和已完成物理证据，不冒称重新综合布线或实板验收。

最终bit SHA256 `0ce9f60635aa00f2318eb04403e604f166e92a6770606ed323bddc0549f29e20`。完整物理报告在独立build证据目录；没有改任何已执行RTL/测试答案/SDC，未进行实板验证。
