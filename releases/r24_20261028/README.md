# R24双列完整工程交接

固定源码分支：`r24-dual-roi-20261028`。固定发布标签：`r24-dual-roi-20261028-release`，基线R23提交`6f2d91cff2280b8b4a53ae08c7fc74fe58406f7a`。

[下载完整工程、bit和校验文件](https://github.com/czp-1-A1/FPGA_Component_Inspector/releases/tag/r24-dual-roi-20261028-release)。完整包约165MB，包含654冻结源、1560项载荷、真实RAW/显示仿真、最终路由DB、时序/约束证据及原失败记录。Git源码分支同时提供完整可移机准备的工程输入；大包使用发布附件。

两列各自001编号、独立总数/有件/空穴/复核/空号。以太网队员先读[逐号事件接口](../../docs/R24_HANDOFF.md)：两路可能同拍有效、无反压、100MHz域；区域+run+id为键，kind=2且reason=0为正常有件，kind=2且reason非0为复核，kind=3为空穴。网络跨域缓存、发送及长期历史由队员实现。

## 下载和源身份核验

```powershell
git clone --single-branch --branch r24-dual-roi-20261028 https://github.com/czp-1-A1/FPGA_Component_Inspector.git D:/FpgaWork/R24_git
gh release download r24-dual-roi-20261028-release --repo czp-1-A1/FPGA_Component_Inspector --dir D:/FpgaWork/R24_download
python D:/FpgaWork/R24_git/scripts/r24/verify_r24.py --archive D:/FpgaWork/R24_download/R24_DualROI_20261028_0ce9f606_source_and_evidence.zip
```

也可直接用发布页下载，`verify_r24.py`只需要Python3.11+标准库。核验会重算654源、完整zip/bit、1560载荷、19项测试日志身份（12实际执行、7输入身份复用）、实际路由及原RAW事件证据，不能将此称作重跑所有测试或上板。

## 移机准备与打开工程

在Git工程的`fpga/component_inspector`目录运行，目标路径必须不存在且为ASCII无空格；`--td`替换为当前电脑TD安装目录下包含`scripts/DefaultFlow.tcl`的目录：

```powershell
python tools/prepare_dual_region_r24.py --work D:/FpgaWork/R24_replay --td D:/AAA/FPGA.....YZW/doc
```

随后用TD打开`D:/FpgaWork/R24_replay/td_project/camera_to_dsi_display.al`。工具会重新生成本机位置描述符并核验102项项目/IP依赖，保留原器件speed3、SDC和seed2。完整重建先执行syn_1/build.tcl，再执行phy_1/build.tcl；当前交付镜像另经过原厂post-route reroute ultra和relocation high收敛，原失败/优化/最终DB与日志在完整包build_evidence。源/时钟/SDC不改。重新构建仍须重新完成两角时序与所有约束审计，不能因同RTL直接认定新布局通过。

## 镜像和验收边界

bit：`R24_DualROI_20261028_0ce9f606.bit`，SHA256 `0ce9f60635aa00f2318eb04403e604f166e92a6770606ed323bddc0549f29e20`。

完整包SHA256：`2f5f7ce1a620071019013b22e8926b6ec2a7dabee440e4596800f857580b40c4`。实际执行652输入SHA `d726f624132ea610b5d2010648f50f765dbc3b151e26de44ffce88ee23f19e9e`；最终654源SHA `af9915f0910895ef0dc427e4d01b350323bc190e8db3b26a762b2124935123c1`，仅另加验证器/说明，全部执行输入原字节保持。

完整RAW两列各P/E/E/P、24完整显示栅格加部分共22940160像素、OF0/UF0通过；独立844800实际像素参考通过。实际Routed双角SWNS+0.002ns/HWNS+0.020ns，STNS/HTNS0；46约束无忽略、20 Gray位、6计数邮箱/SW3/覆盖全部通过。Slice18460/21216、ERAM101/108、DSP28/40、PLL5/6。

建立时序余量较小，尚未实板验收。合成输入下OF0/UF0不能证明现场掉帧或R23移动误复核已解决；每区仍为本段相对号001..300，顶层未接以太网或提供任意历史编号查询。
