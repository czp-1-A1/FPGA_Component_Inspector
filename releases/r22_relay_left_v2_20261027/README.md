# R22 右计数、左补件 V2 联调交付

先读 FIELD_GUIDE.md；当前 RUN 必须从计数线左侧及补件区无未编号料段的状态开始，人工设置屏幕右向左。继电器及其他引脚沿用V1。参数为处理图像像素，尚未实板标定±1mm。本版不驱动吸嘴。

23项选定软件测试及最终布线数值证据在 VERIFICATION.json。新布局停车闭环为完整1280×720处理RGB像素；最终生产分支另实跑12帧原生RAW10 MODE1，用明确可识别的RAW360孔形成4个已知P/E编号、2个空穴队列、到站前超过150ms继续送料，含原始解码/DDR及精确显示像素核对。另一个RAW280弱反光输入失败，见WEAK_NATIVE_BOUNDARY.json及tests/retained_boundary；第6源帧的像素回放在原R22与本版结果逐位相同，原识别边界仍然存在，没有把它算作通过。RAW控制测试没有运动至停车线，不称作原生RAW停车闭环或实板验收。原基线RAW编译时ISP尚未加入类别核对，差异仅位于关闭的AUTO_RELAY分支，保留了历史编译源，另有最终开启分支的新RAW测试。左右类别顺序不一致停止；连续同类穴位完全漏检不能单靠计数在数学上排除，需已知料序验收。

从新的短英文目录重建，不在冻结包内运行或覆盖：

```
python scripts/build_r22_relay.py --left-v2 --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/R22_Left_rebuild --td E:/TD
python scripts/relay_left_checks.py --source project --out E:/2026FPGA/R22_Left_sim --only tb_relay_left_faults tb_relay_left_transport tb_relay_left_rgb tb_relay_left_real_second tb_relay_left_pixels tb_relay_left_osd
python scripts/relay_left_native_check.py --source project --out E:/2026FPGA/R22_Left_native
python scripts/audit_r22_relay.py --left-v2 --work E:/2026FPGA/R22_Left_rebuild
```

工程project/含628项构建冻结源和1项后加的原生RAW测试台，共629项；后加测试台不改变构建硬件源。原R22回退bit在baseline/。build/为本机实际构建DB/日志/脚本历史，不直接用其历史绝对路径替代上述重建命令。原相机/计数/显示回归入口为project/sim/run_modelsim.ps1，按本机路径传-ModelSimBin和-TdSimRoot。PAYLOAD_SHA256.json绑定全部归档载荷。
