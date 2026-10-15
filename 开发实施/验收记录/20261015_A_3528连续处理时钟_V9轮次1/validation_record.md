# 3528连续处理时钟V9验收记录

日期2026-10-15；PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING。用户授权继续生成代码并上传现有任务分支；本轮唯一实现端接续3c13af3交接WIP，原V8现场黑屏记录保持FAIL。

功能：AWB后跨连续100MHz，完整视频帧及同源双结果；原模型/阈值/同一实物保持。215生产输入与本轮source_snapshot一致。17项回归在process_v9_r7_20261015冻结215生产输入后重新执行；最终r8仅精确化SDC选择器，全部RTL/测试/字体SHA同r7；独立参考19图全部通过，原测试条件与答案保持。

TD和CDC：{"timing": {"setup_wns_ns": 0.11, "setup_tns_ns": 0.0, "hold_wns_ns": 0.02, "hold_tns_ns": 0.0, "sta_coverage_percent": 92.79}, "resources": {"slice": {"used": 14414, "total": 21216, "percent": 67.94}, "eram": {"used": 72, "total": 108, "percent": 66.67}, "dsp": {"used": 20, "total": 40, "percent": 50.0}}, "explicit": 38, "vendor": 2, "gray_paths": 20, "warnings": {"syn_1": 125, "phy_1": 12}}。

厂商999.7ns预算不得支撑本轮通过；最终20个逻辑指针位经路由数据库绑定核对，20条匹配路径全部由8ns实际主导。无clock/invalid constraint/loop/no-path问题，完整资源与双角STA通过；厂商/历史告警保留并审计。源码与镜像SHA b954f61ae317896169ae6b7607369d7752a7248a4dd4832c5e9db49b25d26268 一致，实物/端到端恢复未验。

失败历史：V8 r1 RAW可显示但无结果、r2 EDGE缺帧尾；V9r1 UTF8编辑失败后的端口夹具加载失败；r3/r4测试回退等待提前约3.4μs，r5改23ms等待并保持33ms源间隔，全部17项PASS。原失败日志/夹具/生产输入保留，本轮r6新增手写约束被厂商999.7ns项覆盖，审计FAIL；r7改显式Gray FIFO后重跑17项软件及19图独立参考。r7宽匹配集合带入同步附加寄存器，实际约束141路径；r8用转义位总线选择器，仅约束两向20个指针位到第一级同步器，恢复同域自然时序检查，并完成独立路由数据库绑定核对与完整TD。

旧bit SHA全部复核。新发布DA FRAME EXP V9；AI未烧录。现场须复测RAW/四模式/复位/移动/两个有件/P+E/2E/背景/送料孔，不能称硬件黑屏根因闭合。上传结论以随后Git回执为准。打包辅助脚本初次误以为TD-only轮有仿真工作目录，报错和脚本另存packaging_attempts；补充目录缺席处理后重打包，未改变生产源、测试或bit。
