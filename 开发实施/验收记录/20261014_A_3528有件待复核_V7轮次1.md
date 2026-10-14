# A 3528 有件待复核 V7 验证

2026-10-14。软件及构建PASS，现场PENDING。只跑当前同一3528白色器件和同一载带，用户已确认“3258”为笔误。本轮不做多目标、换型或真实偏位量测。

## 变更与来源

分支 `lj4747-contest-work`，HEAD `e604d4fbe4bd40f0d7b40e5fce4ecfda10ea4351`，工作区未提交/推送。最终213生产输入冻结，210项与V6一致，只有 `roi_shape_search.v`、`isp/isp_top.v`、`experiment_osd.v` 修改。TD和所有软件测试的生产SHA完全一致，权威源为同名目录 `source_snapshot` 与 `inputs.json`。

本批13张图的原图/SHA/读码/规则推断已独立归档。图5/6的严格尺寸比例填充通过而NO TARGET，按V6代码推断侧参考失败；4/7还有尺寸/比例/填充超限。侧参考实际计数未显示，不能称直接测得。部分FG受摩尔纹影响，候选读数附近不改变分类。拍屏不能证明烧录bit SHA。

保留严格85%模型，新增长52–86/短40–76/比例1.05–1.8/填充≥75%的实验CHECK包络。主体满足包络、或已严格匹配但侧参考失败时保留有件并标CHECK。空穴和送料孔规则不变。CHECK是匹配/上下文待复核，不能当成安装OK或已测偏位。

## 冻结验证

| 项目 | 轮次 | 结果 |
|---|---|---|
| presence_review | r1 | 20个独立计数的连通掩码，有件/空穴/大孔屏显特征与此前近门限正例、75%与比例边界、侧参考污染/恢复、取消PASS |
| local_search | r4 | 原13个搜索、截断、邻件/孔/背景分离、取消恢复场景PASS |
| local_osd | r4 | 1018496检查像素，D8/V7、黄色有件/FIT CHECK、恢复、同帧锁存、移动框与三拍同步PASS |
| shape_snapshot | r4 | 原37位原子模型字段携带CHECK并恢复清除PASS |
| local_isp | r2 | 16真实RAW10/厂商ERAM输入帧，四视图、形状/侧参考CHECK与恢复、模式/WB/短帧取消、原生FE前结果、完整视频/Sobel PASS |
| 独立原生图参考 | r2 | 12幅实际ISP叠加前PGM，两遍连通标记/并查集参考面积、包围框、分类与CHECK匹配PASS |
| local_video | r3 | 实际校正/RAW/ISP/DDR，CHECK帧被显示槽位选中及恢复清除，零元数据完整视频，614400显示请求/613200非零像素，OFUF0 PASS |
| 其余回归 | r4 | shape_model、shape_osd、writer_epoch、video_fallback_display、video_metadata_fallback、wb_epoch、observation、display_state PASS |
| 完整TD | r1 | 综合、布局、布线、bitgen及最终双角STA PASS |
| 实板与独立新位置样本 | 待现场 | 未测，不声明现场通过 |

合计14项ModelSim测试。特征回放由拍屏调参数据构造合成掩码，不是假装相机原始训练图。原生PGM参考验证的是RTL处理正确性，现场泛化还须以新位置和人工真值复测。

## 资源/时序/CDC

Slice13564/21216=63.93%，ERAM53/108，DSP18/40；相对V6为−95 Slice/+0 ERAM/+1 DSP，布局打包差异不等于减少了功能。建立+0.203ns、保持+0.020ns、建立/保持TNS0，STA92.47%。没有新缺clock、invalid constraint、组合环、no-path问题；125/10告警无新增。

复用37位模型特征bit35，115位记录和198位帧metadata不扩宽；完整图像缺检测结果时零metadata继续显示。SDC与V6完全相同，35显式+2FIFO共37项全部匹配、ignored0；未修改约束换PASS。两位掩码和512队列存储仍推断为5块ERAM，无全数组复位。

## 失败与修正

- r1：新增OSD测试台脚本误给task参数声明尾部追加`0`，测试台编译失败；生产RTL已编译通过。r4只修测试声明，原字体逐像素、颜色、帧锁存和视频断言保留并全部通过。生产输入与r1完全相同。
- r2独立参考首次运行：临时OpenCV模块缺少`connectedComponentsWithStats`，保留失败脚本/日志。改用独立两遍连通标记/并查集实现，不复用FPGA队列、掩码打包或输出值。第二次参考12幅图全部通过；没有改源PGM或放宽比较标准。

失败与复测各自冻结记录保留；V6旧轮次和发布审计不覆盖。

## 发布

镜像：`fpga/component_inspector/release/presence_review_v7_20261014/camera_to_dsi_display.bit`，1789539字节。

SHA-256：`a3d1164e41690a93c9113c6620cc081c63954f0191bffe3d445bcab91d0dfc2c`。

顶部 **D8 LOCAL EXP V7**。操作见 `56_A3528有件待复核_V7实现与上板说明.md`。V6/V5/V4回退镜像保留，未JTAG/Flash、未提交推送，现场PENDING。
