# 本轮工具调用记录

1. 首次ModelSim启动将Tee-Object日志设为相对路径，runner的Push-Location导致日志目录解析错误，未得到完整回归。终端出现`Could not find a part of the path ... sim/tmp/modelsim_probe/...`。此项只保留调用观察，未保存完整原始日志，不补造失败波形。改用绝对日志路径后默认12项完整回归通过；未改DUT或放松断言。
2. 首次TD调用带`-f build.tcl`，工具报`wrong # args: should be "source ?-encoding name? fileName"`，没有执行综合。原始日志在td/syn_1/build_console.log。按TD接口直接传build.tcl后重跑，最终综合日志为td/syn_1/build_console_retry.log；以.opt_gate.end.f和最终报告确认完成。

这两项是命令/日志路径问题，不能作为RTL失败或通过证据。上级modelsim和TD最终报告属于本批冻结输入，旧release未修改。本版尚未上板。
