# P02 已测试版本发布

用户在本轮交付后反馈“测试正常”。P02在R13上修复正常有件全部进入复核的问题，保留原几何/填充、弱T80和计数功能；完整说明见 [交接](../../docs/P02_HANDOFF.md) 和 [跨工程迁移](../../docs/P02_PORTING.md)。

- 分支：`lj4747-contest-work`
- 功能提交：`b549237f15aafd3e3979b53f9df88b6877651e27`
- 发布标签：[p02-present-surface-20261024](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/p02-present-surface-20261024)
- [bit](P02_PresentSurface_1092_40_r0_20261024_dfd2e5c8.bit)，SHA `dfd2e5c8f7081f32f526be0b9e02e754649f1509d872e7cd12aac4ffba9199b8`
- [完整工程/合成测试/实际路由验证包](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/download/p02-present-surface-20261024/P02_PresentSurface_1092_40_r0_20261024_dfd2e5c8_github.zip)，85106059字节/1245项，SHA `cf36dc1e157821609fb12d917005326b66ee3bbee87ec1ea698472e5ae3ee78e`
- [冻结504源](frozen_inputs.json)、[硬件100依赖](hardware_inputs.json)、[完整功能差分](R13_TO_P02.patch)、[验证证据索引](EVIDENCE_INDEX.json)、[字段和烧录操作](FIELD_GUIDE.md)、[用户反馈](FIELD_FEEDBACK.json)、[校验值](SHA256.txt)

原始拍摄素材及个人来源路径留在本机；公开包的bit/冻结源和合成验证/真实路由证据保持相同。原本机完整包的回执保留为LOCAL_DELIVERY_RECEIPT.json，公开包身份以public_package.json为准。旧收据中的未上板字段属于交付时状态，人工反馈由FIELD_FEEDBACK补记；最终上传状态另见GITHUB_UPLOAD_RECEIPT。

当前Routed Slice18266/21216、ERAM103/108、DSP28、PLL5；双角setup+0.005ns、hold+0.020ns、TNS0，完整46约束/20Gray/6邮箱/SW3通过。源/载荷校验执行`python scripts/p02/verify_p02.py`；这不是重新仿真或编译。用户总体反馈不替代未提供的速度/光照量化矩阵。
