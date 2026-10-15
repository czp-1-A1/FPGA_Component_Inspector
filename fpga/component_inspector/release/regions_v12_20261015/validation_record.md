# V12双区模板本地验收（r3构建、r4测试修正）

代码基线2fc4c4318027832f3feda9f193d34565af59a32b；用户最新决定为暂不上传GitHub。本轮不提交或推送，不操作JTAG/Flash。只同一白色3528，自动型号识别、黑色/透明器件及已标定质量类型均未实现。

上下两个虚线区：R1=[400,880)×[240,400)，R2=[400,880)×[432,600)（720p）。每区独立配方、最多两个记录，共四个；按完整连通体中心归属，轻微跨线不截断轮廓。保留V11完整1920×1080视野、2/3双线性缩放、720p60、四种视图、视频优先和同帧同槽结果快照。未知型号显示UNBOUND；定位孔不算有件，无目标不等于空穴。

## 代码与镜像身份

- 实际TD构建r3，346项输入manifest SHA256：7e66e510b5ee7589f8bd3dc708fd78fe8030da52946b74720c0263557b5fd5cf。
- 最终交付r4，346项输入manifest SHA256：64c10628d56471f84562fe5a389e952cca96a7050c5e19f61991ed343ba88f74。
- r3/r4唯一输入差异sim/tb_regions.v：修正作用域外rows[k]并将测试定位孔置于上区。断言及预期数不变。生产RTL/IP/SDC和两个复用测试夹具完全相同。原失败夹具与整体失败日志留在history；不能称r3的完整测试运行通过，不能称r4重新做过TD构建。
- 镜像V12_regions_3528_720p60_20261015.bit，1789539字节，SHA256：66393158dc0ac7e42100f6388d9bb03989e6eacc3c6d99f998f0d2177d4578db。
- 源码在构建时未提交，source_commit_at_build=null；不把后来的Git提交冒充构建时提交。

## 软件与独立参考

31项仿真通过：regions_osd和regions_chain取r3，其余29项取r4，逐项来源/日志SHA见validation/test_provenance.json。新增区域单测8帧、21目标检查；OSD四整幅栅格/2798592独立像素；26FPS、LP0CEF输入链路7源帧、11显示栅格、10945150逐像素DDR比较，OF/UF=0。正常夹具结果在FE后约0.91ms产生，属仿真指标，非实板时延实测。

独立两遍连通参考使用仿真实际输出PGM，核对区域/四条记录/尺寸/面积/分类/诊断/顺序：新区域13幅、原HD18幅，共31幅通过。实物准确率、220mm光学/灰度/像素几何标定仍待测。latest手机图仅说明上下布局与大视野，不能作为原始相机亮度标定或精确V11镜像绑定。

| 测试 | 证据轮次 | 结果 |
|---|---|---|
| process_bridge | r4 | PASS |
| frame_search | r4 | PASS |
| frame_osd | r4 | PASS |
| shape_snapshot | r4 | PASS |
| shape_model | r4 | PASS |
| frame_tailproof | r4 | PASS |
| frame_stop | r4 | PASS |
| frame_process | r4 | PASS |
| shape_osd | r4 | PASS |
| video_fallback_display | r4 | PASS |
| frame_wait_metadata | r4 | PASS |
| video_metadata_fallback | r4 | PASS |
| writer_epoch | r4 | PASS |
| wb_epoch | r4 | PASS |
| observation | r4 | PASS |
| display_state | r4 | PASS |
| roi_guard | r4 | PASS |
| video_first | r4 | PASS |
| video_late_display | r4 | PASS |
| frame_cadence | r4 | PASS |
| hd_resize | r4 | PASS |
| hd_guard | r4 | PASS |
| hd_scaled_guard | r4 | PASS |
| hd_osd | r4 | PASS |
| hd_search | r4 | PASS |
| hd_chain | r4 | PASS |
| hd_pins | r4 | PASS |
| hd_pll | r4 | PASS |
| regions | r4 | PASS |
| regions_osd | r3 | PASS |
| regions_chain | r3 | PASS |

## 路由、资源与告警

Routed Slow/Fast：建立+0.137ns，保持+0.020ns，TNS=0。Slice15936/21216=75.11%，较V11 r9增加1212（工具版本不同）；位于70–80%复核区，新增区域/四对象功能保留正时序，无缓存复制，暂不加额外功能。ERAM94/108、DSP26/40、PLL5/6均与V11相同。SDC逐字节不变；38显式+2厂商max_delay共40条非零匹配、ignored=0；20个Gray位逐位主导8ns预算，shadowed/ignored=0，slack均非负。

本机TD为6.2.168116，V11 r9来自6.2.178840。不能声称相对V11 r9没有新增告警。PHY-5079落在pll_clk_24m相机24MHz输出网（0个时钟端、1个数据端、3段局部线）；同一旧TD构建的V11 r8也有该网告警。PHY-5088为该输出的数据负载及既有相机/DDR PLL反馈级联，USR-6135为两处既有PLL局部反馈。仍有历史I/O时序约束覆盖边界，STA覆盖92.91%，不宣称所有物理接口已证明。原日志、时钟分析和40条max_delay报告完整保留。

## 待现场复测

烧录本地DD FRAME EXP V12后确认RAW实时、上下虚线位置和编号。各区依次验证有件/真实空穴/双目标、定位孔排除、框外干扰、略跨线、完全移出、复位和四种视图。灰度100与旧几何仍为调试种子；新大视野器件更小，必须采同距离/焦点/光照的有件、空穴、定位孔和同平面标尺建立正式配方。底部MEAN/MIN/MAX仍是原中心观察ROI统计，不是每个对象/区域的均值。SIZE/ASP/FILL/REF是模型诊断，未标定为偏移/旋转/立起/翻面。
