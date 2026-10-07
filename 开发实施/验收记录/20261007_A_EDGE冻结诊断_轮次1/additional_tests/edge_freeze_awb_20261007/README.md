# EDGE 冻结：真实 AWB 行时序与 ready 诊断

2026-10-07。仅本目录写入，工程 RTL / 旧证据 / 构建 / 发布 / JTAG 未操作。

## 已完成的密集行实验

`tb_dense_awb.v` 使用 TD 实际选中的 awb.v / signal_delay.v、实际 divider gate、Anlogic vendor ERAM、实际 Sobel 和 packer，1024×16，连续执行 RAW→EDGE→EDGE 和不同 gap 的新帧。输入 R=G=B=100，真实除法器保持 unity gain，参考输出全为 0x646464。本测试定位调度与完整性，不做新图像算法评估。

`console.log` 有最终 `PASS dense actual AWB diagnosis:`，Errors: 0。这里 PASS 表示成功完成诊断与预期异常检查，不代表下面的小 gap 条件功能通过。

| AWB 输入 / 实测输出行间 gap（CSI 拍） | RAW | EDGE（ready 恒 1） | 第一次 cache_overrun |
|---:|---|---|---|
| 1 | 4096 RGB 拍 / 3072 字，完整 | 504 RGB 拍 / 378 字，坏帧 | write_y=4, read_y=1, group=0 |
| 2 | 4096 RGB 拍 / 3072 字，完整 | 759 RGB 拍 / 569 字，坏帧 | write_y=5, read_y=2, group=0 |
| 4 | 4096 RGB 拍 / 3072 字，完整 | 1529 RGB 拍 / 1146 字，坏帧 | write_y=8, read_y=5, group=0 |
| 6 | 完整 | 4096 RGB 拍 / 3072 字，完整 | 无 |
| 8 / 10 / 16 / 384 | 完整或另有对应完整 EDGE 测试 | 4096 RGB 拍 / 3072 字，完整 | 无 |

gap=1 两个连续 EDGE 新 epoch 均在同一位置再次坏；每帧 early FS 已正常清掉上一帧 frame_bad，SOF 均为一次。这证明“每帧重新坏”可导致永久没有新发布槽，而不需要 frame_bad 跨帧保持。

实际 read_start 周期最短为 262 拍 = 256 拍 RAM 回放 + 6 拍 pipeline_idle 排空。源码要求全部 v1/v2/previous/v3/v4/out_valid 清空才能再开始下一行，故行周期 257 / 258 / 260 持续快于可消费周期，四 bank 很快触发 `write_row >= read_y+3`。同一帧的最后两行也被按 262 拍回放；gap 足够时没有遗漏末行。

gap=384、ready 恒 0 时，RAW 仍保持完整旁路输出；EDGE 在 write_y=3/read_y=0/group=0 首次 overrun，零 RGB / packed 输出；下一帧清 bad 后同位置再次 overrun。最后返回 RAW 恢复完整输出。注意这个 standalone 实验直接驱动 ready，不等于已解释真实 VI 为何 ready 低。

证据：`summary.csv` 保存每帧 AWB 拍数 / 行数 / SOF / gap / Sobel 拍数 / 字数 / bad 与触发位置；`events.csv` 保存逐行 read_start 和 overrun 时刻。`inputs.json` 保存编译输入 hash，`compiled_roi_sobel_view.v` 保存本次 Sobel 副本。

## 与板上根因的关系

小 gap 的缺陷是真实 RTL 可复现问题，但不能单独作为板上根因：实际 `csi_unpacket_2lane.v` 每 CSI 拍接收 16bit，并把 32bit valid 每两拍输出一次；1024 像素 RAW10 的载荷至少 640 个 CSI 拍。稳定一行对应一行时，AWB 固定 256 拍回放，两行之间应约有 384 拍加协议开销 / blank 的间隔。该条件下 ready 恒 1 的仿真完整通过。

因此应测量真实 `awb_O_tvalid / awb_O_tlast` 周期及 `camera_row_ready`。如果 VF 不断增长、RAW 槽一直显示，优先区分：ready 准入长期推迟；新的 ROI/config/lane 异常；或者真实 AWB 行时序确实压缩到不足 6 拍 gap。

建议观测信号：AWB early / pixel_sof / valid / last；Sobel frame_mode / write_y / write_group / read_y / reading / ready_rows / pipeline_idle / cache_overrun / frame_bad；VI camera_used / camera_full / camera_bad / camera_count / S_camera_frame_start_extend / S_fifo_rst / S_frame_start / bad_sync / published；MC I_video_out_rd_busy / I_ddr_user_ready。

## 旧 frame_bad 跨新 FS 的静态时序

实际 isp_top 中 AWB early 在 CSI 边沿 E 同时清 `video_frame_bad`；Sobel 同拍清 `frame_bad` 并登记 `out_early_sof=1`。packer 在 E+1 登记 packed FS，VI 在 E+2 采样它并清 camera_bad。若没有新的 ROI/config/lane 错误，旧 ISP bad 早于 VI 新 FS 两拍清除，不能在 E+3 再次置 camera_bad。DDR 的 bad_sync 只暂时阻止写入，不反向置 CSI 的 camera_bad。

