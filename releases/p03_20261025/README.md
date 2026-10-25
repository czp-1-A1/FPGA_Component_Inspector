# P03发布与验证资料

当前成果说明：[P03_HANDOFF.md](../../docs/P03_HANDOFF.md)，逐文件改动及迁移：[P03_PORTING.md](../../docs/P03_PORTING.md)。发布为`p03-standing-review-20261025`预发布，P03实物状态为PENDING。

`INTEGRATION.json`记录独立功能提交、前置P02提交、两处硬件变化和98项未改依赖。`frozen_inputs.json`绑定526静态源；`hardware_inputs.json`绑定100实际依赖；bit SHA为`21d1004fc74505ae7b5ee0c05aadc9c07cb780a2dd0fd763115b3796def060db`。

`EVIDENCE_INDEX.json`逐项绑定31组软件证据；`evidence/classified_audit/`为原SDC/seed2真实Routed双角时序与完整CDC审计，`evidence/physical/`为最终资源与配置；`evidence/cold/`为冷解压复算及新目录单元重放记录。旧错误与复测在完整包中分别保留。

`LOCAL_DELIVERY_RECEIPT.json`、`FIELD_GUIDE.md`是最初本机候选交付时的历史收据，内含“未发布/主源P02”等当时措辞；当前源和发布状态按上方入口、FIELD_FEEDBACK和上传回执。`public_package.json`绑定公开完整包及原本机ZIP，不混用SHA。手机原始视频、照片和个人源路径清单留本机，公开完整包保持原526源/bit及全部合成验证资料。

复原/验收命令在仓库根执行`python scripts/p03/verify_p03.py`和`prepare_p03.py`，详见交接页。原P02用户“测试正常”不等于P03实物通过；不同接收工程必须重新做功能/实际路由/实物验证。
