# P02接棒

当前入口：[P02完整交接](docs/P02_HANDOFF.md)。跨工程沿用先读[逐文件改动与迁移](docs/P02_PORTING.md)，然后读[AGENTS.md](AGENTS.md)。

分支lj4747-contest-work，用户反馈P02“测试正常”。建议移植功能提交b549237f15aafd3e3979b53f9df88b6877651e27；源码、bit、资源/时序和证据身份见releases/p02_20261024/。正式标签p02-present-surface-20261024，完整验证包作为GitHub Release资产提供。

先核对git status/分支/HEAD，再运行python scripts/p02/verify_p02.py。使用prepare_p02.py在新英文短路径复原，不覆盖其他工作。原R13标签/发布和P01回退保留；旧current指针、旧CAL语义和旧运行PID不是当前答案。

按当前文档保存源码/bit SHA及人工真值；工具/许可证/板卡不随Git传输。只有源/归档/历史证据校验通过，不能称重新编译或实物量化验证通过。用户总体反馈记录在FIELD_FEEDBACK，不扩大为所有速度/光照保证。
