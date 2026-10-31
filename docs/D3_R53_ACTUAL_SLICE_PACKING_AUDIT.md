# R53：实际Slice打包审计

用户要求继续后，直接读取保留的R50和R52实际place DB，导出物理网表并核对每一个Slice的LUT、QA/QB寄存器、使能、时钟及复位连接。没有重新布局、布线或改动这两份数据库；没有删减功能或显示模式。

## 核心结论

**R52增加144个寄存器专用Slice的直接表现，是原有FF与LUT的共用减少；不能归因成新增5个准备FF自身占了144个Slice。** 新增5个准备FF全部位于带LUT的Slice，硬件CE选择都是常开1，其RTL保持行为由数据通路实现。

R50与R52有23094个同名Q位。其间1613个从LUT/存储Slice迁入寄存器专用Slice，1301个迁出，净迁入312个；两边仅出现的Q名称中，没有位于寄存器专用Slice的FF。这与专用Slice里的FF总数2453→2765（+312）完全吻合。名称对应和总量核对不是形式化门级等价证明，但足以确认此处的实际打包迁移。

## 与原面积报告逐项对齐

| 实际放置统计 | R50 | R52 |
|---|---:|---:|
| 总Slice | 19994 | 20111 |
| 逻辑/进位Slice合计 | 18137 | 18110 |
| 分布式RAM Slice | 544 | 544 |
| 寄存器专用Slice | 1313 | 1457 |
| 全部Slice FF | 23105 | 23111 |
| 专用Slice内FF | 2453 | 2765 |
| 放2个FF的专用Slice | 1140 | 1308 |
| 仅放1个FF的专用Slice | 173 | 149 |

单FF的Slice反而少24个；双FF专用Slice多168个，合计增加144个。不能继续用“多出很多落单寄存器”解释R52增量。

仅把R50现有173个单FF专用Slice重新两两配对、保持全部2453个FF仍在专用Slice中，理论上最多少 `1313-ceil(2453/2)=86` 个Slice，约占器件0.41%。这是忽略时钟/复位/位置限制的容量上界，实际可能更少。要节省几百个Slice，必须改善与LUT的共用或减少数据通路/存储成本。

## 专用FF热点

以下按实际Q网代表的逻辑字段归类，数字是FF位数，不是这些字段可独占回收的Slice数量。不同字段可能共用一个物理Slice。

| 字段 | 全部FF | 位于专用Slice的FF |
|---|---:|---:|
| `u_video_out/O_active_metadata` | 560 | 274 |
| FSS `recorder_storage` | 750 | 247 |
| `u_count_live_display/D_data` | 286 | 152 |
| `u_video_in/metadata_receive` | 569 | 117 |
| `u_active_frame_display/D_data` | 382 | 103 |
| `u_monitor_display/payload` | 126 | 82 |
| `u_input_monitor/rx_mailbox/D_data` | 94 | 69 |

宽的帧信息、跨时钟邮箱和显示快照是主要热点。它们的采样时刻和时钟域不同；现有 `status_cdc` 用两级令牌同步并保持payload直到确认，不能只因总线内容相近就删除一份。

R52中最大的一些迁移也发生在未增加FF的字段：计数显示D_data净迁入51位，lane0 live_record迁入35位，活动帧显示D_data迁入27位；反方向FSS recorder_storage迁出67位、活动视频metadata迁出39位。资源变化涉及全局重新打包，并非只发生在改写的FSS局部。

## 控制信号应怎样解释

官方物理LSLICE模型有两个独立的CE和数据选择，时钟、异步/同步控制则在Slice内共用。不能说“CE不同就绝对不能同Slice”，也不能把工具的934个Control Set直接等同于这里按共享引脚归类的控制组合。

R50专用Slice中，579个FF硬件CE常开1，1874个由CE引脚控制。常开CE并不表示RTL不存在保持条件，保持也可以由D端反馈实现。两列320个观察标志FF此前已经是硬件CE常开1，不应再把简单“删使能”算作新收益。

审计依据来自本机 `E:/TD/sim_release/ph1p/ph1p_phy_lslice.v` 和实际物理网表。网表没有提供所有逻辑Slice的X/Y坐标；本报告不声称已经证明任意两个FF可以合法重打包，也不声称已找到具体物理拥挤坐标。

## 基于证据选择的后续试验

FSS结果缓存是750位实际FF、247位专用FF的明确热点。原代码在复位、清零、新SOF时清整块缓存，随后逐槽写包。

只删清零并依赖全局ready不成立：异常捕获结束可能使ready在部分包已写时拉高，旧实现允许看到“已写槽位的新值，其余槽位为零”。因此选择R54隔离试验：每槽一个written位，清零只清16个written位，私有可见字为 `written ? raw_word : 0`；写包、重复项清零和所有优先级与原来相同，原控制FSM和周期不改。非DUAL_STOP或非INDEXED继续原实现。

这不是删除结果、显示或复位功能，而是对私有存储零值的另一种编码。必须验证每个时钟的私有可见缓存及所有公开输出，包括部分包、错误帧、复位/取消，而后测实际面积。R54的边界和像素对照目前通过，综合显示掩码也有成本，尚不能承诺Slice收益；最终结果另记录。

## 证据与复现

- 工作目录：`E:/2026FPGA/.codex_tmp/d3_packing_audit_r53_20261031`。
- R50保存place DB SHA：`ba68f6407f244fb4e9acd3632430067e4514eef24114d400759941a73ce85512`，重读前后相同。
- R52保存place DB SHA：`9c8feb4048f106a6d9454b040a8be362825c53d8f40774b13bf52f62330a7598`，重读前后相同。
- `r50_export`、`r52_export` 中的 `EXPORT_RECEIPT.json`、`placed_netlist.v`、`imported.area` 与4份CSV保留完整物理记录；所有Slice/连接Q计数与原面积报告一致。
- 摘要已复制为 `docs/D3_R53_R50_SLICE_PACKING.json`、`D3_R53_R52_SLICE_PACKING.json`、`D3_R53_PACKING_COMPARISON.json`。
- 首次 `report_cells` 属性查询在常量单元处导致TD崩溃。原DB SHA不变，随后跳过该查询，采用成功导出和逐项资源对齐的路径；失败记录是 `D3_R53_FAILED_ATTRIBUTE_QUERY.json`，不计作成功证据。
- 脚本：`export_d3_placed_packing.py` → `audit_d3_slice_packing.py` → `compare_d3_slice_packing.py`。只读取保存数据库、导出和统计，没有优化或烧录命令。
