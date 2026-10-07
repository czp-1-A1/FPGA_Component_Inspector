# EDGE 冻结传输条件诊断（2026-10-07）

本目录只写新 TB、runner、快照和证据；未写工程 RTL、AGENTS、旧日志，未综合或 JTAG。测试对象为固定源码快照，Sobel SHA256 为 `94e0e630cb270a1b5bec4a17bcb438454dc362a7d46c54cdc78ba1ee61ddfa55`。完整九份输入清单与哈希见 `tested_inputs.json`、`manifest.json`。

## 发现和结论边界

旧全传输 TB 每个 1024 像素行给 256 个 AWB 有效拍和 512 个 CSI 空闲拍；每次仿真 mode 固定，未覆盖 RAW↔EDGE 切换。实际 TD 项目选 `hdl_source/awb.v` 和 `signal_delay.v`；后者连续回放 256 拍，AWB 以 valid 下降沿给行末，不保证 512 拍空闲。两 lane 的 1024 RAW10 载荷至少 640 个 CSI 拍，故本诊断将 384 个 AWB 行间空闲拍作为真实条件的下界，对 gap0/64 单独标记为过密压力刺激。

Sobel EDGE 只在 `view_ready` 高且 pipeline_idle 时准入下一回放行。VI 的 `camera_used<=288` 为一行 192 个 packed 字预留空间；写 burst 等待至少 240 个字。四 bank 缓存在 `write_row>=read_y+3` 时拒绝整帧，VI 不发布未写完整的槽，VO 保留旧完整槽，画面表现可为冻结。这是已复现的数字行为；它不等同于已证明实物有相同 MC 暂停。

真实 gap384、没有人为 MC 暂停的 RAW→EDGE→RAW 和 EDGE→RAW→EDGE，在真实 VI/VO 争用及 `mc_to_user_interface`、w155 命令 FIFO 下均完整 PASS。每场景三个完整 1024×600 采集帧，共 345600 写字、345600 读命令、1843200 显示比较像素；MC FIFO 691200 个读写命令逐项比较顺序、地址、类型和写数据，全部正确。故正常模拟条件没有复现 EDGE 独有冻结。

## 固定源相位的真实 MC 对照

CSI/DDR/DSI 周期为 8.888/15/19.23ns。第二帧源在显示 VS 任务后 4500 个 DSI 拍开始；该帧 gap384，暖场和恢复帧 gap512。相邻模式切换时不复位、不停钟。MC 暂停在第二帧产生第 2400 个 packed 字后开始，同时拉低真实 app_rdy 和 wdf_rdy；VI/VO 的 ready 来自真实命令 FIFO 的 almost-full，不由 TB 直接拉低。

| MC 暂停 DDR 拍 | 暂停时间 | 第二帧 EDGE | 第二帧 RAW |
|---:|---:|---|---|
| 0 | 0 | PASS | PASS |
| 1000 | 15µs | PASS | PASS |
| 1200 | 18µs | PASS | PASS |
| 1400 | 21µs | FAIL cache_overrun、OF0 | FAIL camera FIFO 满、OF1 |
| 1600 | 24µs | FAIL cache_overrun、OF0 | FAIL camera FIFO 满、OF1 |
| 1800 | 27µs | FAIL cache_overrun、OF0 | FAIL camera FIFO 满、OF1 |
| 2000 | 30µs | FAIL cache_overrun、OF0 | FAIL camera FIFO 满、OF1 |

该固定相位没有找到 RAW PASS、EDGE FAIL 的窗口。EDGE 在 1400 拍场景的首次拒帧为 write_row18、read_row15、正在回放、credit0、camera_used310，最后只有 2995/115200 打包字、2690/115200 写字，保留旧 RAW slot3；下一 RAW 完整帧恢复 slot2、LF1、UF0。2000 拍时 EDGE 在相同 row18/read15 因 used454 拒帧；RAW 同条件也有 camera FIFO511/OF1，因此 30µs 暂停属于通用过载对照。

另补同为暖场 RAW 的 RAW→RAW→RAW 对照，避免暖场 EDGE 回放尾部造成初始时钟相位差：同 gap384、source offset4500、VO争用，1200拍仍完整 PASS，1400和2000拍仍 RAW camera FIFO511/OF1、旧槽保留、下一 RAW 完整恢复。它与上述 RAW 反向切换结果一致，没有出现只拒绝 EDGE 的窗口。

通过场景 MC FIFO 峰 500 或 501，未达 full；全部用户端接受命令均经真实命令 FIFO 正确退休。MC memory 仅在真实 `mc_app_en` 命令被取出时更新；读响应也只在真实 MC 读命令取出后排队。这不同于旧 TB 在 user_en 时直接更新 memory 的旁路模型。

## 可调源相位

