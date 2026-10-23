# R13接棒

当前入口：[完整工程交接](docs/R13_HANDOFF.md)。读根[README](README.md)、[AGENTS](AGENTS.md)后再动代码。

工作分支`lj4747-contest-work`，冻结标签`r13-compact-resource-20261023`。先`git status --short --branch --untracked-files=all`、`git log -1`、`git remote -v`，确认前一实现端停止。

运行`python scripts/r13/verify_r13.py`核对471输入与正式载荷，再运行`python scripts/r13/prepare_r13.py --work D:/FpgaWork/R13_replay --td D:/td6.2.1`恢复新工程。构建/测试/状态/位域/现场真值要求见完整说明。保持冻结答案独立，不把历史默认参数、旧README按键或HDMI刷新率当生产状态。

源码、bit、ZIP及说明均在本仓库；TD/ModelSim安装、厂商库和许可证由接手电脑提供。无板卡操作或自动恢复任务。旧交接说明保存在[历史文件](docs/history/HANDOFF_before_R13_479a30b.md)。
