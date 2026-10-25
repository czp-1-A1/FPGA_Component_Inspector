# P03 改动与跨工程移植

P03在已接受的P02基础上，补充用户新提供的“有件侧立”姿态。当前功能提交为 **`9d4596885b29559f0bb5ed873464c6964cc53b1a`**，成果分支为`lj4747-contest-work`，发布标签为`p03-standing-review-20261025`。软件和真实布局布线验证通过，**P03实物验收待反馈**；P02的“测试正常”反馈只属于P02。

## 改在哪里、增加什么、实现什么

工程根为`fpga/component_inspector/`。P03相对P02没有新增生产RTL模块，100项硬件依赖中98项逐字节保持。累计新增模块及R13到P02的完整接线见[P02移植说明](P02_PORTING.md)。

|位置|修改/新增|实现效果|
|---|---|---|
|[present_surface_check.v](../fpga/component_inspector/user_source/hdl_source/present_surface_check.v)|增加11位中心和`center_total`、10位最亮边和`max_edge_total`；测量开始清零，结束中心窗口保存未取整和，各边完成时更新最大值；最终B边使用`next_max`参与判定|原P02表面证明全部通过后，再检查亮边是否明显高于中心，补充该类侧立复核；不增加图像RAM，不增加测量拍数或端口|
|[compact_template_rom.v](../fpga/component_inspector/user_source/hdl_source/compact_template_rom.v)|两处启用诊断时的标题字符P02改P03|检测和计数页显示P03，便于确认镜像；其他字段、布局和关闭诊断时的原界面保持|
|[sim/standing/](../fpga/component_inspector/sim/standing/)|新增独立单元、RGB、RAW、计数、界面测试及冻结P02对照；原测试与gold保留|证明新侧立只改变有件质量位，旧8场景保持P02结果，覆盖全部8个真实候选、量化边界和帧取消|
|[tools/prepare_p03_project.py](../fpga/component_inspector/tools/prepare_p03_project.py)、[scripts/p03/](../scripts/p03/)|新增P03准备/源范围/像素/软件证据检查；冻结526静态源和100真实编译依赖|其他电脑可复原并核对同一份源码；准备工具保持原seed2，不自动构建或烧录|
|TD `.al`及两个运行`.prj`|仅工程路径重定位|依赖清单不增减，完整SDC和引脚不变|

`classified_pocket_counter.v`、`classified_count_pipeline.v`、视频/DDR、白平衡、按键、帧保护、探针模块、原测试/gold、引脚和SDC均未更改。P03父清单504项中，除两处RTL和三处路径描述符外，其余499项SHA完全相同；新增静态文件是测试、工具和说明。完整差分可看[功能提交](https://github.com/czp-1-A1/FPGA_Component_Inspector/commit/9d4596885b29559f0bb5ed873464c6964cc53b1a)，最小两文件补丁为[P02_TO_P03.patch](../releases/p03_20261025/P02_TO_P03.patch)。

## 为什么需要新增条件

新视频中6个稳定读数仍为P02绿色有件/RS C0：中心176–192、最亮边205–207、最暗边166–171。几何/填充已通过，P02只限制内部边缘不能太暗，无法排除该类亮边侧立。frame47顶部V0的读数已排除；121个手机帧不当作相机帧率。

P03保留P02全部可测性、完整性及比值条件，再加入：

```text
cell5 = floor(floor((一个2×2窗口内四个原生灰度像素之和)/4)/8)
Csum = 中心64个cell5的和
Lsum/Rsum/Tsum/Bsum = 对应边缘32个cell5的和

P03_normal = P02_normal AND
             2*max(Lsum,Rsum,Tsum,Bsum) <= Csum +16
```

区域先累加、再直接比较，不先除64/32取整。+16等价于区域平均允许2个8位灰度级差异。这样避免5位均值取整掩盖亮边差异。中心和最多1984，加16后2000仍在11位内；每边最多992，乘2最多1984。B边使用包含当前特征的`next_max`，不遗漏最后一边。

T100对象仍为kind2“有件”，只把质量失败写入`reason[3]`。低3位尺寸/比例/填充、弱T80的F复核、空穴/定位孔保持。`REVIEW`仍是`PRESENT`子集；76位对象、304位显示对象、608位计数候选和887位元数据均不变。6个稳定现场读数的量化界限支持新增条件会拦住样本，但这不代替P03实物验证，也不是手机视频的RAW重放。

## 按接收工程的基础移植

### 已有完整P02成果

先保存接收工程自己的改动，再合入P03功能提交：

```powershell
git fetch origin lj4747-contest-work
git cherry-pick 9d4596885b29559f0bb5ed873464c6964cc53b1a
```

若源仓库在另一个remote，使用它实际配置的remote名称。不要覆盖接收工程已有计数、DDR或控制改动。三个路径描述符按接收工程目录重新生成；源代码与测试按功能语义合并。

只需人工移植两处硬件变化时，可参考最小补丁。原文件存在混合换行，已经独立验证的命令为：

```powershell
git apply --check --ignore-space-change <P02_TO_P03.patch的绝对路径>
git apply --ignore-space-change <P02_TO_P03.patch的绝对路径>
```

命令针对P02工程根，不是仓库根；完整`project/`和当前Git源已经是P03，无需再次应用。补丁不包含P02前置接线，也不包含新测试。普通dry-run因换行上下文失败的记录和成功复测见[补丁说明](../releases/p03_20261025/PATCH_APPLY.md)。

### 从R13或未具备P02成果的最新工程接入

先按[P02_PORTING.md](P02_PORTING.md)合入P02功能提交`b549237f15aafd3e3979b53f9df88b6877651e27`，再合入P03提交。累计生产RTL为两个新增模块及六个原有模块修改；P03只进一步修改其中两个文件。

必须一起核对：双ROI加上下文的5位缓存、8个实际候选逐一`SURFACE_WAIT`、T100与弱T80来源、`SURFACE_REVIEW && REVIEW_PROBE && REGIONS`使能依赖、ISP元数据等待、源帧/DDR槽/epoch绑定，以及新增模块的TD编译清单。不能只复制新的比较式到旧暗参考路径，也不能为隐藏诊断而关闭分类所需灰度采集。

## 接收工程必须重新验收

1. 核对接收工程的RAW/PPC、灰度顺序、缩放、ROI及同帧取消语义；本版为1920×1080 RAW10/PPC4、1280×720处理、100MHz处理域、HDMI720p60。
2. 通过新单元/RGB/RAW/70帧计数与原有关回归，正常正面仍放行，旧背面/短侧/长侧/背侧及空穴/定位孔保持；不得修改旧gold迎合新结果。
3. 用接收工程自己的完整约束真实综合、布局布线，检查两个角的setup/hold、TNS、CDC和资源；本bit的时序结论不能继承到其他工程。
4. 用自己的灯光、器件与速度做实物对照。P03当前尚未收到实物通过反馈。

本版结果为Slice18385/21216（86.66%）、LUT616565/21216（78.08%）、寄存器21244/42432（50.07%）、ERAM103/108（余5）、DSP28/40、PLL5/6。原完整SDC/seed2实际Routed双角setup+0.010ns、hold+0.020ns、TNS0；46个最大延迟Ignored0、20Gray/6邮箱/SW3审计通过。相对P02的ERAM/DSP/PLL不增加；Slice变化受实际布局影响。

完整验证与重建入口见[P03_HANDOFF.md](P03_HANDOFF.md)，可机读改动表见[INTEGRATION.json](../releases/p03_20261025/INTEGRATION.json)。
