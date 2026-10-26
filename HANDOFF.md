# R19接棒

当前源：fpga/component_inspector；分支lj4747-contest-work，固定标签r19-robust-empty-20261025。先读[完整R19交接](docs/R19_HANDOFF.md)和[现场反馈](releases/r19_20261025/FIELD_FEEDBACK.json)。

112软件/26独立参考/真实路由与完整约束通过；现场正常速度空穴仍有漏计，不能称已实板通过。接收新反馈时保留冻结镜像与真值，不能边测边换代码。先核对Git分支/HEAD/未提交和运行端，再决定是否继续分析或另冻新版本。

运行python -B scripts/r19/verify_r19.py（完整归档核验加--archive），prepare_r19.py仅在新英文目录复原559源/101依赖与seed2，不自动构建或烧录。源码清单、bit/ZIP SHA、源变更、日志与原始证据见releases/r19_20261025。GitHub普通推送与独立远端复核回执见该目录GITHUB_UPLOAD_RECEIPT.json（源码88855ce已普通推送，GitHub独立下载559源/bit/公开包及工程复原核验通过；标签固定源码提交）。旧P03/P02/R13标签和发布保留。
