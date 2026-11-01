# 当前交接：R57（2026-11-02）

以 [R57 交付说明](docs/R57_DELIVERY.md) 和 [冻结交付](releases/r57_dense_dual_20261102/) 为当前入口。生产代码仅三文件变化，704 个源输入逐 SHA 匹配已验收构建。下一步为实板验收。以下为历史交接。

---

# 当前R22接棒

请先读[docs/R22_HANDOFF.md](docs/R22_HANDOFF.md)。本分支为R22精确冻结源码与完整证据，用户已反馈正常速度稳定，高速待验证。

运行`python scripts/r22/verify_r22.py`核对源码与交付包。保留旧版本标签和release；其他分支不受此次上传影响。
