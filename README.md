# FPGA载带识别与计数 R22

当前分支`r22-local-edge-20261027`：灰度＋局部Sobel联合识别、固定ROI计数和局部恢复。用户已报告**正常速度稳定**，高速仍待进一步验证。

- [另一AI接棒说明](docs/R22_HANDOFF.md)
- [当前交接入口](HANDOFF.md)
- [完整源/bit/证据包](releases/r22_20261027/)
- [生产工程](fpga/component_inspector/)，TD入口`td_project/camera_to_dsi_display.al`

先执行`python scripts/r22/verify_r22.py`。144软件、46参考及真实路由/独立归档验证通过；Slice89.63%，ERAM101/108，setup+.001ns/hold+.020ns/TNS0。不能把这些结论当作所有速度实板通过。

旧R19/P03/P02/R13的release和固定标签保留；当前R22完整说明优先。
