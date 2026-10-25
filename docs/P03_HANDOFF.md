# P03完整交接

当前`lj4747-contest-work`源采用P03，发布标签`p03-standing-review-20261025`。本版在P02基础上补充亮边有件侧立复核；软件与实际路由验证通过，**P03实物验收待反馈**。用户已要求上传供其他最新工程沿用。改动位置、判据、依赖和两类移植路径先读[P03_PORTING.md](P03_PORTING.md)。

## 版本身份

- 功能提交：[`9d4596885b29559f0bb5ed873464c6964cc53b1a`](https://github.com/czp-1-A1/FPGA_Component_Inspector/commit/9d4596885b29559f0bb5ed873464c6964cc53b1a)，适合已有P02的工程作为移植单元。
- 前置P02功能：`b549237f15aafd3e3979b53f9df88b6877651e27`；原已接受[P02发布](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/p02-present-surface-20261024)保留。P02“测试正常”反馈不外推到新增P03。
- 当前源：`fpga/component_inspector/`，526静态源SHA清单[frozen_inputs.json](../releases/p03_20261025/frozen_inputs.json)，100硬件依赖[hardware_inputs.json](../releases/p03_20261025/hardware_inputs.json)。仅两处生产RTL变化，其余499父静态文件保持；路径重定位独立记录。
- [P03预发布及完整验证包](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/p03-standing-review-20261025)。本版作为预发布供移植验证，不改变P02已接受状态。
- [bit](../releases/p03_20261025/P03_Standing_1092_40_r0_20261025_21d1004f.bit)：1789539字节，SHA256 `21d1004fc74505ae7b5ee0c05aadc9c07cb780a2dd0fd763115b3796def060db`。

本机bit统一在`D:/fpga_download/`。公开完整包保留相同526源/bit/100依赖、合成输入、PGM/HEX、实际路由和回退；原始手机视频、照片及个人路径清单留本机，公开ZIP与本机原始ZIP的SHA不同，见[public_package.json](../releases/p03_20261025/public_package.json)。

冻结源中的P01/P02指南、P03最初本机FIELD_GUIDE、旧`current_*.json`和原始交付收据是当时快照，可能仍写“主源P02/未发布”。当前Git版本、发布和实物状态以本页、INTEGRATION、FIELD_FEEDBACK及上传回执为准。不要修改冻结文件以更新历史措辞；那会改变源码身份。

## 验证范围与限制

|验证|结果|
|---|---|
|单元|39请求，170精确5位均值及和；冻结P02同输入对照；四亮边方向/四RAM相位/+16边界/溢出/取消|
|实际RGB分类|9完整720p帧、72记录、320特征参考；旧8场景整608位记录等同P02；新增8目标只改reason[3]；默认关闭2829736拍等同P01|
|计数|70实际T100/T80帧、140观测、4次越线，含空穴、送料孔、暂停、CSI停止|
|RAW到显示|8源帧/7有效质量帧、28判定/140特征和/70诊断均值，四视图/白平衡取消/同槽迟到元数据；15完整显示帧及部分帧共14623282像素，OF/UF零|
|独立参考|7归档PGM的NumPy重算通过；P03与原默认界面各3686400像素独立参考零差异|
|原回归|24项相关测试通过，原测试/gold不改；未称原72项全跑|
|真实Routed|TD6.2.168116、完整原SDC/seed2，双角setup+0.010ns、hold+0.020ns/TNS0，完整46最大延迟/20Gray/6邮箱/SW3审计|
|实物|P03尚待反馈；单个新姿态/一个曝光条件的屏显界限，不代表所有型号、光照或速度|

首轮新增合成RAW亮边760经ISP后不足以隔离旧/新证明，失败输入和日志保留；仅该新合成输入改840后重跑，RTL、标准、原7场景和旧答案保持。单位生成cwd错误及补丁普通dry-run换行失败也分别保留。单元/RGB/计数/RAW/UI运行日志警告分别为0/52/24/17/0；不称全流程无警告。31组证据索引见[EVIDENCE_INDEX.json](../releases/p03_20261025/EVIDENCE_INDEX.json)。

## 其他电脑复原

需要Python3、TD、ModelSim及有效厂商库/许可证；这些及板卡不会随Git传输。仓库父路径和新工程目录用英文短路径。

```powershell
python scripts/p03/verify_p03.py
python scripts/p03/prepare_p03.py --work D:/FpgaWork/P03_replay --td D:/AAA/FPGA.....YZW/doc
```

`--td`必须是包含`scripts/DefaultFlow.tcl`的目录，本机为TD安装目录下的`doc/`。准备工具拒绝覆盖已有目录，复制冻结源并重新生成TD描述符，恢复seed2；不自动编译或烧录。

在新工程的`td_project/camera_to_dsi_display_Runs/syn_1`、`phy_1`依次用`td_commands_prompt.exe build.tcl`构建；回新工程根执行`td_commands_prompt.exe tools/classified_audit_routed.tcl`，再运行`python tools/verify_classified_physical.py .`。不要单独使用通用准备工具的seed1默认值；新构建必须独立完成物理验收。

新测试入口在`sim/standing/run_unit.ps1`、`sim/standing/run_rgb_count.ps1`，完整RAW/UI为`sim/run_standing_tests.ps1 -OnlyTests standing_raw_chain`或`standing_ui`。旧RTL按Verilog编译，仅TB使用`-sv`。从公开包运行独立PGM/UI重算用`tools/verify_standing_native_rasters.py`、`sim/standing/verify_standing_ui_pixels.py`和包内`verify_original_ui_pixels.py`；这些需要包内对应光栅。

`scripts/p03/verify_p03.py --archive <公开完整包路径>`校验ZIP自身SHA、全部CRC/成员SHA、526源、bit及历史验证证据；不会把核对历史收据称作重新综合或实物通过。P03源不能通过固定P02/R13源码校验，回查旧版须使用对应标签的新checkout。

## 人工复测与后续

先维持EXP1092、GAIN40、WB100/100，看标题为P03。新增侧立应为有件待复核，正常正面应继续绿色有件，原背面/短侧/长侧/背侧/空穴/定位孔及计数应保持。记录完整屏显、PRB和姿态；人负责板卡操作与真值。本轮未替用户烧录。

当前P03已经按用户要求发布供复用；后续实物反馈另存，不回写“已验证”到本次冻结证据。提交/推送/附件的核对回执见`releases/p03_20261025/GITHUB_UPLOAD_RECEIPT.json`（发布完成后追加）。
