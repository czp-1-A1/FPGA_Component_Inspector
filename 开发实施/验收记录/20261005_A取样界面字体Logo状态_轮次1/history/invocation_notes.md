# 工具调用与测试修订记录

1. 首次TD误启动GUI td.exe，未执行综合，build_console.log为空。只关闭本轮新启动PID5644，未结束用户旧TD。随后使用td_commands_prompt.exe直接传build.tcl，最终综合为build_console_retry.log，物理阶段为phy_1/build_console.log。
2. 添加runner条目时字符串替换误触OnlyTests过滤表达式，首次定向调用只执行stop_recovery，未执行roi_chain。sample_ui_integration_console.log保留；修复过滤后定向两项通过，再执行默认完整14项，数量和每项最终PASS分别核对。
3. 初次停流边界测试第一场景停在已归零窗口，输出0参考拍，不能用作最坏边界证明。增加“停流前必须FPS非零”断言并将第一相位移至窗口150/1000，最终两相位分别1850、1020参考拍；此为增强测试，未放宽断言。
4. apply_patch首次拒绝同一文件的delete/add合并操作，未修改RTL；拆为顺序操作成功。没有本轮DUT断言失败或降低时序目标，约束未改变。

以上首次日志只保留历史，不当作本批最终通过证据。modelsim/regression_console.log和td最终报告属于最终203输入/.al。
