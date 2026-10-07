# 去除逐行等待后的真实 MC 回归（2026-10-07）

本目录独立重新复制和编译九份当前工程源，并使用全新的 ModelSim work 库。Sobel SHA256 为 `377f6b3ff67cd3f11a744ce3cf0839576f78431754845eaba78cb014e4c3de11`，包括 root 移除逐行 pipeline_idle 准入条件和新增 timing_debug（LP/WS）。VI、VO、3:4 packer、MC adapter、两类生成 FIFO 源保持原哈希。本测试没有复用旧 `94e0e630...` 编译库或把旧通过证据归给新源码。

工程只读；本目录仅测试和证据，没有工程/AGENTS/旧日志写入、综合、发布或 JTAG。`tested_inputs.json` 记录测试前 SHA，`tested_rtl/` 保存实际编译快照，`manifest.json` 核对九份工程源与快照测试前后哈希一致。

## 通过结果

全部输入帧均为 1024×600，每行 256 个 RGB4PPC 有效拍及 384 个 CSI 空闲拍；每帧必须完整产生/写入/读取 115200 个128位字，完整显示逐像素比较614400个RGB像素。CSI/DDR/DSI 周期为8.888/15/19.23ns；三个时钟始终运行、模式切换不 reset。第二帧源在显示 VS 任务开始后4500 DSI拍进入，与真实 VO 读 burst 竞争。

| 场景 | 功能结果 | 校验结果 |
|---|---|---|
| RAW→EDGE→RAW，无 MC 暂停 | PASS | 三帧345600写字、1843200显示像素、691200真实MC读写命令，全部零差异 |
| GRAY→GRAY+EDGE→GRAY，无 MC 暂停 | PASS | 同上，灰度及边缘RGB逐像素均正确 |
| RAW→EDGE→RAW，MC暂停1000 DDR拍（15µs） | PASS | 三帧完整；命令FIFO峰501，无full；OF/UF/LF=0 |
| RAW→EDGE→RAW，MC暂停2000 DDR拍（30µs） | 预期拒坏帧并恢复 | EDGE不发布短帧、保留旧slot3，下一完整RAW更新slot2；OF/UF=0，LF=1 |

2000拍场景最终日志明确 `FAIL: SWITCH_TRANSPORT`，因为中间EDGE帧受到受控过载而没有完整发布。它通过的是安全拒帧和恢复预期，不会把功能FAIL改称完整视频PASS。首次cache_overrun在write_row18/read_row15、camera_used454；EDGE实际产生2880/115200 packed字、2426/115200 MC用户写字，frame_bad/camera_bad均为1。所有实际输出前缀、MC写字/地址和随后旧完整帧/恢复帧的显示像素零差异；命令FIFO全部接受的命令均正确退休，没有full。

LP在所有完整和受控坏帧中测得640，与独立刺激的256+384行周期相符。正常WS=0；1000拍暂停时EDGE WS=190；2000拍拒帧时EDGE WS=1025，下一RAW WS清零。

独立NumPy从坐标/帧ID生成原RGB，计算(R+2G+B)//4和完整3×3 Sobel；没有读取DUT灰度/梯度作答案。核心ROI统计也独立计算并断言：帧ID1为core_pixels6400、edge_count5750、edge_sum1177208；帧ID2为6400/5759/1175752。这里两种完整EDGE帧ID2统计均匹配6400/5759/1175752，RAW/GRAY三项均为0。四种显示模式通过逐坐标RGB和128位打包参考检查。

## 真实 MC 命令检查

实际调用 roi_sobel_view、data_96bit_to_128bit、video_in、video_out、两侧 w128 异步FIFO/RAM、mc_to_user_interface 和其 w155 命令FIFO。ready取真实almost-full；MC暂停只改app_rdy/wdf_rdy，保留现有8命令headroom约定。

独立接受队列在最终user_en记录命令；MC口出队时逐项核对顺序、地址、读写类型、写数据。memory只在实际mc_app_en取出写命令时更新，读响应只在实际MC取出读命令后按40DDR拍延迟排队。完整场景accepted=retired=691200、mc_writes=mc_reads=345600；未绕开命令FIFO直接保存DDR数据。

## 运行和证据边界

```powershell
& ./tmp/edge_transport_after_pipeline_20261007/run_mc.ps1 -Pauses @(0) -FirstModes @(0,1) -Competes @(1) -Gaps @(384)
& ./tmp/edge_transport_after_pipeline_20261007/run_mc.ps1 -SkipCompile -Pauses @(1000,2000) -FirstModes @(0) -Competes @(1) -Gaps @(384)
```

runner拒绝覆盖既有case；重跑需复制到新的独立目录。每个case包含console.log、transcript.log、trace.csv、result.json；ModelSim退出0还必须见明确最终PASS/FAIL且没有Fatal/Error。write_manifest.py进一步验证精确完整帧计数，以及2000拍的旧槽保留和完整恢复，全部四个场景达到各自预期。

最终vlog编译0错误/0警告。首场景优化器保留18条生成FIFO的既有宽度/缺省连接警告，后续场景0警告。`compiled_tb_edge_freeze_mc.v`保存本次实际编译TB；主TB成功模拟后只改正继承的恢复帧gap注释，执行逻辑没有变化。

这里输入为合成AWB RGB、合成末行frame_good，未包含native RAW解包、真实AWB、ROI guard、config/observation控制CDC、DDR PHY、OSD或物理摄像头帧率。本次证明新源码的受控传输和故障恢复，不证明旧实物EDGE冻结根因已确认或上板已修复。旧诊断SHA94与旧bit冻结SHA137仍须分别核对，不能混用为新源码377的PASS。
