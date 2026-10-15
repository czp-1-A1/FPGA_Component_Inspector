# V12 本地烧录候选：上下双虚线区，各自绑定3528

请使用 `V12_regions_3528_720p60_20261015.bit`。顶部识别码 **DD FRAME EXP V12**。这是V11大视野底座上的区域功能版；不是已完成实物精度验收的版本。

- 1920×1080采集、720p60显示保留；上青/下紫两区，每区最多两个结果，编号1.1/1.2/2.1/2.2。
- 区域和模板编译期设置在source_snapshot/user_source/hdl_source/inspection_region_config.v；改后重新综合布线。两个区当前均为同一白色3528，未实现自动型号识别。
- 按完整轮廓中心归属，轻微跨虚线可保留完整形状。框外不输出结果；定位孔排除；空穴必须匹配自身特征。
- 共同灰度阈值100及原几何值为未标定种子。照片中新视野器件变小，正式像素范围需标尺/实物样本。SIZE/ASP/FILL/REF不代表已确认的缺陷类别。
- 31项仿真、31幅独立参考、双角路由时序通过；实板仍待人工烧录复核。
- 按用户最新要求，本轮仅保存在本地，未提交/推送GitHub，未操作JTAG/Flash。

镜像SHA256：`66393158dc0ac7e42100f6388d9bb03989e6eacc3c6d99f998f0d2177d4578db`（1789539字节）。完整事实及告警见validation_record.md；失败轮次见history；校验全部文件见MANIFEST.json。build_evidence是实际r3构建的归档，不应直接当作已重定位的新工程打开。

## 校验与重放（PowerShell）

需要Python（独立图像参考另需numpy）、ModelSim和TD。路径换成自己安装位置；重放目录用全英文无空格且不存在的新目录。TD本次6.2.168116，不同版本的布局/bit不保证相同。

```powershell
python -X utf8 scripts/verify_package.py
python -X utf8 scripts/replay.py --action verify
python -X utf8 scripts/check_regions_reference.py tests/r4 tests/r3
python -X utf8 scripts/check_hd_reference.py tests/r4
python -X utf8 scripts/replay.py --action prepare --work D:/v12_replay --td-root D:/AAA/FPGA.....YZW
python -X utf8 scripts/replay.py --action sim --work D:/v12_replay --td-root D:/AAA/FPGA.....YZW --modelsim-bin D:/modelsim/win64
python -X utf8 scripts/replay.py --action build --work D:/v12_replay --td-root D:/AAA/FPGA.....YZW
```

若需核对本次保存的路由DB：先prepare到新目录，将build_evidence中的gate.db/pr.db复制到对应新目录，再把scripts/audit_routed.tcl放入新目录并以该新目录为cwd运行TD。先核对MANIFEST；重新路由时仍须复核资源/全部约束/20条Gray预算，replay.build的正建立/保持检查不能替代完整物理审计。

本机TD为6.2.168116，V11 r9来自6.2.178840。不能声称相对V11 r9没有新增告警。PHY-5079落在pll_clk_24m相机24MHz输出网（0个时钟端、1个数据端、3段局部线）；同一旧TD构建的V11 r8也有该网告警。PHY-5088为该输出的数据负载及既有相机/DDR PLL反馈级联，USR-6135为两处既有PLL局部反馈。仍有历史I/O时序约束覆盖边界，STA覆盖92.91%，不宣称所有物理接口已证明。原日志、时钟分析和40条max_delay报告完整保留。
