# A阶段EDGE帧尾直通修复（2026-10-07）

状态：软件修复候选，本机综合、布局布线和镜像生成已完成，实物未复测。源码提交`43a3da6cf36da923835f4e7fb5f03e3bdb5c779f`。用户确认RAW/GRAY持续更新，EDGE和GRAY+EDGE冻结，返回RAW自行恢复。原镜像失败保留于`验收记录/20261007_A_EDGE上板复测_轮次1.md`。

## 原因证据与边界

VF是`video_in.O_lost_frames`，在下一帧开始发现上一帧未发布时增长。ER只记录ISP四类拒帧原因，不能检测所有DDR未发布原因。

冻结旧RTL，在真实RAW10→uial2axis→demosaic→AWB→Sobel→128位打包→原厂异步FIFO→video_in上测试：每行640接收时钟的RAW有效/间断节奏加98空闲时钟，实测AWB LP738；FE后200个CSI时钟后停止CSI，DDR保持运行1ms。相同完整帧115200字的通过条件下，RAW通过，旧EDGE失败：AWB153600拍、视图153268拍，打包114950字、DDR114720字、good1/bad0/ER0/WS0，未发布。连续钟、充分帧尾等待可以成功，因此900拍等待时的DDR未完成不是永久故障结论。保留所有失败和等待时间诊断日志。

该反例证明旧设计依赖额外CSI帧尾时钟，匹配用户现象；尚未测板上HS接收时钟在FE后的实际持续时间，不能把模型停钟当成现场波形证明。

## 最小RTL变化

只改`roi_sobel_view.v`（候选SHA256 `0ae85b3cc597443a83c521a8a96a8a814c88972a34ccea5a4fe7efe279e23512`）。在ROI末行不再等待下方邻域；在y≥Y1的行首、缓存读游标已追上、读流水与最后输出均排空且有完整行FIFO容量时，锁存tail_bypass，后续框外原图直接输出。连续密集输入未满足边界时保留原缓存调度。直通期间下一行无容量则使当前帧失效，禁止发布残帧；early FS及pixel SOF复位状态。核心Sobel、ROI、阈值、灰度/颜色、原帧完整性证明不变。

## 接口、位宽、时序、CDC和资源

- 输入AWB RGB888 96位/PPC4，左到右[95:72]、[71:48]、[47:24]、[23:0]；pixel_sof和第一有效组同拍，pixel_last与行末组同拍，early_sof仍单独用于DDR通知。
- 新增1位tail_bypass状态；沿用8位组索引（256组）、10位行计数（0..600）、原13位核心像素数、24位梯度和。没有新增累加器、DSP或RAM；预期少量比较/选择LUT和1个FF，4×256×96同步行缓存保留ERAM推断，最终以TD报告为准。
- 缓存读请求到RGB输出仍为5个CSI时钟；安全行边界之后的尾部与RAW/GRAY一样为1拍，数据/valid/EOL/坐标同时选择。无组/像素丢失或重复；首行复位和旧帧尾数据屏蔽仍保留。
- 所有变化在CSI时钟域内；不改变原邮箱、异步FIFO或SDC，ready只允许决定完整行启动，不能停相机。FIFO深度有效511、ready条件used≤288，留223字容量，大于192字/PPC4行及打包在途余量。
- tail_bypass在首拍SOF与early FS清除；RAW/GRAY原旁路行为保持。dense fallback、复位、新帧、信用不足、坏帧和恢复均有外部像素/数量/有效性检查。

## 软件验证与使用

原sobel_view 11场景通过；新增sobel_tail 15场景，独立逐像素/3×3梯度/打包比对，覆盖安全直通、密集回退、尾部信用失效和下一帧恢复；真实ISP roi_chain九完整帧场景通过，含四模式、残缺行/长暂停、epoch中途变化及恢复。相同停钟反例的新EDGE和GRAY+EDGE均完整153600拍/115200字并发布。集成isp_writer_stop入口通过。MC共享读写两组RAW→EDGE→RAW、GRAY→GRAY+EDGE→GRAY共比对3686400像素，无错误/溢出/下溢/丢帧。停钟探针的lost=1来自刻意发送的首个4行暖机残帧，完整帧未增加lost；这不等同于MC完整帧测试的lost=0。

本机ModelSim SE-64 10.5（2016.02），原厂ERAM模型未做强制覆盖。使用`sim/run_modelsim.ps1 -ModelSimBin D:/modeltech64_10.5/win64 -TdSimRoot D:/td6.2.1/sim_release -OnlyTests sobel_tail,isp_writer_stop`（PowerShell原生数组参数，或逐项调用）。独立验证必须冻结代码；本轮实际隔离目录分别为工作区外的edge_repro_20261007_baseline、edge_tail_20261007_candidate及edge_tail_mc_20261007_ready。MC首次漏复制参考HEX，连RAW也读出xxxx导致比对FAIL；保留为夹具错误，在新目录复制旧冻结HEX并逐个核对SHA后通过，未修改参考答案或通过条件。尾部直通后read_y不再前进，因此WS仍可能记录尾部credit-low间隔（本轮MC为457），WS非零本身不证明冻结。

TD6.2.168116安装综合时明确License expired，失败日志保留；本机TD6.2.178840在隔离ASCII目录对同一207输入完成综合、布局布线及bitgen。最终setup WNS +1.384ns、hold WNS +0.020ns、TNS均0；slice16424/21216（77.41%）、ERAM48/108、DSP8/40。207输入与提交及工作区逐项SHA一致，只有Sobel文件相对旧输入改变；约束未修改。资源与旧版比较受TD版本变化影响，不能将全部差值归因于新增1位状态。

完整约束检查已执行并保存。STA覆盖94.59%；no-clock/invalid-constraint/无路径约束/组合环均0；DDR PLL频率检查7项与旧冻结报告相同，悬空节点4→2、shadowed约束9→5，仍有39输入/63输出未指定delay和1项partial input delay。最终报告匹配CDC/max-delay路径，早期start_timer的No clocks matched告警也保留。没有把这些遗留告警算作已关闭或宣称全约束通过。

新镜像`fpga/component_inspector/release/edge_tail_fix_20261007/camera_to_dsi_display.bit`，SHA256 `bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65`，1789539字节。旧release保留为失败/回退对照，不能当作本次修复。软件与构建记在`验收记录/20261007_A_EDGE帧尾修复_轮次1.md`，新镜像实物结果另记`验收记录/20261007_A_EDGE上板复测_轮次2.md`，目前未烧录/未测。
