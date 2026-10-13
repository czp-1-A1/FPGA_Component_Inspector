# B追踪黑屏排查与帧尾发布修复 — 轮次1

来源：用户报告黑屏并确认RAW/复位后仍黑。分支lj4747-contest-work、HEAD3be3967f2457622566fb20b7cef3aa5038e7d885；未提交、未推送、未烧板。当前是软件修复候选已通过，现场未验收；板上旧镜像SHA尚未核对。

## 观察与复现

原照片保存onsite_black_screen.jpg：OSD正常，相机区黑；FRAME STALE/ROW0，EXP2244/GAIN48/WB64，FPS27/CFG1，ER0/LP02E2/WS0，FR03F9/VF03F8、OF0/UF0。由计数推断完整帧未发布；不能由照片确定真实CSI尾部时长。

真实RAW10桥、原厂ERAM、demosaic、手动WB、Sobel、ROI/分类、178位元数据邮箱和DDR写入器联合复现。旧生产逻辑尾部200拍测试PASS；尾部20拍停CSI、DDR继续时，AWB/view均153600拍、pack/DDR均115200字、good1/bad0，但ready0/pending1/wait44，completed0/capture0，因metadata门控黑屏。初次直接vsim缺许可环境退出4，设置已有许可环境后得到上述逻辑失败，日志各自保留。

原32项回归有覆盖缺口：isp_writer_stop未启用METADATA，而isp_tracking_late未接writer且给700拍尾部时钟，独立frame_metadata又人为生成ready；没有覆盖真实结果等待和CSI帧尾停钟同时发生。这次补齐，不将旧仿真PASS视为硬件通过。

## 最小修改与完整性

210生产输入中仅user_source/hdl_source/isp/isp_top.v改变。TRACKING时在ROI/Sobel邻域和孔三行完成后启动统计/分类，RESULT_ROW=max(HOLE_Y+10,ROI_Y1+2)，本轮下方390行、旧上方兼容342行。保留原28拍除法和48拍结果稳定等待；它们在后续相机行扫描期间完成。样本/分类外部输出由完整帧video_frame_good门控；提前计算的观察快照/元数据必须经原writer的完整字数、done/good/bad、epoch检查才随DDR槽发布。

未改video_in/out、FIFO、CSI/DDR IP、SDC、孔位/孔亮度/孔距、ROI、MEAN/EDGE阈值及成像按键。坏采集仍撤销metadata，599行即使ROI和孔完整、结果提前ready也不能发布；下一完整帧恢复。测试夹具只按writer_epoch归属判断published，避免把上一帧保持的published标志误判为下一帧早发布。R1修复先成功完整帧，随后夹具误报失败保留；R2修夹具、补恢复帧触及100ms旧测试预算，R3保留20ms间隔并按四帧114ms预期预算设150ms看门狗；生产语义不变（LF统一）。

## 验证边界

本轮六项新跑：真实下方ISP13帧、真实上方ISP、真实停钟writer、ROI整链、178位writer/reader槽原子性及新增真实METADATA停钟测试。新增测试主视图GRAY+EDGE，另对RAW/GRAY/EDGE各独立新跑；每次短前缀→完整600行→599行残帧→完整恢复，FE后20CSI拍停钟，DDR继续，证明提前结果不会放行残帧或混元数据。其余27项沿用旧R3结果，但逐条解析真实vlog命令，证明所有RTL和测试台哈希与本轮冻结源及当前工作区一致。33项覆盖清单并非本轮全33重跑。

| 测试 | 执行来源 | 结果 |
|---|---|---|
| tracking_late | 旧R3/所有编译输入未变 | PASS |
| tracking_status | 旧R3/所有编译输入未变 | PASS |
| isp_tracking_late | 本轮R2新跑 | PASS |
| tracking_age | 旧R3/所有编译输入未变 | PASS |
| isp_tracking | 本轮R2新跑 | PASS |
| tracking_osd | 旧R3/所有编译输入未变 | PASS |
| tracking | 旧R3/所有编译输入未变 | PASS |
| dynamic_sobel | 旧R3/所有编译输入未变 | PASS |
| frame_metadata | 本轮R2新跑 | PASS |
| wb_controls | 旧R3/所有编译输入未变 | PASS |
| manual_wb | 旧R3/所有编译输入未变 | PASS |
| wb_epoch | 旧R3/所有编译输入未变 | PASS |
| fixed_wb | 旧R3/所有编译输入未变 | PASS |
| presence_modes | 旧R3/所有编译输入未变 | PASS |
| isp_metadata_stop | 本轮R3新跑 | PASS |
| isp_writer_stop | 本轮R3新跑 | PASS |
| sobel_tail | 旧R3/所有编译输入未变 | PASS |
| sobel_view | 旧R3/所有编译输入未变 | PASS |
| observation | 旧R3/所有编译输入未变 | PASS |
| stop_recovery | 旧R3/所有编译输入未变 | PASS |
| display_state | 旧R3/所有编译输入未变 | PASS |
| controls | 旧R3/所有编译输入未变 | PASS |
| cdc | 旧R3/所有编译输入未变 | PASS |
| monitor | 旧R3/所有编译输入未变 | PASS |
| csi_monitor | 旧R3/所有编译输入未变 | PASS |
| i2c | 旧R3/所有编译输入未变 | PASS |
| osd | 旧R3/所有编译输入未变 | PASS |
| pack_boundary | 旧R3/所有编译输入未变 | PASS |
| pixel_interface | 旧R3/所有编译输入未变 | PASS |
| roi_guard | 旧R3/所有编译输入未变 | PASS |
| roi_core | 旧R3/所有编译输入未变 | PASS |
| classifier | 旧R3/所有编译输入未变 | PASS |
| roi_chain | 本轮R3新跑 | PASS |

原厂仿真模型、输入PPC4和有效节拍断言未替换；软件合成样本只证明这些逻辑场景，不代表实物识别准确率。现场相机真正停钟时长未测，也可能有额外物理因素，仍需新镜像确认。

## 构建与身份

TD6.2.168116，综合96275/物理38932退出0并完成bitgen，冻结R2的210输入/70工程源。Routed慢/快角setup+0.280ns、hold+0.020ns，TNS0、违例终点0；Slice13463/21216=63.46%，LUT611304、REG13669、ERAM48、DSP8；STA覆盖92.49%。34max_delay均匹配且ignored0，SDC哈希未变；124/10警告标准化后与下方v1完全相同，既有PLL/I/O、STA未覆盖限制保留。正式镜像fpga/component_inspector/release/tracking_lower_holes_v2_blackfix_20261011/camera_to_dsi_display.bit；1789539字节，SHA-256 `20149f678aabd974d80d2bfec9a15bf2f7225eca0feb031a7f791f1de9a662e9`。R2三项通过后新增恢复帧触及原100ms测试台预算，38686退出1；保持20ms间隔和断言，仅将四帧测试预算按总时长扩为150ms，R3三项85518及额外视图21003退出0；复现与夹具失败各单独保留。

source_commit=null，来源是本记录source_snapshot，而非已提交Git版本。冻结编译输入、测试源/日志、复现、构建报告、脚本、说明和接力断点；旧v1、上方版、静态可调WB的所有清单副本再次校验未变。current_codex_build绑定本轮。

## 下一步实物验证

按40说明核对SHA下载，先RAW正常更新、固定模式VF不再每帧增加，再回到下方孔静止锁定和慢速手动横移。无孔时相机图仍应显示，状态可以NO HOLE/待检测；先完成图像恢复验证，才判断定位/分类效果。记录现场FR/VF/OF/UF、ER/LP/WS、CFG/FPS及模式。
