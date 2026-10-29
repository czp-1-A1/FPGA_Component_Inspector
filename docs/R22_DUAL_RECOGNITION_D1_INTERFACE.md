# D1 双区识别交接接口

本次只恢复上下双区识别，双列计数等待队友代码。新分支 `codex/r22-dual-recognition-d1` 以本地 RL7 归档 `a716eac` 为基线；本版没有拉入、替代或编写队友的计数实现。

## 实例和模式

顶层 `design_top_wrapper.v` 的 `DUAL_RECOGNITION_ONLY=1` 是本次构建默认。它将 `isp_top` 的 `RECOGNITION_ONLY` 置 1、`CLASSIFIED_COUNT/AUTO_RELAY/RELAY_LEFT_LAYOUT` 置 0，保留 `RESULT_RECORDER/MULTITHRESHOLD_EMPTY/COUNT_EMPTY_MARGIN/ROW_GUARDED_BRIGHT_EMPTY` 等 R22 检测开关。`frame_shape_search.v`、配方、原 pin.adc 和相机增益修复代码未改。

计数生成块关闭，`count_live`、`relay_feed`、`relay_alarm` 为 0；没有双列轨迹、编号、累计数、自动停车队列、五连报警实例。顶部旧模式源码仍可供后续集成参考，不能在未验证时将旧单列计数直接打开就称为双列完成。

## 候选端口

`isp_top` 增加以下输出，均为 **post_clk 时钟域**：生产默认 `ASYNC_PROCESSING=1` 时为 `processing_clk`（100MHz），其余模式需查看 `post_clk` 选择。这些接口位于 FPGA 内部，未增加实体连接器引脚，顶层未接出的端口会被综合优化。

| 信号 | 宽度 | 含义 |
|---|---:|---|
| `detect_source_start` | 1 | 当前处理源帧开始；清除上一帧待提交证明 |
| `detect_frame_commit` | 1 | `post_commit && !video_frame_bad`，源帧完整提交证明 |
| `detect_frame_bad` | 1 | 已开始接收像素后检测到坏帧；当前源帧必须废弃 |
| `detect_sample_new` | 1 | 检测器本次结果更新通知，不能单独作为计数事件 |
| `detect_objects` | 608 | 上、下区各 4 个 76bit 候选 |
| `detect_config` | 64 | `{post_config[31:0],post_wb[31:0]}`，同一处理源帧配置标签 |

接收端必须同时管理源帧开始、完整帧提交、坏帧、配置变更和检测结果通知。提交和结果可能不在同一周期，应保留当前源帧各自到达的证明，待两者齐备才接受；坏帧/新源帧/复位必须撤销旧证明和未提交结果。中途配置变化可能出现“视频帧完整但识别无效”，不能复用上一帧目标来补齐。旧 `classified_count_pipeline.v` 的帧证明管理可供参考，它不等于现成双列计数。

本次只增加原始端口，没有新增已提交事件邮箱或跨时钟 CDC；在其他时钟域消费时必须增加完整握手，不能各位独立同步。接口未提供持久目标 ID 或源帧序号，后续若需要，应在同一帧证明边界生成。

## 608bit 格式

上区 ROI1：`detect_objects[303:0]`。下区 ROI2：`detect_objects[607:304]`。区内槽位 `k=0..3`：

```verilog
record = detect_objects[(lane*4+k)*76 +: 76]; // lane=0 上，lane=1 下
```

| record 位 | 字段 |
|---|---|
| 75 | valid |
| 74:73 | kind：1=待复核，2=有件（仍需检查 reason），3=空穴 |
| 72:69 | reason，保持当前检测器原始位义；有件带复核原因不得直接当合格有件 |
| 68:56 | 检测面积 |
| 55:49 / 48:42 | 形态宽 / 高，检测器半分辨率 mask 单位 |
| 41:31 / 30:20 | xmin / xmax，1280×720 处理像素 |
| 19:10 / 9:0 | ymin / ymax，1280×720 处理像素 |

ROI1 为 `[400,880)×[240,400)`，ROI2 为 `[400,880)×[432,600)`。目标框、面积、形态宽高需按原检测器定义使用，不能把不同单位混用。框中心可由两端坐标平均；边界不要直接当毫米。无效槽必须忽略，空槽不等于检测到空穴。

候选槽位是本帧排序结果，跨帧可改变，**槽位号不是目标编号**。画面只取每区前 2 项：`{detect_objects[455:304],detect_objects[151:0]}`；计数端若接入应读取全部 4 项/区，避免把显示上限误当检测器上限。

## 显示元数据和约束

本版总帧元数据 631bit，保持原几何/识别与 129bit 标定信息；移除旧 256bit 计数帧段。通过原帧槽发布/获取逻辑与图像一起交付，未把异步 live 结果直接叠在另一帧上。

构建使用独立 `td_project/camera_to_dsi_recognition.sdc`：与原 SDC 相比只删除未实例化的 `u_count_live_display` 3 条最大延迟约束，其他字节相同；46 项活动约束无忽略。手动命令仍经 `u_count_command`，实际电机状态仍经 `u_relay_display`。原 SDC 没有改，后续接入计数后需重新核对实际实例和元数据宽度，不可沿用本版资源/时序结论。

## 已验证范围

`tests/dual_recognition_d1` 提供双区 RGB/RAW10/OSD/按键测试，发布包带编译输入 SHA 和日志。当前保留白色 3528 已标定几何和 R22 判据，未证明任意封装、任意速度或弱反射空穴均可检出。继承的弱 RAW 反射孔漏检边界未修；旧自动模式高速编号的已知边界也没有因本版而解决。双列计数集成及实板识别验收待后续进行。
