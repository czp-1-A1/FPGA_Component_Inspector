# D2 第一条停车 + 第二条识别交接

此说明覆盖 D1 接口文档对当前模式的解释。D1 关闭计数和停车不符合本次用户澄清；D2 保留完整第一条 RL7 计数/停车流程。队友只交付双列计数，停车接入仍在本工程完成。

生产默认：`SECOND_LANE=1`、`DUAL_RECOGNITION_ONLY=0`，因此 `CLASSIFIED_COUNT=1`、`AUTO_RELAY=1`、`RELAY_LEFT_LAYOUT=1`。原计数器、`classified_count_pipeline`、`pocket_relay_stop_v2`、按键控制的旧模式、V2 和原 SDC 保留。

## 三个区域与独立通路

共享 `frame_shape_search` 扫描引擎扩展到三个区域，按原第一条计数、第一条定位、新增下方识别顺序扫描；T100/T80 及当前帧的行锚、亮阈值证明、局部暗参考和 Sobel 质量判据分别管理。下方不会使用第一条的 hold/repair 提示，也不参与第一条 transport_occupied。局部灰度缓存保留原上方矩形，追加下方矩形，避免给左下空白分配缓存。追加缓存的 RAM 读取经一级寄存器后再做判定，相应测量等待增加一拍；原两区兼容模式的延迟不变。

`isp_top` 在 post_clk 域输出：

| 信号 | D2 含义 |
|---|---|
| `detect_objects[303:0]` | 第一条右侧计数区 4 个候选 |
| `detect_objects[607:304]` | 第一条左侧补件定位区 4 个候选 |
| `detect_second_objects[303:0]` | 新增下方第二条料道 4 个候选 |
| `detect_sample_new` | 三个区域本次检测结果通知，不能直接当计数事件 |
| `detect_source_start / detect_frame_commit / detect_frame_bad` | 当前处理源帧开始、完整提交、坏帧证明 |
| `detect_config[63:0]` | `{post_config,post_wb}` 配置标签 |

注意：旧 D1 的 `detect_objects` 曾表示上/下两个区；**D2 的这个 608bit 总线恢复为第一条计数/定位两个区**。新增第二条必须读取 `detect_second_objects`。端口注释已同步区分 count+repair 与独立下方料道。

每个候选仍为 76bit：valid[75]、kind[74:73]、reason[72:69]、面积[68:56]、形态宽/高[55:49]/[48:42]、xmin/xmax[41:31]/[30:20]、ymin/ymax[19:10]/[9:0]。kind1 待复核、2 有件（需检查 reason）、3 空穴；无效槽不是空穴。坐标是全图 1280×720 像素，形态宽高与边框跨度单位不同，保持原检测器语义。

本帧槽位会重排，不是持久 ID。消费端必须处理源帧开始、提交与结果先后到达、坏帧、配置变化和复位，不能单凭 sample_new 计数或补入上一帧结果；跨域时使用完整握手。生产默认 post_clk 为 processing_clk 100MHz。

## 帧元数据

D2 总宽 **1039bit**：原 887bit（含原 631bit 观察/标定及 256bit 计数段）保持低位映射；新增第二条显示候选放在 `[1038:887]`，每帧取下方前两项。原计数段仍 `[886:631]`，标定 `[630:502]`，原计数/定位可见对象仍 `[501:198]`。

全部元数据经原帧槽、epoch、late attachment、VS 快照和显示有效性判断传输。不能用另一个异步 live 结果替换显示槽中的目标。完整 RAW 回放验证该布局及失效帧撤销；这不等于物理 DDR 标定或光学识别召回验收。

## 后续双列计数接入

当前计数/停车仅消费第一条原通路。接入队友代码时需交换每条料道的 source frame、RUN、ID、kind、位置、方向、置信度与复核/丢失状态；然后在本工程明确单电机下两条停车队列的仲裁。第二条目前不编号、不累计、不自动停车、不计入五连报警，这是等待计数接口，不是删除第一条功能。

`SECOND_LANE=1` 当前按生产 `REGIONS=1 / RELAY_LEFT_LAYOUT=1 / INDEXED_CANDIDATES=1 / COUNT_CANDIDATES=1` 配置使用；其他检测布局先独立验证，不能用此模式的资源、时序或结果承诺任意参数组合。
