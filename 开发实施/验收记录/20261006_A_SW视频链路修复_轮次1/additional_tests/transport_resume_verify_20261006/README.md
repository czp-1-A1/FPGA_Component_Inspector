# 全视频传输修复后独立回归（2026-10-06）

本目录由 `tmp/full_transport_test_20261006` 的 TB、runner、独立 NumPy 参考生成器复制并重新运行。旧目录和旧通过日志未覆盖；工程只读。`BASELINE_README.md` 与 `baseline_manifest.json` 仅记录来源，实际本次编译哈希在 `tested_inputs.json`、快照在 `tested_rtl/`。收尾时六份工程源、测试前哈希及快照哈希完全相同，记录于 `tested_inputs_after.json`。

正常测试仍使用真实 roi_sobel_view、data_96bit_to_128bit、video_in、video_out、两侧生成的异步 FIFO/RAM 行为；MC 在最终读写 en 当拍接收命令，沿用注册 en 的 8 命令 headroom 约定，不对 ready 低后的已有命令额外丢弃。CSI/DDR/DSI 时钟周期为 8.888/15/19.23ns。

每模式两帧均为 1024×600，各帧实际产生、写入、读回 115200 个 128 位字并逐像素显示比较 614400 个 RGB 像素。四模式全部 PASS：每模式 writes=230400、read_commands=230400、display_pixels=1228800；view/packer/MC write/address/display pixel 全部零差异，overflow/underflow/lost 为 0。总计 921600 写字、921600 读命令、4915200 显示像素。第二帧尾部与真实读 burst 争用时 ready 低 300 DDR 拍；camera FIFO 峰 384，读 FIFO 加 outstanding 预留峰 480。

异常链路仍为 1024×8 EDGE 模式实际行回放。CSI 尾部停钟 50µs 时仅 1176/1536 打包字、960 写字，短帧不发布并保留旧完整槽。新 early FS 后完整帧恢复；响应长暂停导致当前显示帧末 256 像素黑屏，underflow 累计 1；跨 VS 保持 active slot 和 FIFO，旧 outstanding=240 排空后才 CLEAR 且 outstanding=0；ready 长暂停实际触发 cache_overrun 并拒绝坏帧，随后完整帧恢复，lost 累计 2、overflow=0。`faults.console.log` 有明确 TRANSPORT_FAULTS PASS。

新增 `tb_pre_sof_four_modes.v` 从独立 `tb_pre_sof_tail.v` 的参考与检查器生成，仍为 1024×8，并将 ROI 放入该小高度内以比较真实 3×3 Sobel。对实际旧 RAW、GRAY、EDGE、GRAY+EDGE 四模式各发送半帧，early_sof 清掉旧帧后，在真实 pixel_sof 前注入 4 拍旧 valid（末拍带 last）。每拍逐项检查：四个 bank 的全部 RAM 内容不变、写组/行计数不变、input_valid/input_armed/cache_overrun 均为 0、无 RGB 输出、无打包字、packer 相位为 0、无 frame_bad、统计清零。随后每模式下一完整帧逐 8192 像素/1536 字、坐标、bypass 时序、Sobel 计数比较通过。新边界共拒绝 16 拍旧 valid，恢复 32768 像素/6144 字。

`initial_edge_to_four_modes/` 保留首次补测的通过日志和 TB，其旧帧统一为 EDGE、恢复帧覆盖四模式；最终测试加强为旧帧本身也覆盖四模式。该目录不作为最终四种旧模式覆盖的证据。

`run.ps1`、`run_faults.ps1`、`run_pre_sof_four_modes.ps1` 同时要求进程退出 0 和明确最终 PASS；manifest 另检查没有 Fatal/Error，不依赖 ModelSim 的退出码。RTL/TB vlog 编译 0 errors/0 warnings。mode0 和 faults 优化器各出现 10 条生成 FIFO 既有 ceb/addrb 宽度和 dib/doa 缺省连接警告；其余 mode1..3 和独立边界测试优化/运行 0 warnings。警告未当作通过依据。

证据限定于受控数字链路行为，输入为合成 AWB RGB，不包含 RAW 解拜耳、输入 guard、真实 DDR PHY、DSI、OSD 或上板现象。该测试没有综合或 JTAG 操作。
