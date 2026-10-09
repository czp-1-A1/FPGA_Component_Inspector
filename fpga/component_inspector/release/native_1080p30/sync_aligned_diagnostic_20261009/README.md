# C 1080p30 同步对齐色条（诊断，待上板）

TD易失下载根目录C_1080p30_sync.bit；AL为td_project/sync_aligned_fhd30.al。
旧Flash、A/B、原相机和厂商TPG包保留。人操作板卡，本端不烧录。

相对于失败A，C仅将VS首尾边沿与HS前沿对齐。RGB色条、1920×1080、2200×1125、
74.25/371.25MHz级联PLL、串行器/ODDR和四对TMDS引脚保持原方案。独立布局。
HS为[2008,2052)，VS从活动坐标(y1083,x2008)至(y1088,x2008)，5整行；
前沿定义的front=4、back=36，总1125，30Hz目标不变。没有AVI/音频、相机或DDR。
正确相位是CTA官方Figure2的HS定义行语义，不是减少帧总数或改变采集目标。
这是具体时序差异修正，尚未证明它是实物失败的根因。

参考依据：https://www.cta.tech/cta-861-ovt-calculator/ （公开Figure2）
作者实现交叉核对：https://raw.githubusercontent.com/hdl-util/hdmi/master/src/hdmi.sv
新接收参考在运行前冻结：反解三个实际串行数据引脚，比较2073600个RGB像素、1080行、
2475000符号和全部边界；VS区间按平坦像素坐标计算并断言首尾与HS沿重合，PASS。
旧A新相位准则反例明确失败，raw Fatal日志保留于legacy_a_negative；这不是C失败，
也不事后改写原A旧计数准则PASS的有限范围。全帧采用严格5:1理想时钟＋原厂ODDR，
真实生产PLL源码与A/B相同；本轮未重跑真实PLL模型或实测板上时钟。
独立厂商核AVI观察：6630包ECC、2个RGB/VIC34包校验通过，见vendor_avi_observation；
只是实际核并行符号的理想时钟测试，不据此认定原物理链信息包通过或误VIC为根因。

TD6.2.178840完整综合/P&R/bitgen，setup/hold TNS0、违例端点0，WNS见diagnostic.json，
详细资源/时钟地点/相关像素至串行路径/告警见reports。复位和4路TMDS板级预算仍开放，
PHY-5016保留，不能称完整物理路径闭合或上板已通过。原25相机测试本轮未重跑。
15项预冻结输入＋6项由冻结脚本生成的构建文件另存SHA；参考、模型SHA和日志均归档。
early_rounds保留第一轮参考/输入/日志：C完整帧和TD通过，旧A触发预期相位Fatal，
但运行脚本错误依赖ModelSim进程退出码将其归为执行失败。修正只涉及结果归类；
参考和RTL不改，第二轮重新冻结并运行正反例/完整TD。不抹去第一轮记录。

用户已确认A输入不支持、B能显示色条，B不是相机/DDR/采集FPS验收。
C只验证这一个同步差异；记录是否色条/输入不支持，若能显示还需信息菜单实际分辨率/Hz。
阶段2人工门槛没有通过，完整EDGE/组合不准入，分类UNCAL。
rollback.bit为仓库旧候选，SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65；
不声称它就是用户Flash中能用的旧文件。烧录及回退沿用人工易失操作。
