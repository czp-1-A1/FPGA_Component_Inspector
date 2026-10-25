# P03接棒

当前源/发布入口：[P03_HANDOFF.md](docs/P03_HANDOFF.md)。跨工程沿用先读[P03_PORTING.md](docs/P03_PORTING.md)，再读[AGENTS.md](AGENTS.md)。

分支lj4747-contest-work。P03功能提交9d4596885b29559f0bb5ed873464c6964cc53b1a；已有P02的工程合入该增量，从R13等旧基础先合P02功能b549237f。P03软件/真实Routed通过、实物待反馈；P02“测试正常”只属于P02，旧标签/发布保留回退。

先核对git status/分支/HEAD，再运行python scripts/p03/verify_p03.py。prepare_p03.py在新英文短路径复原526源/100依赖及seed2，不覆盖已有工作。完整包、bit/源SHA、原始证据和上传回执见releases/p03_20261025/。

冻结源中的最初本机P03指南可能写“未发布/主源P02”，属于历史快照；当前状态按P03交接、INTEGRATION、FIELD_FEEDBACK和GITHUB_UPLOAD_RECEIPT。工具/有效许可证/板卡不随Git传输。不同工程需独立验证；本次未替用户烧录。
