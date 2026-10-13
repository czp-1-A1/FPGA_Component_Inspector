# 中间失败与未发布结果

以下前两项是会话终端观察摘要，原工作目录compile/console/WLF被后续复测更新，不能当作完整冻结失败波形。相关runner输出能保留的部分位于本history目录，不补造原始日志。

1. 首次改动脚本在换行匹配失败后续跑，roi_statistics重复声明sample_new；ModelSim报告 `sample_new already declared`，未进入ROI测试。重复声明已修复，最终编译通过。
2. 人工测试检查27位异步邮箱后未重新对齐CSI时钟，导致FS脉冲不足以跨源时钟边沿。终端报告 `state frame 4 expected=1 got=2 fs=0 child_fs=0 cancel=0 fresh=1`，Time 19951ns。测试刺激改为在negedge clk驱动并保持完整周期；最终测试通过，没有放松期望状态。
3. 初次隔离TD仅复制.al直接引用的59项文件，缺少间接IP依赖，open_project返回PRJ-8644。原始完整TD日志与设置保留td_missing_inputs，补齐旧197项清单及新增classifier后重新构建。
4. 新帧开始时清除旧统计的中间实现完成过综合及7帧仿真。随后细化为保留最近完整调参统计、取消未完成计算，另建最终目录重新综合/布局布线并复测。superseded_synthesis只作中间记录；其198项哈希位于superseded_build_inputs.json，与最终不同的源文件保留superseded_source，其余与最终快照相同。此中间配置没有发布bit。

最终通过证据使用上级modelsim/及td/，交付版默认未标定，实物未测。
