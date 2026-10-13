from pathlib import Path
r=Path(__file__).resolve().parents[2];p=r/'fpga/component_inspector'
a=r/'AGENTS.md';s=a.read_text(encoding='utf-8')
s=s.replace('本批尚未完成新RTL仿真/TD；原SDC不改。','已完成状态/OSD/实际监测停钟定向测试；6状态底部图和完整614400像素与独立参考一致。14项完整回归待完成；原SDC不改。')
s=s.replace('生成24×24中文字模/8×16 ASCII/96×64 Logo同步ROM和3级OSD；状态、字模、逐像素及真实RAW→ISP回归通过后隔离TD综合/布局布线。','字模33中文/32ASCII和96×64 Logo、3级OSD已完成，综合确认5新增ERAM（总36），DSP8、LUT15232/REG15864。真实RAW→ISP集成第6帧已通过检查，尚在跑第7帧。随后跑14项完整回归并读最终TD报告。')
s=s.replace('无后台构建；设备由用户管理','ModelSim定向roi_chain和TD布局布线正在运行；隔离构建tmp/sample_ui_td_build_20261005，TD为td_commands_prompt.exe；设备由用户管理')
a.write_text(s,encoding='utf-8')
doc=r/'开发实施/04_FPGA接口与异常处理约定.md';s=doc.read_text(encoding='utf-8')
s+='''

## 6. 2026-10-05取样界面接入

用户明确采用取样界面。本版保留原classifier采集帧新鲜性，另用roi_result_snapshot发布最近完整显示记录。正常native FS仍撤销classifier当前帧判定，但不清上一完整显示记录；新sample_new后再等一采集时钟，让新类别与新MEAN/MIN/MAX同一快照发布。坏帧、lane/config和sample_valid撤销记录，FS抢占取消待发布旧帧。

ROI邮箱从27位改为28位：bit27完成翻转；bits26:25状态（0未标定/1等待/2有件/3空穴）；bit24统计有效；bits23:16均值、15:8最小、7:0最大。bit27只在新完整记录发布时翻转，邮箱轮询不翻转。数据不是DDR显示帧绑定，“最近采样”不声称当前帧质量。

显示域roi_display_state检查CFG、独立监测域FPS和实际EXP/GAIN。曝光/增益变化、CFG0、FPS0或无效记录撤销旧有效性；参数/输入恢复有32像素时钟稳定等待，期间记录旧token以排空旧跨域内容，之后必须新完整token才恢复。标定匹配恢复还需新分类token，不允许从保留的统计重建旧类别。累计L/F/I/G只作历史提示，不永久锁故障。

跨域预算不改。CSI周期8.888ns、相机配置时钟41.667ns、HDMI像素19.230ns；每个邮箱从源捕获到显示最多4目的周期，请求/应答往返再包含3源周期。保守相机→CSI配置撤销→ROI显示总传播按(4×8.888+3×41.667)+(4×19.230+3×8.888)约264.1ns估计，32像素周期615.36ns留有余量；接收端曝光比较另有1采集周期，合计仍小于615.36ns。这是持续有钟条件下的物理/同步上界；CSI停钟时由独立FPS撤销，恢复不能凭冻结内容重启。真实相邻采样约37ms，明显长于完整邮箱往返；1bit完成标记不作为任意高速事件队列。

OSD统一3像素时钟：坐标/地址与RGB第1级，同步ROM及元数据第2级，叠加第3级；DE/HS/VS/ENABLE旁路一致。动态字段在VS边界锁存，BCD需16拍，依赖原HDMI垂直消隐；显示撤销最多再等一显示帧边界。上下条[0,80)、[504,600)，不改变原视频坐标或ROI。字模/Logo使用同步ROM，最终ERAM映射须以TD报告确认。

当前CLASS_CALIBRATED=0、T=0占位不改。人工状态注入/阈值仅用于仿真，不代表实物分类或准确率。输入停止检测沿用1秒FPS窗口，约1～2秒；HDMI停钟/显示器断线仍需现场观察。本轮最终仿真与布局布线状态见21实施说明及独立验收记录。
'''
doc.write_text(s,encoding='utf-8')
sim=p/'sim/README.md';s=sim.read_text(encoding='utf-8').replace('当前默认共12项','该批默认共12项')
s+='''

2026-10-05取样界面批次：当前默认14项，新增display_state及stop_recovery。保留原12项；roi_chain另外检查真实ISP的完整记录发布/异常撤销。display_state使用真实28位邮箱和classifier，不依赖强制覆盖，验证正常FS保持、atomic记录、无效/配置/配方/停流/恢复和旧内容。stop_recovery直接停CSI时钟、保留独立50MHz监测和HDMI时钟，将1秒窗口缩为1000参考拍，测试两端停流相位及恢复新采样要求。定向命令：

```powershell
./run_modelsim.ps1 -OnlyTests display_state,stop_recovery,osd,roi_chain
```

OSD为三拍延迟；完整1024×600及六种1024×96状态条逐像素与独立Python布局参考比对，检查字体/Logo、双框/灰度/框外彩色、状态优先级和整帧快照；参数检查65535和前导空白。输出osd.ppm与osd_state_0..5.ppm。它们是仿真图，不是实物画面。辅助Icarus入口已接入小ROM，但本轮主要验收仍用ModelSim。

字模和Logo生成脚本generate_osd_assets.py依赖Pillow、本机微软雅黑/Consolas和原Lab3 Logo（输入SHA在osd_assets/manifest.json）。生成33个中文字和32个ASCII，无完整字库。生成的3个Verilog ROM已是综合输入，不需要在别台电脑重新装字体或运行生成器。要复刻原素材请核对输入SHA；布局参考由render_osd_reference.py生成，需在运行OSD测试前保留osd_assets/reference.hex和state_0..5.hex。生成脚本也会写experiment_osd.v，仅在有意再生成时运行。
'''
sim.write_text(s,encoding='utf-8')
print('Checkpoint and interface/simulation documentation updated.')
