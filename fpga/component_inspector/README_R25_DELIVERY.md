# R25正式本地交付版

R25_DenseDualROI_20261028_09c50dd1.bit，SHA256：09c50dd1fe8c181b91ee2800369785b05ef4f71a7d96b04da4ce4f7b1fec8e2c。

本版针对R24单列正常、双列密集目标超出帧间预算的问题，优化保守空行扫描和队列读取。两个原有3528有效区仍分别001编号、各自总数/有件/空穴/复核/空穴号及逐号事件；分类阈值、计数器、C6完整性保护、时钟和SDC不改，未实现以太网。

22项本候选实际测试全部通过，无旧PASS复用。原14场景/三取消、6密集场景与冻结R24的分类/坐标/候选/trace结果相同；原运动RAW全部11个候选包和trace逐帧与历史R24相同。原12帧RAW两列各001P/002E/003E/004P，24完整显示栅格加部分共22940160精确RGB像素；密集5帧每列10器件及定位孔，4帧结果均在FE后1.207ms内就绪，第5帧晚WB取消，9完整栅格加部分8367437精确RGB像素，零虚假事件。两条RAW均OF0/UF0，独立上下像素核验分别844800/307200。

100MHz直接密集基准140456→97595周期，约减少30.52%；完整native的最大1.206398508ms与简化基准是不同口径，验收按完整链路原27FPS预算。旧R24同输入在第一帧phase10超时，两个中间候选也未过原deadline，均保留且未交付。没有放宽答案或取消C6。

实际TD6.2.168116、speed3、seed2全SYN/PHY自行收敛，strict finalizer重新导出。Routed双角SWNS+.006ns、HWNS+.020ns、STNS/HTNS0；全部46maxdelay、20Gray Q、6计数邮箱、SW3及覆盖审计通过。Slice19278/21216(90.87%)、ERAM101/108、DSP29/40、PLL5/6。原vendor PLL/IO警告并未宣称消除，时序余量仍较小。

实际执行661源SHA 1afd1aae81035d4827071f0cc9a5e4fa68c6f9afdff2a01a9ed7d4760c8e036b，R25_EXECUTED_INPUTS.json保持原字节。最终R25_FROZEN_INPUTS.json只新增本交付说明和专用验收器；661执行输入全部不改。README_R25.md是执行冻结时的候选说明，本文件和validation/r25/verification.json为当前验收入口。R24_FROZEN_INPUTS.json是历史独立工具读取当前身份的兼容别名；旧R24/C2验收器不适用R25。

重新准备全英文目录，目标必须不存在：

```powershell
python tools/prepare_dual_region_r25.py --work D:/FpgaWork/R25_replay --td D:/AAA/FPGA.....YZW/doc
```

准备后的TD入口为td_project/camera_to_dsi_display.al，先syn_1再phy_1。优化由ISP双列参数启用，请使用完整工程，单独替换检测器文件不会更新旧ISP的实例参数。

独立归档复原状态以发布目录PACKAGE_VERIFICATION.json为准。复原只重新核对全部载荷、661执行身份、22测试/像素与已完成物理证据及fresh102依赖准备，不代表再次全SYN/PHY或上板。包内只提供唯一正式bit，旧/未接受的镜像不随包交付。

尚未上板；请烧录后确认COUNT R25，清零/开新段，用原双列相同速度和路径复测编号、空穴号、V与C6。真实坏帧仍应触发保护，不盲接旧编号。原移动有件误复核未通过修改阈值处理，网络协议/跨域接收和历史保存由队员负责。
