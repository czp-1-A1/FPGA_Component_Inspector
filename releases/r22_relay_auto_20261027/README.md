# R22自动空穴停车联调版

识别基线a1cceaa，分支codex/r22-relay-v1；新版本见RELEASE.json，先读FIELD_GUIDE.md。
20项软件测试实际执行、完整双角布线和49条延迟约束/20条Gray/9组邮箱审计通过；毫米定位和板载5V负载仍待人工实测。8个EMPTY队列，向右，实测位置确认后保持1秒，故障保持停止。没有吸嘴动作或补件成功判定。

烧录根目录R22_RelayAuto_V1_20261027.bit。baseline/保留原R22回退bit。project/为完整源及测试；SOURCE_SHA256.json绑定每个文件。build/为历史真实构建DB/配置/报告，不是现场实测证据；历史绝对Path不直接作为跨机重建入口。

在新的全英文短目录重建，不覆盖发布包或旧工程：

```
python scripts/build_r22_relay.py --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/R22_Relay_rebuild --td E:/TD
python scripts/relay_r22_checks.py --source project --out E:/2026FPGA/R22_Relay_sim --modelsim E:/Modelsim/win64
```

原R22回归入口project/sim/run_modelsim.ps1，传入-ModelSimBin及-TdSimRoot。真实生产1秒测试使用100MHz默认参数；编号流水线集成用缩短保持参数以检查身份/队列时序，不把缩短参数测试当真实1秒。UI与队列的独立测试台在project/sim，原始编译命令、日志和字节身份在tests/；原R22的144项历史验证没有作为本候选重跑数重复计入。
