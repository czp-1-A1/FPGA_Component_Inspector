# R19完整交接（2026-10-26）

## 版本与边界

固定标签r19-robust-empty-20261025；分支lj4747-contest-work。发布父提交372c0f0c0a3f9340a5c686aa6515b97b172594c9为P03上传回执；R19功能来自本机R18集成路线，包含索引候选存储、计数关联/局部恢复、UI与缓存优化及P03有件侧立复核。不能将这次完整工程替换误当成P03的两个文件补丁。

冻结559源manifest SHA `684e4fa0c723d0f38c14b0acb7f54e39c3e12e5f3fd00e89f1733a0b89f6bd0e`。bit `PocketCount_SW3_RobustEmpty_r19_20261025.bit`，SHA `feaa11d1df1e009b10b239da85916f4c7709cf80a9d77c44850250a68800b444`；公开完整包 `PocketCount_SW3_RobustEmpty_r19_20261025_github_full.zip`，SHA `e5dfa85b7adb17481320f045a78b0bd8f6aae2e499a82a940abf41fa34a79e41`。桌面原ZIP保留原SHA1871bad718c7a02eeed59dd36f2bde34f95a35096f5ed2efe10761d34da52a74，不能混用。公开派生仅移除本机手机输入路径清单，不改559源/bit/刺激/答案/112日志/原生与UI捕获/物理证据。

## 实现

在同帧实际有件行、真实T80小连通块、至少2格T100核心、原尺寸/暗区/定位孔和器件内部排除的保护下，ROBUST_SMALL_EMPTY允许微小亮点缩小后的宽高/填充变化。不按孔距补造穴位，不新增图像RAM或FSM拍。top/ISP启用，UI标R19。相对R18只有frame detector、参数传递和标题层生产变化，counter/pipeline/局部恢复/元数据/ROI/controls/SDC/灰度缓存/P03表面判据原字节。

相对当前GitHub P03主源，实际26份原输入变化、58份新增、25份P03独有文件保留；逐文件列表见INTEGRATION.json。旧P03/R13自带冻结标记是历史身份，不应覆盖R19_FROZEN_INPUTS与当前交接。其他开发机原D:/fpga_download路径只作历史；本聊天R19用户指定桌面交付已保留，不擅自移动旧bit。

## 验证与限制

112软件：63项本轮实际重跑，49项全部实际编译/runtime/日志精确同SHA复用；旧104测试/答案不改，新8显式启用新分支。26套独立参考通过。24帧形状AB12正/12负，5组有限15/P13/E2（空号003、014）左右/不同位移RGB，四幅720p共3686400像素0差异，新RAW11源37目标和4个事件/源帧独立匹配。合成像素不是手机视频还原的相机RAW。

TD6.2.178840、原SDC/seed2，真实Routed Slice18971/21216=89.42%、ERAM101/108、DSP27/40、PLL5/6，setup+0.060ns/hold+0.020ns/双TNS0。46最大延迟匹配Ignored0，20实际GrayQ8ns及全部选中物理路径主导，6邮箱和SW3扇出严格通过。既有DDR/PLL/I/O工具告警保留，不宣称零告警。

原桌面包1539载荷、559源/112日志/101真实硬件依赖独立恢复，26参考及完整物理审计从解包重算通过；末次独立Desktop全部SHA复核通过。探索语言编译、HYST3/HYST4独立checker接入及封包启动前语法错误均保留，不改冻结答案或约束。此次上传只校验/复原已验收源与证据，不冒称重新运行112RTL或重新布线。

**新实板反馈仍未完整通过**：同一15穴/3空、正向002/008/015，慢速反馈正常，正常速度正向/反向仍少计，另一聊天正在分析，不改变此冻结R19。不能宣传常速/高速已经稳定，见FIELD_FEEDBACK.json。当前每RUN单向，往返每趟SW3重新开段；原C5保护保留。

## 接收与下一步

1. 核对分支/HEAD/工作区及当前写入端；固定R19验证使用标签，不追逐未来分支HEAD。
2. python -B scripts/r19/verify_r19.py --archive releases/r19_20261025/PocketCount_SW3_RobustEmpty_r19_20261025_github_full.zip；检查559源/bit/全部公开载荷/112日志和真实约束。该工具不会重跑RTL或26图像oracle。
3. python -B scripts/r19/prepare_r19.py --work D:/FpgaWork/R19_replay/fpga/component_inspector --td D:/td6.2.1；只在新目录复制和重定位工程，确认101实际依赖及完整SDC/seed保持。旧Example、P03/P02/R13发布不动。
4. 继续现场问题时先看同一冻结R19、原光照/机位/EXP1092/GAIN40的新真值；先区别源检测缺失、候选保留与计数关联。不按周期补数，不因软件通过宣称板测通过。需要修改则另冻新版本重验。

SW4上检测下计数；SW3上再下开新段；K3+K4长按1秒RUN/累计/空号全清。最多300，TOTAL=PRESENT+EMPTY，待复核为有件子集，两页/中文/安路Logo保留。公开发布不含板卡、TD许可证或本机进程，无JTAG/Flash操作。
