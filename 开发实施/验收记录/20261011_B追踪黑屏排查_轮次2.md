# 第二轮黑屏排查及D3发布条件诊断

现场状态：用户报告v2后仍黑，RAW和复位均不能恢复；新照片FR=2441、VF=2440、ER=0、LP=02E2、WS=0、OF=0、UF=0、CFG=1、FPS=26，显示FRAME STALE/ROW0。照片保存在同名目录。用户尚未独立确认板上镜像SHA。

## v2遗漏的测试边界

对冻结v2原厂模型的实际ISP/metadata/writer补测 `+TAIL=0`，保持原完整帧通过目标，测试失败：AWB153586、VIEW153585、PACK115188、WR114960、camera_count115188、good0/bad0；metadata_ready1、pending0、wait0、camera_epoch2/writer_epoch2、metadata_matches1。缺12个packed字，DDR尾突发未完成。原20拍尾部测试依赖额外CSI拍；原夹具下一FS前还有900拍冲刷。失败日志另存，不覆盖v2已通过的日志。

这证明软件仿真的覆盖缺口，不能直接证明板上CSI停止时刻。原生FS会清旧ROI处理上下文；真正修复须同时证明旧processed尾部及DDR剩余字能在新帧重置前完成，并保留全600行/115200字/epoch校验。

只读审查同时确认：v2的210生产输入/正式bit来源一致；178位metadata字段和top连接正确；现有实际ISP测试未包括top中image_correction这一拍。SC500CS本地数据手册未提供连续时钟配置依据，不猜测其他传感器的0x4800寄存器。

## D3范围与通过目标

D3是诊断版，未声称解决黑屏。仅添加上一帧发布条件的只读采集、DDR到HDMI稳定邮箱和顶部 `D3 Pxx Wxxxxx` 显示。ISP、ROI、完整帧发布及DDR读出逻辑保持v2。

- `W`：该采集帧关闭前已提交MC端口的字数，包含关闭边沿上最后一条写命令；十六进制显示，完整帧115200=`1C200`。
- `P`：sticky条件，从高到低为published/current_metadata_epoch/ready_and_epoch_match/camera_done/frame_good/frame_bad/exact_word_count/frame_open。
- 每个FS关闭上一帧后清当前累积；首个FS与复位保持零。排除FIFO复位期，避免旧done/good直接污染下一帧。
- sticky位表示各条件曾出现，不保证同时出现。若所有前置位都到过而未发布，还要查撤销/时序，不能仅凭P断言发布门控故障。
- OSD在显示帧起始快照，不在当前画面中途更新文字。新增三条SDC约束沿用稳定邮箱预算，不切断跨域路径。

## 本轮执行记录

主线程唯一写入，分支lj4747-contest-work，HEAD3be3967f2457622566fb20b7cef3aa5038e7d885，未提交/未推送。

R1冻结diagnostic单元失败：测试使用上一完整帧留下的capture_ok作为新帧发布证据。失败库及日志保留。R2只修测试为当前published，不改RTL、不降低残帧拒绝目标。

R2冻结210生产输入，publish_diag单元PASS：首FS/复位、完整/短帧/metadata等待/坏帧与恢复、无跨帧继承、最后MC命令与FS同拍。tracking_osd逐像素验证D3字符和帧内固定，原osd/frame_metadata/isp_metadata_stop/isp_writer_stop五项回归PASS。共六项新测、28项编译源闭包未变复用；综合/布局布线PASS，Routed慢/快角setup+0.351ns、hold+0.020ns、TNS0；Slice13698/21216=64.56%，ERAM48、DSP8；STA覆盖92.36%。37条max_delay均匹配/ignored0，124条综合与10条物理告警内容与v2相同。

上板结论：PENDING。无JTAG/Flash操作，不能以软件通过替代现场恢复画面。

构建审计第一次因假设报告的新增约束都排列在末尾而失败；核查集合证明原34条全部仍在、恰增D3三条。改为逐条计数集合比对，不放宽Total>0/ignored0、37条总量或旧约束保持的要求；旧审计脚本保留。RTL、约束文件和构建镜像未改。

正式D3镜像：`fpga/component_inspector/release/tracking_publish_diag_d3_20261011/camera_to_dsi_display.bit`，1789539字节，SHA-256 `7cda6149c57585308e26dce31bd6acbb28cb1a4fcdf9b97c63a3d59bc3c87c54`。详细输入/时序/测试见audit.json及manifest.json。