这个证明只排除“旧 Sobel bad 原样跨过新 FS”的路径，不排除新 roi_invalidate / config / lane 错误在 AWB early 后重置 ISP bad；也不排除 VI overflow 或 read_busy 造成新的信用饥饿。`tb_ready_recovery.v` 另做真实 VI / generated FIFO 信用闭环和坏帧后的恢复证明。

## 实际 VI 信用闭环 / 低 ready 恢复实验

`tb_ready_recovery.v` 在实际 AWB / vendor RAM / Sobel / packer 后连接实际 video_in 与 generated w128_d512_fifo。CSI 周期 10 ns，DDR 周期 15 ns；输入行 period=640 CSI 拍（256 拍有效 + 384 拍 gap）。MC write_ready 恒 1，用 read_busy 的长暂停隔离 DDR 读写仲裁对行信用的影响。所有 MC 写数据与 16 字节 0x64 逐字一致。

ISP video_frame_bad 分支复刻当前 isp_top：AWB early 清、Sobel bad 置 sticky。完整输入几何由本 TB 构造保证，frame_good 用全部 AWB 拍到齐来提供；本实验不伪称实际 roi_guard / native CSI 几何证明，也不包括实际 video_out 或 DDR PHY。其目标是核实 actual video_in 的 ready / FIFO / camera_bad / publish 行为。

| 帧 | 模式 | read_busy 从新 pixel_sof 起持续拍数 | RGB 拍 / MC 写字 | 当前槽发布 | 结果 |
|---:|---|---:|---|---|---|
| 1 | RAW | 0 | 4096 / 3072 | 是 | 完整 |
| 2 | EDGE | 2400，随后恢复 | 4096 / 3072 | 是 | 同帧信用恢复，完整 |
| 3 | EDGE | 3000，随后恢复 | 557 / 135 | 否 | write_y=5, read_y=2 过载；三层 bad 置位 |
| 4 | EDGE | 再次 3000 | 557 / 136 | 否 | 新 early 正常清 bad，然后再次同位置过载；DDR 相位造成一个 MC 写字差异 |
| 5 | EDGE | 0 | 4096 / 3072 | 是 | 坏帧后的新 FS 完整恢复，camera_bad 无旧错误再置 |
| 6 | EDGE | 整个有效输入期间持续 busy | 512 / 0 | 否 | 两行填满信用后停止准入，write_y=5/read_y=2 过载 |
| 7 | EDGE | 0 | 4096 / 3072 | 是 | 再次新 FS 完整恢复 |
| 8 | RAW | 0 | 4096 / 3072 | 是 | 切回 RAW 完整 |

较晚 release 虽已拉低 read_busy、DDR 开始读取 FIFO，但恢复信用并完成正在回放的行仍需时间，早于 bank 安全界限完成才可救同一帧。一旦 cache_overrun 发生，解除外部 busy 不会救已坏的同一帧；下一 early / packed FS 清旧 bad 并重置 FIFO 后可恢复。这是有意的完整帧保护，而不是旧 bad 原样跨 FS 的死循环。

`ready_recovery/console.log` 应见明确最终 `PASS actual AWB/video_in credit recovery:`、无 Fatal / Error；`ready_recovery/credit_events.csv` 记录 credit 每次变化、early / packed FS、read_busy release、cache_overrun 和 camera_bad 新上升。`ready_inputs.json` 记录本次编译源 hash，`ready_compiled_roi_sobel_view.v` 为实际编译 Sobel 副本。第一版七帧成功证据保存在 `ready_recovery_initial/`；最终另补相同晚 release 的连续两帧，验证每帧重复新故障而不是旧坏帧重置失效。

仍未认定上板冻结根因。若实物真实行 gap 约384，则当前证据把进一步检查重点收窄到：MC read_busy / write_ready 造成的反复长信用暂停，或 AWB early 之后新 guard/config/lane 错误。两种来源会汇聚到 VF 增长和旧槽持续显示，必须靠事件源区分。

```powershell
& ./tmp/edge_freeze_awb_20261007/run.ps1
& ./tmp/edge_freeze_awb_20261007/run_ready.ps1
```

两脚本都检查最终 PASS 与 Fatal / Error，不能只看 ModelSim 退出码。厂商网表已有端口宽度 / timescale 警告保留，不用 RAM / FIFO 替代模型或 force。

## 20ms debounce / CDC / 实际 ISP 生命周期追加验证

`lifecycle_after_diag/` 是 root 加入诊断及去掉 pipeline_idle 后的独立冻结源测试，和上文旧 Sobel 吞吐复现分开。冻结 Sobel SHA256 `377f6b3ff67cd3f11a744ce3cf0839576f78431754845eaba78cb014e4c3de11`；ISP SHA256 `9235953d2b438ac7334ba1b70e7b1af33adf0d4a054693487748448554d13afe`。`inputs_snapshot/` 为所有实际编译 ISP 源副本，`origin_inputs_manifest.json` 映射工程来源与 hash。测试没有 force 内部状态。

