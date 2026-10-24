> 历史R13说明：当前分支工程已推进P02。当前入口为仓库docs/P02_HANDOFF.md；R13源校验请在r13-compact-resource-20261023标签的新checkout执行，原发布包保持不变。

# R13当前入口

本目录的471项R13冻结输入以[R13_FROZEN_INPUTS.json](R13_FROZEN_INPUTS.json)为准。
请先读仓库根目录[README](../../README.md)和[完整交接](../../docs/R13_HANDOFF.md)。

其他README保留历史原字节，部分旧按键/失锁/速度边界与当前生产参数不同，不作为R13操作规范。
先运行`python scripts/r13/verify_r13.py`，再用`prepare_r13.py`复制471源到新ASCII目录。
旧Runs/旧handoff不是当前构建输出；不可把所有旧RTL按glob一起编译。
