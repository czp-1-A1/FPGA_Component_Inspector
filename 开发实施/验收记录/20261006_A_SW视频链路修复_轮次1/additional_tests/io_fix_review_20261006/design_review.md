# video_in/video_out 修复审查建议（只读审查）

本文件由独立审查端写入临时目录，未改工程 RTL。接口根据真实 video_in、video_out、mc_to_user_interface、top 与 roi_display_state 读取。

## 必须保证的不变量

- 只读已完整写入 115200 个 128 位字的缓冲；一次 frame_start 不是 completed frame。
- 相机 FIFO 满或帧中抢占导致丢字，该帧不得发布；不可将少字帧与上帧尾部拼成显示。
- 写槽必须同时避开当前 reader 槽与最新 completed 槽，否则采集异常后重复显示的上次完整帧可被覆盖。
- DDR 命令共享 FIFO 保证原写/读命令顺序。旧接口 ready 降低后仍有 8 字接收余量；现有一拍寄存写可以保持，不能用当前 ready 再次门控已寄存的 write en。
- display 空 FIFO 时不能只暂停 FIFO re 而继续解包相位；本显示帧撤销并输出黑色直至下一个干净显示帧起点。
- 显示复位 FIFO 与读地址前，必须停止新命令并排空旧 outstanding 返回；旧返回不得混入新帧的 FIFO。
- 空间判断要包含 wrusedw 与 outstanding=已发 DDR read 命令−已收到 read 返回，不能只用 FIFO 占用和固定 40 拍延迟余量。

## 最小接口

video_in → video_out（同 DDR 域）：completed_valid、completed_rp；前者首次完成前为 0，以后保留上一完整缓冲，即使后续坏帧也不清除可重复显示的图像。

video_out → video_in（同 DDR 域）：active_rp、active_valid；读端在旧返回排空后切换并保持，writer 每次新帧选取既非 active_rp 也非 completed_rp 的槽。保持 0/7000000/14000000/21000000 四基址。

质量状态与 completed_valid 区分：capture_ok 在坏帧/full/抢占时撤销，完整帧写入后恢复；display_ok 在缺字或预填不足时撤销，干净显示帧恢复。HDMI 域 roi_valid 应受二者限制，同时保留原曝光/增益/模式/统计 token 新鲜性。

若要认定采集质量，ISP 应给当前输出帧合法结束/故障；不能直接把 sample_cancel 当持续视频坏标志，因为 native FS 正常撤销统计。输出字数证明传输完整，不能替代现有输入 guard 的采集完整性。

## 写端边界

camera 域：frame_start 初始化 accepted_count、bad；I_camera_valid && full_flag 时 bad 置位，停止本帧余下 FIFO 写；bad 在帧期间稳定，跨 DDR 同步。合法结束应同时检查字数。下一帧重新初始化并重置 FIFO。

DDR 域：frame_start 优先停止 burst、清 O_wr_en 和计数、选择写槽/基址；S_fifo_rd_en 必须包含 !S_frame_start && !S_fifo_rst。边沿前已有的寄存 O_wr_en 仍按旧地址被 mc FIFO 接收；不可再产生一拍旧 FIFO 读，让下一拍带新基址写旧词或 reset 后 0。

actual_write_count 按最终 O_ddr_user_wr_en 递增。只有 count 最后一字实际进入 mc command FIFO、输入帧合法且无 bad 才原子发布 completed_rp。完整帧结束应显式限制写入到 115200 字，不继续读不属于本帧的余词。

## 显示端恢复

1. 显示 VS 到来：禁止新 DDR read 请求；仍接收并计数旧返回，等 outstanding=0 后清 FIFO、地址与解包状态，再锁存最新完整槽。
2. 垂直消隐预填：只在有效完整槽存在时读；首个可见相机像素前需至少一整行的 192 字预填（或等价固定有证明的水位）。第一次不满足时，本显示帧保持黑色，下一帧再试。
3. read outstanding 每个命令 +1，每个 DDR valid 返回 −1；同时发生时不变。启动 240 命令 burst 前必须保证 wrusedw+outstanding+240<=511；更保守的最小方案是等前一 burst 返回完毕才启下一个。
4. 实际需要取字的相位 0/5/10 发现 empty：停止本显示帧继续取字，按 RGB 原有延迟对齐将之后像素置黑；通知 DDR 端停止新命令。允许当前有限 outstanding 排空，不能在其未排空时复位 FIFO。下一 VS 重建相位和读地址。
5. 若 DDR 返回长时间停滞，显示保持黑色且不重用仍在 outstanding 的槽。正常无缺数据时不额外改变像素延迟。

## 针对性验证

- 真实 packer/FIFO + 全 600 行：逐字 ID、115200 实际写字、首尾地址和四模式；旧复现 300 DDR 拍暂停应全写或明确整帧舍弃，不能部分发布。
- 首帧未完成、短帧、115201 字、多次 FS、FS 恰逢 ready 和寄存末写：不错误发布、不在新基址写旧词、下一合法帧恢复。
- 读端 initial 无 completed：黑色但 OSD 稳定；每帧预填成功时逐像素匹配原 x/y。
- 任意 0/5/10 解包相位缺数据、第一行前 128 像素空窗：本帧黑且无右移继续显示；下一干净帧 x700 标记仍显示 x700。
- VS 恰逢 read 命令/返回、返回延迟 >40 且跨 VS：outstanding 清零之前不重置/换槽，无旧返回混入下一帧。
- 长期保持上次完整图像，采集持续坏帧/显示 60Hz 与输入 26Hz 异步：writer 不覆盖 pinned/latest，4 槽轮转正确。
- CSI 停钟/恢复、SW 边界切换、ready 长暂停；质量状态撤销后只凭新完整传输和新完整统计 token 恢复有效。
