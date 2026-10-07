# 最终诊断源真实 ISP 验证（2026-10-07）

Sobel 冻结 SHA-256：377f6b3ff67cd3f11a744ce3cf0839576f78431754845eaba78cb014e4c3de11。root 接续被中断的只读验证收尾，核对 origin / 实际编译 / 两份完整帧 TB 清单，所有文件哈希相符。

- life_console.log：13 个真实 ISP 前缀场景 PASS，20 ms SW 去抖、CDC、下一 native FS 恢复，以及 config/lane/cache/guard 拒帧原因；每次真实 AWB early 都核对旧 epoch 原子锁存和新 epoch 清零。前缀不代表完整帧成功。
- full_g160_console.log：640 有效拍 + 160 空闲拍/行，共 600 行。153600 个 AWB PPC4 拍、153600 个视图拍、614400 像素完整；guard / video_frame_good 成功。下一 AWB early 锁存 ER0、LP800、WS0；独立实测 AWB 行首间隔800，与 LP 相符。只有1个完整 EDGE 帧，未称四模式原生完整帧或板上验收。
- full_console.log：640 有效拍 + 32 空闲拍/行，明确 FAIL 并保留 Fatal。首次 guard_bad 出现在 CSI26644拍；最终 AWB145411、view144384，少于153600。怀疑现有 zhenghe 回放尾被下一行截断，需要真实 CSI 行时序验证；未把合成输入失败归因成板上冻结原因。

最终细目和日志哈希见 final_diagnostics_manifest.json。当前完整帧 PASS 和负例使用同一冻结 RTL，native gap 不同，证据分别保留；未改答案或隐藏失败。
