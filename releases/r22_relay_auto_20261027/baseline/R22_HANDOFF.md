# R22接棒入口

本分支`r22-local-edge-20261027`的当前工程是R22灰度+局部Sobel联合识别与计数，`fpga/component_inspector/`为精确615冻结源。用户最新反馈：**R22稳定性不错，正常速度没问题**。高速及首末/连续空等完整现场边界仍待验证，不能把仿真通过写成所有速度实板通过。

## 获取与核对

```powershell
git clone --single-branch --branch r22-local-edge-20261027 https://github.com/czp-1-A1/FPGA_Component_Inspector.git FPGA_R22
cd FPGA_R22
python scripts/r22/verify_r22.py
```

冻结manifest SHA256：`8e81b47dcd40d88b461aae525e946d5c41bd175691bc66f896b9dc34989541bf`。烧录镜像：`PocketCount_SW3_LocalEdge_r22_20261027.bit`，SHA256：`a07bd753296d320c495f234669477563f1f34cdc60af87089575b3bc1bad4df2`。完整源码、144真实日志/像素/事件、失败/复测和物理证据在`releases/r22_20261027/PocketCount_SW3_LocalEdge_r22_20261027_full.zip`；ZIP SHA：`1ffbc00ab9b2573da938afa623d238f3545a2b4b89a8acda5962b7cc2917d8d6`。同目录有烧录说明、SHA、交付回执、FIELD_FEEDBACK和冻结输入。原包保持原字节，路径记录属于历史证据；复原用下面的可携入口。

## 运行与复原

TD6.2.178840、ModelSim10.5、Python3；独立像素参考还需NumPy/Pillow。先校验，再在新的全英文短路径复原，禁止覆盖已有工程：

```powershell
python fpga/component_inspector/tools/prepare_portable_project.py --source fpga/component_inspector --manifest releases/r22_20261027/frozen_inputs.json --work D:/FpgaWork/R22_replay --td D:/td6.2.1
```

TD入口`td_project/camera_to_dsi_display.al`。复原只重定位描述符并生成102依赖，不等于重新综合/路由或实板验收。完整包内`workflow_scripts/`是本机历史调度脚本，含原D盘绝对路径；跨机先用上面的可携源准备，重跑脚本须明确新目录，不盲跑历史脚本或旧R13/P03/R19校验器。原包`validation/reference_tools/verify_all_references_r22.py`和完整测试捕获支持46参考独立复算。

## 本版改了什么

- `local_edge_surface_check.v`：同一5bit灰度缓存串行四向3x3有符号Sobel，至少3侧内亮外暗，不增加图像ERAM，不依赖显示MODE。
- `frame_shape_search.v`：原先真空穴6x6变7x6会撞定位孔规则；先保留真实候选，再联合同排、尺寸/形状、50%最低填充/90%最高加1格余量、暗背景与Sobel。宽候选需同帧独立孔排证据，相隔24..80源像素，不能自证、不能按孔距补目标或补计。
- P03灰度仍保留；边缘不足的有件只置待复核，不转为空穴。ISP/top启用LOCAL_EDGE_ASSIST，默认模块参数仍为0、生产为1。
- 两页标题DETECT R22/COUNT R22，保留中文有件/空穴/待复核、Logo、空号/LAST。计数器、局部恢复、元数据、控制、ROI、完整SDC和旧133bench答案不变。

## 验证与边界

144软件实际执行candidate_r3/611输入；最终candidate_r6/615仅修非执行Python参考语法/模式PASS派发、UI可携CLI并增加4参考工具。全部生产/bench/runtime与R3字节相同，按真实compile/runtime/log SHA严格聚合到最终manifest，无展开排除。46独立参考、完整归档3874载荷/615源/144日志/102依赖复原并重算通过；不能声称用不同生产输入跑过测试。

最终Routed **Slice19016/21216=89.63047%，ERAM101/108，DSP27/40，PLL5/6**；原SDC/seed2，setup+0.001ns、hold+0.020ns、双TNS0。46max-delay匹配Ignored0、20实际GrayQ8ns全路径、6邮箱和SW3扇出审计通过。setup余量很小，后续RTL变更要重新冻结并验证，不能直接复用本bit时序结论。DDR/PLL/I/O既有工具告警保留。

## 现场操作与下一步

SW4上检测/下计数；SW3先上再下开新段；K3+K4长按1秒全清RUN/累计/空号。保持已用机位和EXP1092/GAIN40，已知15穴5空正空001002008013015、反001003008014015。每趟清零重开，慢/常用/较快正反对照，重点首空、末空、连续空、停车、清零、四模式。用户本次已报告正常速度稳定；继续收高速数据和原页TR1/2诊断，再定位漏检/误判/计数关联，不凭周期造数。不要同一RUN退回重走后当独立准确率。

## Git与交接保护

上传父为远端工作分支`277bcbda44cc1ca73e4dde5c7322169e5572ea7c`（R19），该分支及旧release保持；本R22以冻结快照整体置入独立分支，不能把父R19当作本版增量来源。实际算法来源为R21冻结589源及本聊天R22修复，P03参考提交372c0f0c0a3f9340a5c686aa6515b97b172594c9。原Example和其他根目录沿用，旧版本固定标签仍有效。

只有一个实现端写入。R22生产冻结未再修改，无本聊天构建/仿真进程；未操作板卡/JTAG/Flash/用户TD窗口，无子代理。r22临时跟进已删除，r12保持暂停。先核对分支/HEAD/git status，再开新工作；基于当前真值和用户反馈接手，禁止边测边改答案、放宽SDC或掩盖失败。源码上传commit以本分支`git rev-parse HEAD`为准，上传回执在本机记录并经远端复核后给用户。
