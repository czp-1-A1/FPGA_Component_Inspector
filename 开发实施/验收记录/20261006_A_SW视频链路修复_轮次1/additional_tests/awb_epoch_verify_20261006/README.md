# 真实 AWB 停钟 / early FS / pixel SOF 独立验证

2026-10-06，Asia/Shanghai。只写本目录；工程 RTL、AGENTS、旧证据、构建、发布和 JTAG 未改。

## 结论

TD 实际选用 `user_source/hdl_source/awb.v` 与 `signal_delay.v`，不是 `isp/awb/` 下的同名副本。实际 AWB、divider gate 网表及 Anlogic PH1P_LOGIC_ERAM 验证了旧输出残留：新 I_tuser 清 rd_valid，但 rd_valid_d / valid_d1 / valid_d2 仍向下游留下三个可采样旧 valid。

旧 Sobel 的真实 AWB 契约负例明确 FAIL；当前 input_armed 修复在四模式均通过，旧 valid 不改变输入指针、不写旧 bank 地址、不产生新 epoch RGB / packed 字、不重新置 frame_bad。随后每模式一完整 1024×8 帧，从 (0,0) 起逐像素、坐标、行末和 128bit 字比对通过。

| 模式 | 旧 AWB 残留拍数 | 旧 Sobel 新 epoch RGB 拍 | 旧 Sobel 新 epoch packed 字 | 旧 Sobel sticky bad | 修复后新 epoch RGB / packed / bad |
|---|---:|---:|---:|---:|---|
| RAW | 3 | 3 | 2 | 0 | 0 / 0 / 0 |
| GRAY | 3 | 3 | 2 | 0 | 0 / 0 / 0 |
| EDGE | 3 | 0 | 0 | 1 | 0 / 0 / 0 |
| GRAY+EDGE | 3 | 0 | 0 | 1 | 0 / 0 / 0 |

旧 Sobel 输入指针从 group=208,row=3 增加到 group=0,row=4；修复后始终保持 group=208,row=3，直到真正新 pixel_sof。EDGE 两模式已写入的 bank3 对应地址在此区间保持不变。四模式均逐拍断言 input_armed=0、采样 input_valid=0；三拍真实 AWB 残留均被计入 suppressed。

修复后各模式新 AWB 2048 拍、8 个完整行，Sobel 8192 像素、packer 1536 字，只一个 pixel_sof 和一个 early 事件。RAW / GRAY 的 core / edge / sum 均为 0；EDGE / GRAY+EDGE 为 40 / 40 / 3840，与独立软件式参考一致。EDGE 全行输出连续性逐拍检查通过。

## 刺激与时序定义

1. 每模式独立 reset；先送正常旧帧前三行，行间留 600 CSI 拍。
2. 送完整旧输入第 3 行，停止输入，再运行 6 拍。此时 AWB O_tvalid=1，Sobel write_y=3，但 AWB 的 I_tvalid_r0、I_tvalid_r1 及 signal_delay.I_valid_r 均已为 0。该刺激把输入流水残留与输出回放残留分开，使新帧输入几何完整。
3. CSI 时钟停止 500000 ns；cycle 计数不变。恢复首拍拉高新 I_tuser，下一拍撤销；等待 20 拍，然后送新完整帧。没有强制 AWB 内部状态、valid、divider 或 RAM 输出。
4. 若把 early 被采样的一拍记为 E，Sobel 在 E+1、E+2、E+3 三拍仍采样旧 O_tvalid=1；E+3 的 NBA 后 O_tvalid 才为 0。trace 同时记录边沿采样值与 NBA 后流水值，避免把它们混用。
5. 本刺激中新的 pixel_sof 被 Sobel 采样在 E+75；RAW / GRAY 同拍输出新坐标 (0,0)，EDGE 两模式等整行缓存准入后也从 (0,0) 回放。75 拍包含测试设定的 20 拍空闲，不是整个 ISP 的 native FS 到 RGB 延迟测量。

