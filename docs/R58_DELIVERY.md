# R58 双列蜂鸣器报警与真实采集到输出延迟（待实板验收）

基于已发布 R57 `02b18c34`。完整设计、接口、参考包审查和实板操作见 [交接说明](docs/R58_DESIGN_AND_HANDOFF.md)。

- 任一列连续五个有效空穴锁存报警：电机停止，C12 低有效蜂鸣器输出 2kHz，响200ms/停300ms循环；接通板载SW5。K3清零或明确新RUN解除，K2/K4保留报警。生产接线将局部定位故障与真实坏帧分开，同拍第五空穴不会被局部故障屏蔽；局部故障停机和真实坏帧保护保留。
- 右上角蓝色 LAT/LAG、粉色 SRC，16×32 字号。LAT 是同一采集帧 RAW SOF 到本次 OSD 后 HDMI 首有效像素的帧龄，0.1ms显示；SRC是视频来源号，与穴位编号独立；LAG是最新来源号与显示来源号的差。重复帧重新计时；无效/未来/过期标签显示横线。
- 数值包含采集SOF之后的读出、ISP、帧缓存、等待和扫描，不包括之前的曝光、HDMI后端及面板响应，也不是单独识别算法执行时间。预览来自实际RTL仿真。

## 验证

最终源码对应25项验证，其中5项未受接线修正影响且输入SHA相同的本轮结果保留，20项重新执行；不复用旧R57通过结论。另有560640文字区RGB及第二列112字形行独立比对，包含完整RAW、真实DDR/FIFO/相位/OSD、生产五连故障碰撞及旧接法负对照。冻结705个源输入，13处文件变化，R57密集检测器和主计数器保持。

最终Routed双角：setup +0.105ns、hold +0.020ns，双TNS0。44条有效最大延迟约束、精确9条原有已移除显示约束、原20+新64位Gray、邮箱、SW3/四键、V2电机和C12蜂鸣器实际映射/路径审核通过。原时钟及原SDC预算保持，仅追加仪表所需约束。

最终资源：Slice 18901/21216（89.09%）、ERAM 102/108（94.44%）、DSP 31/40、PLL 5/6。

## 烧录与重建

烧录唯一文件 `R58_Buzzer_Latency_Dual_20261102_eebefd74.bit`，SHA-256 `eebefd741fe06c5322b11b83a882198c9929e95e698d723e2e7f2a16ff59e821`。确认屏幕 **INSPECT D3 R58**，再按交接说明验收。项目入口 `project/td_project/camera_to_dsi_display.al`。

换机后使用本机TD安装根和新工作目录；从本包根目录构建：

```powershell
python scripts/build_r22_relay.py --source project --baseline-manifest R57_BASELINE_SHA256.json --baseline-label 02b18c34 --extra-source user_source/hdl_source/contest_latency_clock.v --keys-v3 --seed 4 --synthesis-strategy Default --physical-strategy Default --stage-timeout 7200 --td <TD安装根> --work D:/FpgaWork/R58_rebuild
```

实际验证工具/夹具/日志位于 `validation/r58/`，物理报告/综合网表位于 `build/`。工具脚本保存实际运行路径，移机重新运行前需调整这些路径及许可证；新构建必须重新验收，不能复用本包物理PASS。参考包仅作参考，不能覆盖双列生产工程。

本任务没有操作板卡、电机或继电器。实际发声、光学识别及停车精度仍 **HUMAN_PENDING**；本版尚未上传GitHub。旧R57交付、停止的候选A及CDC拒绝的候选B记录保留。最终C仅将新增邮箱返回路径恢复9ns，避免综合合并寄存器后19ns覆盖原9ns预算；全部25项RTL编译输入一致，物理构建和审计完整重做。
