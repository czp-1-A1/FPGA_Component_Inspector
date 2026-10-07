# 独立 VI / VO 稳定性回归

日期：2026-10-06。独立测试端仅修改本 tmp 目录。工程 RTL 由 root 实现端修改；本测试无工程写入、综合、JTAG 或发布操作。

最终复测：VI publication 条件加入 `!S_frame_start` 后，19:22 的缩尺寸与完整尺寸重新运行均 PASS，数值与下文一致；最终验证源哈希已更新。前轮通过不代替该最终复测。

## 运行方法

仓库根运行：

- `./tmp/io_fix_review_20261006/run.ps1`：32×161 边界/恢复测试，共 966 个 packed 128 位字，最后 burst 仅 6 字。
- `./tmp/io_fix_review_20261006/run.ps1 -FullRaster`：1024×600 完整传输与显示测试。

实际工程 video_in、video_out 与实际 w128_d512_fifo 参与测试。MC 为有序命令/返回行为模型，没有 DDR PHY；最终 O_wr_en/O_rd_en 当拍接收，ready 低允许 8 个额外命令，不对最终 en 再门控 ready。每次运行的日志保留于 attempt_* 目录，最新 console.log/transcript.log 为完整尺寸测试。

## 结果

### 缩尺寸异常/恢复：PASS

- 冷启动无 completed：5152 个可见像素全黑。
- 四次完整发布分别为源帧 1/3/5/6；每次 966 个实际 MC 写入字、所有地址连续、内存内容逐字相符。
- 帧 1、帧 3、最终恢复帧 6：每幅 5152 个显示像素全部匹配，x/y 无累计偏移。
- 400 字短帧期间新 FS 撞 DDR 写事务，短帧不发布，后续源帧完整恢复。
- 输入无法回压、MC ready 暂停时 FIFO full：overflow_frames=1，坏帧未发布，capture_ok 撤销；下一完整帧恢复。
- mid-display 返回暂停导致 empty：underflow_frames=1，故障后余下 2592 像素全黑，未继续显示错位数据。
- 新源帧 6 写完而旧显示 DDR 返回仍暂停：新 VS 未切换 pinned 槽，也未发送新 read 命令；恢复旧返回后排空、复位、预填，整幅帧 6 正确。
- 每个 MC 写入检查不得覆盖当前 active 槽及最新 completed 槽。
- 总计 3957 次实际 MC 写入，3618 个 read 命令及对应返回，25760 个显示像素比较，lost=2/overflow=1/underflow=1。

### 完整 1024×600：PASS

每行模拟 packed 输出 192 字，按连续 3 字有效/1 拍空闲产生，共 256 CSI 拍，再 512 CSI 拍空闲；输入不等待 camera_ready。源帧中点加入 ready 低 300 个 DDR 拍。

实际写入、读命令、返回均为 115200 字；全部 MC 写地址和内容逐字校验，614400 显示像素逐一匹配，black=0/overflow=0/underflow=0。有限暂停没有发布半帧。

## 保留失败及修正

- `attempt_initial_fs_failure`：第一版 VI 在 CSI FS 立即 reset FIFO，但已有寄存 MC write 尚未消耗，导致 word 91 被写为全 0。测试将证据反馈实现端；实现端改为 DDR 同步帧边沿先停止管线，再 reset FIFO，后续该刺激通过。
- 后续两次失败为 TB 自身刺激：underflow 用例从 DDR negedge 启动 DE，首行可能只有 31 个有效 pixel edge，导致下一行预期 index 31 对实际 index 32。只修测试 DE 起点至 pixel negedge；保留失败日志，不将其当 RTL 缺陷。
- ModelSim `-onfinish exit` 在 `$fatal` 后仍可能返回 0。runner 同时检查 Fatal 和显式 PASS 标记，避免返回码导致误判。

IP 自带未连接辅助端口与端口宽度告警保留（ModelSim vopt 缓存不同可报 4 或 7 条）；当前运行 0 错误。未降低检测目标或修改工程 IP。

## 限制

本测试直接给 video_in 已打包 128 位源流；字节排列由独立函数生成。没有 ISP、Sobel、真实 MIPI、OSD、物理 DDR 控制器或板卡，不能据此宣布全工程或现场通过。四种 SW 模式的真实 ISP/打包链路仍需实现端整体回归和用户上板。

## 最终 top / ISP / CDC 只读审核

- top 新增 `u_transport_display`：DDR 源 `{capture_ok,lost_frames}` 共 17 位到 HDMI；`u_overflow_display`：CSI 源 overflow_frames 共 16 位到 HDMI。display_ok 和 underflow_frames 已在 HDMI 域，不需要再次多位异步采样。
- `transport_ok=transport_display[16] && display_ok` 进入 roi_display_state 的 cfg_done。故障会清 armed/token，恢复需要原 32 拍稳定窗口和新统计 token；不是仅在 OSD 最终有效位上门控。
- OF/VF/UF 三个 16 位计数在显示 VS 快照，用既有 ASCII ROM 输出四位十六进制；Logo、字体资源与主 ROI 范围没有改变。
- ISP 输出 video_frame_good/bad 按 AWB early FS epoch 清除，roi_commit 提供采集完整性证明，Sobel cache_overrun/config/lane/guard 错误撤销。native FS 本身不无条件撤销已完成的旧尾。传输计数不能替代采集 guard。
- SDC 已去掉 DDR blanket clock-group cut；CSI→DDR 14 ns、DDR→CSI 8 ns、DDR→HDMI 19 ns 物理 max-delay 覆盖新增同步与 FIFO 交叉路径。
- 两个新 status_cdc mailbox 均有 payload/req/ack 三条预算：transport 为 19/19/14 ns，overflow 为 19/19/8 ns。19 ns payload 小于 HDMI 两级 token 到 capture 的 38.46 ns 最小稳定窗口；req/ack 进入首同步级。
- 源级约束结构与连接完整。该审查不能证明 TD 的 get_regs/get_clocks 实际集合匹配、约束未忽略、布局布线 setup/hold 通过，必须由最终 TD 报告核对。

这部分是只读逻辑/约束审查，不是 top/ISP 仿真。审核源哈希独立列在 review_source_hashes.json，避免与 transport 仿真通过混淆。
