# 180mm 定位孔32×32临时采数版

本地候选：`candidate/V12_CAL180_hole32_1092_40_20261016.bit`，SHA256 `89e25b78f42451e125b5e2f73f00c0bcfbc069cac4d2622fdb889582dfe68233`，1789539字节。顶部仍为DD FRAME EXP V12，CAL面板必须显示 **OUT32 CORE16**。

1. 保持180mm、曝光1092、增益40、WB100/100、原焦点和灯3档。先RAW模式，测量阈值100。
2. 把一个定位孔完整放入粉色32×32框、对准黄色16×16核心，避免邻孔或带外亮背景。等PIPE OK和新CAL数字，确认CLIP0，再拍完整屏幕。
3. 同样补测真实空穴。若需要，只对有歧义目标补GRAY模式T80；不重拍整套四模式库。
4. 保留原64框观察镜像测有件；当前有件36×44/46大于32，不能用本版截断的宽高替代它。原64镜像在同级calibration_pending_180mm_20261016交接包，SHA290c7b12a0da9399ebe95ddd88ab1ba0dc3b110ead3d7f809b9b3f062b3fc5de。

CAL1粉框x=[624,656)、y=[304,336)，CAL2粉框x=[624,656)、y=[500,532)。黄色核心位置不变。M/MIN/MAX/SAT是核心16×16统计；W/H/A为32窗内所有阈上前景的联合范围，CLIP0仍不自动证明单目标。转640×360配方时宽高除2、面积除4。

只改临时测量和显示两个生产文件，正式分类器/阈值/配方、有效区、四结果、四模式、631位记录及同帧同槽/视频保护不变。**这是供重新采数的观察镜像，180mm正式配方尚未标定通过。** 助手没有烧录、Git提交或推送。

软件6项针对性测试通过，含10组测量独立参考、两整帧显示/103120独立字模与框线像素、真实ISP/DDR四模式及测量字段迟到绑定。5帧实际RGB trace的测量字段另经NumPy重算；这些链路帧的中心为背景，不冒充定位孔实物验证。原扩展20项运行在所需项目通过后主动结束，未宣称20项全部通过；范围记录见validation/scope_selection.json。

TD6.2.168116双角Routed：setup+0.101ns、hold+0.020ns，TNS0，STA92.86%；Slice16878/21216（79.55%），ERAM94、DSP26、PLL5。SDC未改，38显式+2厂商max_delay全匹配ignored0，20Gray位逐位主导8ns且正slack。保留历史相机输出本地路由、PLL反馈和I/O延迟覆盖边界；不称物理接口全证明。

完整源输入352项（manifest `3774e7a45cb36e553979c7f9685068796a8b84428361ff2fafa902abec1d6655`）、日志/时序/逐Gray审计均在本包。旧ae04观察包不修改。新数据和独立穴位配方复测通过后，再按67计划关闭CAL、恢复正常界面和502位并重新构建验收。

```powershell
python -X utf8 scripts/verify_candidate.py
python -X utf8 scripts/replay.py --action verify
python -X utf8 source_snapshot/sim/check_calibration_reference.py --trace validation/reference_input/calibration_rgb.txt --records validation/reference_input/calibration_records.txt --output independent_recheck.json
python -X utf8 scripts/replay.py --action prepare --work D:/cal32_replay --td-root D:/AAA/FPGA.....YZW
python -X utf8 scripts/replay.py --action sim --work D:/cal32_replay --td-root D:/AAA/FPGA.....YZW --modelsim-bin D:/modelsim/win64
python -X utf8 scripts/replay.py --action build --work D:/cal32_replay --td-root D:/AAA/FPGA.....YZW
```

独立参考需NumPy；TD/ModelSim路径按实际安装改，prepare目录需全新且全英文无空格。重建后仍须运行audit_routed.tcl检查完整约束；replay的正WNS检查不能代替审计。跨TD版本bit不保证同SHA。
