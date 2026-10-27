# FPGA载带识别与计数 R23

当前分支`r23-present-trace-20261028`：在R22上加入动态有件被动诊断，保持原分类判据、计数和局部恢复。**R23尚未修复现场误复核，等待诊断视频。**

- [另一AI接棒说明](docs/R23_HANDOFF.md)
- [当前交接入口](HANDOFF.md)
- [完整源码/bit/证据包](releases/r23_20261028/)
- [生产工程](fpga/component_inspector/)

先运行`python scripts/r23/verify_r23.py`。151软件、53独立参考和独立归档审计通过；最终Slice89.6022%、ERAM101/108、setup+.002ns/hold+.020ns/TNS0。实板尚未验收，R22正常速度反馈不等于R23通过。旧分支、release和Example保留。