实际链为默认 1000000 周期（50 MHz、20 ms）的 observation_controls → status_cdc → uial2axis → 原 demosaic / AWB / divider / vendor RAM → 实际 ISP / guard / Sobel / packer。native RAW10 四像素有效组按 2 / 2 / 2 / 4 CSI 拍分布，载荷每行 640 拍。仅三次实际模式变化产生 request 0→6→9→15；保持电平不反复增加 epoch。

冻结源的 13 个短前缀明确 PASS，`lifecycle_after_diag/life_console.log` Errors: 0：

- 停 CSI 期间切 EDGE，恢复首拍 native FS 先于 request mailbox 新值到达，当前帧 tag=0、随后 request=6，guard 持续 invalidate / video_bad，reason=8。下一 native FS 捕获 tag=6 后 EDGE 恢复；重复稳定 EDGE、GRAY、GRAY+EDGE 前缀均没有新 bad。
- 原始输入 cfg 低三拍触发 config+guard reason=0xA；lane 低位错误三拍触发 lane+guard reason=0xC。没有改变内部 fault 或答案；恢复后下一 native FS 清 guard，再到 AWB early 清新 epoch。
- credit 恒低触发 Sobel cache reason=1，WS 非零；撤销 credit 故障，下一帧前缀恢复。
- 每个真正 AWB early 都在边沿前保存旧 `{reason,LP,WS}`，边沿后断言 video_diagnostics 精确锁入旧值、当前 reason / timing / good / bad 清零。config 故障的下一 early 锁入 A；lane 故障锁入 C；cache 故障的下一 early 锁入 9 / LP687 / WS1119。

前缀之间故意尚未完成 600 行，下一 native FS 的 guard 把未完成候选标坏，因此正常前缀的下一 old-epoch reason 也可多出 guard8，cache 后记录9。这是短前缀的限制，不能拿它解释完整实物帧的 reason 或声称前缀产生 frame_good。所有前缀的 good 均为0。

## 完整实际 ISP 单帧与短 native gap 负例

同份冻结源另跑一正常完整 EDGE 帧，采用旧九帧 proof 已验证的 native gap160（行周期800）。`full_g160_console.log` 有最终 `PASS actual ISP full epoch:`，Errors: 0：600 native 行 / 614400 像素，AWB153600 拍、Sobel153600 拍，guard 完成且 video_good=1 / bad=0；独立 AWB 行 start 间隔=800，与 LP=800 相同。下一个实际 AWB early 精确锁入 clean reason0 / LP800 / WS0，并清掉 good / 新 epoch 数字。这是实际原生几何 frame_good 的成功证明，未连接 VI / DDR PHY。

先跑的完整 gap32（行周期672）负例保留在 `full_console.log`，不可当 PASS：600 行输入后 AWB145411 拍、Sobel144384 拍，guard / video_bad=1、good=0，明确 Fatal。guard 首次置坏在 CSI cycle26644（新 pixel_sof=6034），早于结束检查；16行短前缀尚不能覆盖这种累计错位。

静态候选解释是原 zhenghe 的固定回放窗口需要 `data_complete_delay=50` 尾部，下一行 valid 到达会重置其 flag / x_cnt；gap32 可能让旧行回放被下一行打断。已有前缀观察到 native period672、诊断 LP687；完整原生输入仍不足全部实际 RGB 拍。**尚未认定板上根因**：真实 sensor gap 未观测，而且该 upstream 失配不应仅影响 EDGE。需确认 RAW 是否随移动目标持续刷新，不能把静态画面无花屏自动等同于 RAW 一直发布完整新帧。

`lifecycle_pilot/` 保留首次 testbench 错误：恢复 CSI 后测试 task 先等待900拍，导致 mailbox 已送达再发 nativeFS，未覆盖原定的“request 晚于 nativeFS”场景；修正为恢复首拍立即 FS，隔离契约目标与工程 RTL 都没有改变。之前未冻结的 `life_console.log` / `life_proof_inputs_manifest.json` 是分析实验，不当最终版本证明；其中 ISP 为新诊断源、Sobel 为中间 hash38e905。最终结果一律以上述冻结子目录为准。

```powershell
& ./tmp/edge_freeze_awb_20261007/lifecycle_after_diag/run.ps1
& ./tmp/edge_freeze_awb_20261007/lifecycle_after_diag/run_full_g160.ps1
# 预期失败的 native gap32 负例，保留原 FAIL：
& ./tmp/edge_freeze_awb_20261007/lifecycle_after_diag/run_full.ps1
```

full runner 复用 `run.ps1` 建立的冻结 RTL / vendor 编译库，只编译自己的新 TB。正例要求最终指定 PASS 且无 Fatal / Error，完整 gap32 负例明确 FAIL，不以退出0或中间 PASS latch 行判通过。
