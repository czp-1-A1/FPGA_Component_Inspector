# AlarmRoles V3仅空穴自动停车验收

用户指定904a2bb0版本，基于真实克隆codex/rl7-v3-alarm-roles/
904a2bb053a9e679b3f50378ca3163a55698b20e；先核对分支/HEAD/暂存/未提交文件，
新建codex/rl7-alarm-roles-empty-only-20261102。旧工作区/源/bit/ZIP不改。

仅三生产源变化：top、isp_top参数传递和pocket_relay_stop_v2；635份原源保持。
旧停车策略按差异移植，未覆盖V3控制器或OSD。V3独立报警账本和无效序列
失效规则保持；额外保证运行故障转FEED后，第五空仍保留首次故障上下文。

| 验证 | 结果/证据 |
|---|---|
| 新控制策略+V3联合 | checks_r0：20940检查PASS |
| 历史控制兼容 | checks_r0：65断言PASS，EMPTY_ONLY_STOP=0 |
| 四键/CDC/SW3 | checks_r0：27检查PASS |
| 生产100MHz完整一秒 | second_r0：生产100MHz完整100000000拍保持/一次完成PASS，全部编译输入SHA同最终源 |
| V3原报警/像素/全空RGB | roles_r0：原报警碰撞/21报警蜂鸣检查/18栅格66355200参考像素对/无P全空RGB四合同实际PASS |
| 原生视频 | native_r0：12RAW/24精确显示栅格/22940496像素/25时间绑定/OFUF0实际PASS |
| 实际物理 | build_r0，V3 seed1/原SDC，Routed Slice18903/21216 ERAM98/DSP30/PLL5；setup+0.100ns/hold+0.020ns/双TNS0，50maxdelay/20FIFO及64时间Gray/实际V2 C12完整审计PASS |
| 实板 | 未测，无板卡/JTAG/Flash/电机/用户GUI操作 |

冻结输入、实际编译和运行日志分别保留；后续失败另存，不能边测边改测试答案。
原生/真实一秒夹具仅启用参数和改模块名，其他刺激/断言同原夹具；V3原有合同不改。
最终交付/独立归档恢复/桌面SHA/远端核验见交付和上传回执。
识别/编号失锁本身不在本轮修改范围，不声称实物准确率或故障漏检已解决。