新旧帧采用不同 id 的行 / 像素位置图样，各像素 R=G=B，使实际 divider 得到 unity gain，隔离 AWB 颜色增益与 epoch 恢复问题；GRAY 在此图样等于原值。EDGE 参考仍独立计算非零梯度和阈值覆盖。不同通道的灰度转换正常路径由 root 的其他 Sobel 回归覆盖。

packer 的 epoch 以其实际 O_128b_frame_start 划分。early 经 Sobel 的 registered out_early_sof 再进入 packer；RAW / GRAY 在 E 当拍仍可能有 1 个旧 epoch 字，该字先于新的 packed_sof。TB 分开记录 prior_epoch_words_before_FS 与 leaked_packed_after_FS。packed_sof 同拍禁止 packed_valid；packed_sof 后至新 pixel_sof 禁止任何新字。修复前新 epoch 漏两字，修复后零字。

## 证据与运行

- `legacy_contract/console.log`：不使用 EXPECT_LEGACY，对冻结旧 Sobel 跑同一隔离契约；528801 ns 明确 Fatal `new early epoch accepts old AWB tail mode=0`，Errors: 1。这是预期负例，不能当功能 PASS。
- `legacy/console.log`：四模式旧 RTL 特征复现，明确 `PASS legacy defect reproduced:`，Errors: 0。PASS 只表示成功复现旧缺陷。
- `fixed/console.log`：四模式指针 / RAM / valid 隔离与完整帧恢复，明确 `PASS real AWB epoch isolation:`，Errors: 0，Warnings: 2。
- 三个目录各含 `epoch_trace.csv`、`inputs.json`、实际编译的 `compiled_roi_sobel_view.v` 副本；正常日志还含 compile / transcript。输入 SHA256 涵盖实际 RTL、TB 和运行脚本。
- `pilot_monitor_phase/` 保留第一次监测错误：把 packed_sof 之前的旧 epoch 字误计入新 epoch，导致 fixed 误判；CSV 首版末列缺逗号亦已纠正。后续以实际 packed_sof 为边界，没有改变 RTL 或新 epoch 隔离目标。
- `pilot_pointer_monitor/` 保留加强检查后的采样错误：新 pixel_sof 在 NBA 后出现时组合 input_valid 合法变 1，TB 曾把它当成上一边沿采样的旧输入。改为 posedge 采样 input_valid，与 DUT 写 RAM 的边沿一致。旧指针和 RAM 保持断言目标没有改变。
- `corrected_monitor/` 保留只含输出契约的第一次四模式通过证据；最后的 `fixed/` 另包含指针 / RAM / packer FS 同拍断言。

```powershell
& ./tmp/awb_epoch_verify_20261006/run.ps1 -Case legacy_contract
& ./tmp/awb_epoch_verify_20261006/run.ps1 -Case legacy
& ./tmp/awb_epoch_verify_20261006/run.ps1 -Case fixed
```

ModelSim 退出 0 不作 PASS 依据。positive runner 必须同时见指定最终 PASS 且无 Fatal / Error。negative runner 必须见指定旧 RTL 契约 Fatal，并在终端标明 EXPECTED FAIL。vendor RAM 原 gate 网表的 ECC 注入口宽度警告保留；没有使用 RAM 行为替代模型或 force。

旧 Sobel SHA256：`13738d3d535df505dc675979ac44bfa74ce186be517f7bfdc4fb5ca030312596`。

修复 Sobel SHA256：`94e0e630cb270a1b5bec4a17bcb438454dc362a7d46c54cdc78ba1ee61ddfa55`。

范围是实际 AWB→Sobel→packer、真实 divider/vendor RAM、1024×8 独立输入契约证明；未包含 native RAW / demosaic / CSI 解包、DDR PHY、完整 1024×600 或实物花屏验证。这些由 root 的工程 / 实际 ISP / 完整传输回归与上板验收覆盖。
