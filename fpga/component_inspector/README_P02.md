# P02 当前工程入口

本目录当前采用用户反馈“测试正常”的P02：在R13上增加同帧内部表面分类，解决正常有件全部进入复核的问题，保留原尺寸/比例/填充、弱T80复核及计数逻辑。原R13可从`r13-compact-resource-20261023`标签和原发布包恢复。

- [完整交接与构建说明](../../docs/P02_HANDOFF.md)
- [逐文件改动、接口和跨分支迁移](../../docs/P02_PORTING.md)
- [冻结504项源清单](P02_FROZEN_INPUTS.json)
- [实际100项硬件依赖](P02_DESIGN_INPUTS.json)
- [P02操作和五姿态复拍说明](P02_FIELD_GUIDE.md)

仓库根目录运行`python scripts/p02/verify_p02.py`，再用`prepare_p02.py`在新英文目录恢复工程。工程只编译`.al`清单及其已核对依赖；本目录还保留历史文件，不能用整个目录glob代替当前编译清单。旧README/P01指南是历史快照，当前按P02交接和P02字段定义使用。

bit本机统一放`D:/fpga_download/`；GitHub身份和下载入口见[发布说明](../../releases/p02_20261024/README.md)。
