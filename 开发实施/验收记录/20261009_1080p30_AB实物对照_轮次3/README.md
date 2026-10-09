# 首封包元数据错误保留

metadata_r0是本轮未发布的首封包，完整字节与原SHA清单保留。其diagnostic.json误取placement中间WNS+0.928/+0.051，不能当最终布线数据；最终应为+0.134/+0.026。bit与正式C为同一SHA，原始最终TD报告和冻结输入也相同。封包解析及校验工具已修正，正式交付仅使用 `fpga/component_inspector/release/native_1080p30/sync_aligned_diagnostic_20261009`，不要从此目录选择交付或烧录文件。

详细经过、测试结果和当前人工门槛见同名轮次3验收记录。此保留件不是新增RTL失败或新的实物测试结果。
