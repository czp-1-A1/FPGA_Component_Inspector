# 独立全视频传输回归（2026-10-06）

本目录仅测试资料。测试端没有修改工程RTL、AGENTS、旧bit或旧冻结证据。

实际模块：roi_sobel_view、data96_128真实3:4打包、video_in、video_out、两侧生成的w128_d512_fifo及其FIFO/RAM行为。输入是合成AWB RGB4PPC；不包括RAW解拜耳/输入guard/真实DDR PHY/DSI/OSD或器件准确率。MC模型在最终O_ddr_user_*_en当前拍接收命令，同DDR域共享端口禁止同时读写；按命令顺序保存读响应，默认40拍返回延迟，可暂停ready/返回。真实MC接口的almost-full ready保持原寄存写一拍的8字余量约定。

## 正常四模式和真实读写争用

- CSI 8.888ns，DDR 15ns，显示 19.23ns；1024×600，256 CSI有效拍+512 CSI行间空闲。
- 每模式两帧不同RGB内容。第一帧完整写入后显示其完整614400像素，期间捕获第二帧；在第二帧尾部的真实video_out读burst开始/进行时ready低300 DDR拍。
- 独立NumPy参考先由坐标/帧ID生成RGB，灰度按(R+2G+B)//4，完整3×3 Sobel |Gx|+|Gy|>=80，处理仅绿色ROI x[256,768)、y[172,428)，边缘橙色ffae64。没有读取DUT内部灰度或梯度生成答案。
- roi_sobel_view逐输出坐标及四lane内容对参考；打包逐128位对参考；最终MC写逐128位/slot/连续地址比较；两完整显示帧逐x/y及RGB比较；新采集槽不得等于active或latest completed槽。
- mode_0..3.console.log均PASS。每模式实际写230400字、读230400命令、显示校验1228800像素。共921600写字与4915200显示像素，全部零差异。第二帧FIFO峰384、读FIFO占用加outstanding预留峰480、OF/UF/LF=0。
- 实际ready低开始时mode0/1 produced114816、camera_used97；mode2/3 produced114624、used145。不能把第一帧已完成后的空闲暂停算成帧尾争用；本测试显式在第二帧重置计数后才开启注入。

## 异常恢复（1024×8；EDGE模式实际行回放）

- CSI最后输入行后40拍停钟50µs：1176/1536打包字、960写字；未发布短帧，保留旧完整slot3。
- 停钟期间预置新early FS然后恢复CSI，新完整1536字/8192像素恢复slot2；LF=1。
- 显示读响应暂停8000 DDR拍：缺字只取消当前显示帧，4行中的末256输出像素置黑，之前像素仍逐坐标匹配；UF=1，不接着右移显示。
- 此时新VS仍有240 outstanding；检查DRAIN期间不复位FIFO或更换active slot；旧响应队列全部回收（old_queue_tail4032）才进入CLEAR且outstanding0。下一完整8192像素仍零差异，UF累计1。
- 采集命令ready低10000拍：只384打包/0写字便实际缓存过载frame_bad、camera_bad置位，capture_ok撤销，保留latest slot2，无FIFO full溢出；下一新完整帧恢复slot3，LF累计2、UF累计1。
- 最终faults.console.log包含STOP_CSI、UNDERFLOW、CROSS_VS_DRAIN/CLEAR、CACHE_OVERRUN和PASS。

## 运行和证据边界

`reference.py`重建四模式两帧RGB/Sobel参考；`run.ps1`编译真实工程源并跑四模式；`generate_fault_tb.py`由完整TB继承真实模块和检查器后生成小高度异常TB；`run_faults.ps1`在同work库编译/运行异常TB。runner必须同时检查进程退出码及明确PASS行；ModelSim -onfinish exit在某些$fatal退出路径仍返回0。

`tested_inputs.json`和`tested_rtl/`记录本次编译源快照。ModelSim 2019.2；vlog无RTL/TB编译警告。优化器保留生成FIFO既有ceb/addrb连接宽度及缺省dib/doa等警告（首次7条/后续缓存0或4条），没有当作修复通过的依据。

`initial_tb_wait_bug/`保留开发测试器期间失败日志：首次误将上一完整帧capture_ok当作当前帧完成，改为当前slot+published+115200实际写字；缺字检测时误把仍应输出的上一拍像素要求为黑，改为匹配原一拍输出延迟；排空旧返回后允许下一帧重新预填，改为在DRAIN→CLEAR边界验证旧outstanding=0。上述均为测试器语义修正，不改RTL或放宽正确像素/完整字数要求。正式PASS仅对应本目录最终TB。

这里证明受控数字链路行为，不能称现场摄像头花屏已上板解决。新的完整ISP/OSD集成回归、TD时序和实物复测由root继续。
