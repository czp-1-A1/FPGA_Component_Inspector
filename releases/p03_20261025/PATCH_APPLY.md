# P03最小补丁使用说明

完整project/已经是冻结P03，无需再应用补丁。P02_to_P03.patch供其他已经具备完整P02成果的工程参考，只改present_surface_check.v与compact_template_rom.v。新实物验收完成前不要替换已接受版本。

父工程两个文件的换行风格不同，普通git apply的上下文匹配可能失败。已在独立P02两文件副本验证以下命令，应用结果逐行与冻结P03一致：

```powershell
git apply --check --ignore-space-change <P02_to_P03.patch的绝对路径>
git apply --ignore-space-change <P02_to_P03.patch的绝对路径>
```

接收工程存在自己的改动时，需要逐项合并并重新跑功能、资源与实际路由检查，不继承本bit的时序。以上操作不用于发布仓库主源，本轮仅生成本机候选。

首次普通dry-run失败保留cold_patch_check.log；成功dry-run保留patch_check_with_whitespace.log；实际应用只发生在独立临时副本D:/FpgaWork/P03_patch_verify_20261025，没有改主工程或冻结P03。交付包和bit的SHA保持。
