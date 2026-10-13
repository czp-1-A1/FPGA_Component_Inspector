# 首次与复测记录

1. 首次observation单元失败：目的端把tag匹配放在live条件，第一份新tag记录到达才开始稳定等待，消耗其token。修正为独立请求变化触发等待、tag仅屏蔽记录有效位；不改变32拍排空标准。缩小仿真帧时序需先等45个显示拍再发布，第一次重试尚未满足等待的日志亦保留。停CSI/快速往返/恢复均需新完成token。
2. 首次实际ISP编译失败：Verilog模式不接受view_last/sample_cancel前向显式声明，已提前声明并用assign，保留编译日志。
3. TD首轮ADC注释使用//不被ADC命令解释器接受，改为#后新建构建目录重跑；首轮报告保留。没有放松时钟或跨域预算。
4. 7帧集成/OSD定向测试通过后，增强到9帧：覆盖四模式、帧中请求撤旧而视频保持本帧模式、下一原生FS应用与恢复；SW上电已拨上状态另加复位测试。默认16项最终回归是最终通过证据。
5. 默认回归运行时又补充observation单元的同时调参/配置与拨动恢复场景，独立定向重跑通过；其最终compile/console/WLF对应冻结的最新tb_observation.v，补测runner日志另存。没有为此重复慢速真实9帧或TD（DUT未改变）。
6. 检查覆盖报告新增2个no-input-delay（异步SW仍有匹配false-path，不加虚构同步input_delay）和3项shadow。只读导入最终数据库，report_timing_ignored明确SW 2/2匹配、0覆盖/忽略；report_nets显示每个SW仅一个同步寄存器负载。旧monitor req/ack由相同19ns观察显示预算覆盖，camera-display13个payload路径由更严格8ns接收预算覆盖。12项CSI/ROI/SW专用预算全部有效。report_timing_path直接从无同步delay的输入查询告警，不能用它的空结果作为路径证明，实际采用ignored报告。

初次日志不是最终验收。正式分类及实物性能尚未验证。
