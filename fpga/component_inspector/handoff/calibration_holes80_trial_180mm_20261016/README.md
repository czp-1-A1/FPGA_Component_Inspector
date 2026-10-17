# 180mm白色3528：空穴/定位孔T80候选

已接入新CAL数据，固定180mm/EXP1092/GAIN40/WB100/100/原灯光；同一白色3528和原载带。当前为**上板复核候选**，不是独立实物验收完成的正式版。未烧硬件、未提交或上传GitHub，原正式发布指针保持。

镜像：candidate/V12_CAL180_holes80_trial_1092_40_20261016.bit，1789539字节，SHA256 1f44ce56298285ffd4eed329fdc657047f72887325a956f16720bdd07435b3cf。界面为 **180MM HOLE TRIAL**；标定面板说明 **BODY100 HOLE080 / CAL NOT FROZEN**。

- 有件仍在T100检测，保留已测36x44/46、A1456/1516及内部尺寸下限22/18。
- 小孔另用T80掩码，复用引擎；空穴8..10x8..10像素，定位孔14..16x16像素来自当前两区实测包络。6内部像素间隙不教为空穴。
- 定位孔不占对象，剔除其T100碎片；已识别有件不会被小孔覆盖。小亮块不能仅凭小尺寸改为空穴。此保护不等于所有侧立/翻面等异常已可靠判有件。
- RAW/GRAY/EDGE/GRAY+EDGE只是观察模式，**实际有件100/小孔80在各模式相同**。RAW下CAL T100仍可能显示小孔W/H/A为0，这不代表小孔T80算法没运行；观察其采数可切GRAY。
- 保留两虚线区、每区最多2结果、631位CAL元数据、全部视频优先/同槽迟到/VS保护，SDC未改。默认小孔缓存Y[224,616)，含两区上下16像素余量；以后调整区的纵坐标需同步覆盖此缓存范围。

先在RAW模式、相同设置复核两区：有件与空穴混合时分别显示；只有定位孔不应报空穴；稍跨虚线但中心仍在区内的小轮廓应完整识别。现场识别效果、漏检/误报率及坏摆放的有件覆盖仍未验证，不能由这些合成测试保证。没有独立穴位ID/相机原帧或现场bit读回，四张照片只绑定界面和设置。

9张异常/正常参照图及人工文件名标签已归档，按用户方向统一“有件·摆放异常”，不细分四类；这部分分类尚未启用，当前优先空穴/定位孔。

同一r3冻结源354输入：dcf672905f357ecb8a750d07451989d677b4cc591ad6abcfa4b6f8e91b8f6d20。7项仿真通过：cal180_holes、cal180_body、regions、regions_osd、calibration_osd、local_wait、calibration_chain。小孔9帧27记录，含CAL80精确尺寸/面积、T100有件低灰边缘不改尺寸、孔排除/高门限碎片去重、混合/边界/未测间隙/小亮物复核及取消。完整RAW10/ISP/DDR/四观察模式链路11栅格10945150像素、OFUF0，实际5帧CAL trace经NumPy独立重算通过；另按原CAL数据独立解码比对实际小孔结果。它们不是实物准确率测试。

TD6.2.168116真实双角路由：setup+0.102ns、hold+0.020ns，TNS0、STA92.95%；Slice17074/21216（80.48%）、ERAM104/108、DSP26/40、PLL5/6。**Slice超过内部80%警戒线、ERAM余量4块；暂停新增质量子类/新型号功能**。本轮已共享引擎、只缓存小孔纵带；独立实物复核后才移除CAL显示/额外元数据并重新评估正式版资源，当前不会提前关CAL来宣称通过。

实际DB40条max_delay全部匹配/ignored0；20逻辑Gray位各自8ns预算且正slack，并核对所有生成的源扇出报告。物理路径数量见handoff.json，不能等同逻辑位数。历史相机输出局部路由、PLL/DDR反馈与I/O覆盖边界仍在，不能称零警告或所有外部接口时序已证明。

history保留r0漏检、r1通过及r2资源超限；最终r3修RAM推断并增加保护，未覆盖失败源或降低测试期望。原BODY/孔32/CAL64交付保持。

```powershell
python -X utf8 scripts/verify_candidate.py
python -X utf8 scripts/replay.py --action verify
python -X utf8 scripts/replay.py --action prepare --work D:/holes180_replay --td-root D:/AAA/FPGA.....YZW
python -X utf8 scripts/replay.py --action sim --work D:/holes180_replay --td-root D:/AAA/FPGA.....YZW --modelsim-bin D:/modelsim/win64
python -X utf8 scripts/replay.py --action build --work D:/holes180_replay --td-root D:/AAA/FPGA.....YZW
```

prepare目标须全新、ASCII无空格。构建后从工作目录运行audit_routed.tcl，核对实际DB约束；replay的正WNS摘要不能代替此审计。现场验证完整配方后，才按67恢复CAL-off正常界面并重新综合/路由。