`tb_edge_freeze_phase.v`、`run_phase.ps1` 在同 gap384、MC1400拍暂停、VO争用下，主动改变第二帧源的起始偏移到 4517、4553、4611 个 DSI 拍。phase 改变保持三个时钟和所有数字链路运行，不用 reset 或 force；每个场景最终状态及详细触发数据保存在对应 `*_phase_*` 的 result.json、console.log、trace.csv。它覆盖三个主动改变的源/显示相位，没有穷举所有帧周期或模拟物理相机帧率。

| source offset DSI 拍 | EDGE 第二帧 | RAW 第二帧 |
|---:|---|---|
| 4500 | FAIL cache_overrun | FAIL OF1 |
| 4517 | FAIL cache_overrun | FAIL OF1 |
| 4553 | PASS | FAIL OF1 |
| 4611 | PASS | FAIL OF1 |

主动扫描没有出现 RAW PASS、EDGE FAIL，反而有 EDGE 通过而 RAW 溢出的相位。这说明固定 source offset 的暂停阈值不能泛化到所有相位。

## 过密连续行与 epoch 静态检查

direct user-port MC 控制模型下，gap0 的 EDGE 在 write_row4/read1 即 cache_overrun；gap64 无 VO 时首次在 write_row36/read33，带 VO 时在 write_row9/read6。均 OF/UF0，保留旧槽且下一 RAW 恢复。RAW 在 gap0/64 也会相机 FIFO 溢出 OF1；这组压力结果不能用来断言真实 640 CSI 拍行周期的上板根因。gap128/384/512 的 EDGE 正常控制均完整通过。

静态检查实际 `isp_top.v`：AWB early_fs 当拍优先清 video_frame_bad，packer 的 FS 稍后清 VI camera_bad；当前 Sobel 的 input_armed 屏蔽 early_fs 到 pixel_sof 的旧 valid，没有看到仅旧 view_bad 残留在这个优先级下再次毒化新 camera_bad 的直接路径。本 TB 的 frame_good 在输入末行合成，I_frame_bad 直接取 Sobel frame_bad，未包含真实 ROI guard、observation_match/config_ok/控制 CDC 或完整 ISP epoch。静态路径判断不能替代这些模块的集成仿真。

还必须核对用户实际 bit 的源版本。旧 `tmp/awb_epoch_verify_20261006/README.md` 的 legacy 负例对应 `tmp/video_fix_td_final_20261006/.../roi_sobel_view.v` SHA `13738d3d...`，而本目录编译的是修复后 SHA `94e0e630...`；两者证据不能混用。

## 运行和证据

`generate_probe.py` 从旧检查器生成真实 Sobel/packer/VI/VO/FIFO 的双向三帧测试；`generate_mc_probe.py` 加真实 MC adapter/FIFO；`generate_phase_probe.py` 只增加 source phase 参数。`run.ps1`、`run_mc.ps1`、`run_phase.ps1` 都保存独立 case 子目录，并拒绝覆盖已有 case。每个场景必须同时满足进程退出0、一个明确最终 PASS/FAIL、无 Fatal/Error；功能 FAIL 不伪装为 PASS，只表示模拟完整复现了拒帧条件。

```powershell
& ./tmp/edge_freeze_transport_20261007/run_mc.ps1 -Pauses @(0,1000,2000) -FirstModes @(0,2) -Competes @(1) -Gaps @(384)
& ./tmp/edge_freeze_transport_20261007/run_mc.ps1 -SkipCompile -Pauses @(1200,1400,1600,1800) -FirstModes @(0,2) -Competes @(1) -Gaps @(384)
& ./tmp/edge_freeze_transport_20261007/run_phase.ps1 -Pauses @(1400) -FirstModes @(0,2) -Competes @(1) -Gaps @(384) -Phases @(4517,4553,4611)
```

上述命令用于新证据目录；本目录既有 case 会触发拒绝覆盖。RTL/TB 最终 vlog 编译 0 errors/0 warnings；生成 FIFO 优化器既有端口宽度/缺省连接警告保留。`mc_compile_failed_implicit_net.log` 保存新 MC TB 首次声明顺序错误（implicit nets），最终修正仅移动测试端 wire 声明。未创建或运行8bank及其他候选 RTL。

本诊断到此冻结：39 个完整场景，17 功能 PASS、22 功能 FAIL（受控过载拒帧），没有模拟器/checker Fatal/Error。root 此后已把工程 Sobel 更新到 SHA `377f6b3ff67cd3f11a744ce3cf0839576f78431754845eaba78cb014e4c3de11`；该新版本未用于本目录仿真，本目录始终编译固定 SHA `94e0e630...`，manifest 的 engineering_unchanged 因 root 的随后变更对 Sobel 为 false。新版本回归另存新目录，不能把这里的旧 PASS 宣称为新源码 PASS。
