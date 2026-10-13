from pathlib import Path
root=Path(__file__).resolve().parents[2]
agents=root/'AGENTS.md';text=agents.read_text(encoding='utf-8')
text=text[:text.index('## 当前断点')]+'''## 当前断点（2026-10-05）

- **目标与断点**：用户回复“可以”批准17稿，本批已实现512×256灰度观测＋中央80×80青框核心统计，默认UNCAL。12项ModelSim通过、综合完成，独立TD布局布线进行中；尚未冻结或上板，不当作完整A验收。
- **分支/基线**：hx1p35a-contest-work，HEAD f87ccf1c6a38e84b58a4f86cecd532a71ae56e89；fpga/component_inspector。原工作区及5个冻结release保留。最新已发布基线roi_classifier_20261004，SHA e9ae1233a592f5d500d8b30cabbcb17acbf82c6ed49ce1ead95be26e0282a707。
- **本批改动**：仅3项综合RTL输入变化：design_top_wrapper添加SAMPLE坐标并传ISP/OSD；isp_top默认统计80×80；experiment_osd画青框及CYAN 80X80。通用统计算法、guard/classifier/27位CDC、相机、四键、1024×600、ADC/SDC/.al均不改。新增tb_roi_core，修改tb_osd/tb_roi_chain/runner及simREADME/04接口/17状态，新增18说明。
- **验证及证据**：ModelSim SE64 2019.2默认12项PASS，无强制覆盖。6400像素独立参考、框外黑白排除、255满量程、气泡；OSD逐像素灰度/双框/框外彩色、字样、同步/旁路两级延迟。真实RAW→选定ISP/原厂ERAM共7帧1024×600，短行/长暂停拒绝和恢复；非4对齐/配置/取消/分类/27位CDC旧回归全部通过。日志/WLF在sim/modelsim_work，runner tmp/modelsim_probe/regression_roi_core_console.log，PPM/预览已检查；最终复制待TD完成。
- **构建/资源**：tmp/roi_core_td_build_20261005隔离完整198输入＋.al，与旧基线仅上述3RTL不同，约束不改。综合LUT15006/REG15680，ERAM/DSP及最终Slice/WNS以物理报告为准。TD6.2.168116，PH1P35MDG324 speed3。首次TD带-f未执行综合，保留build_console.log；正确直接传build.tcl的综合日志build_console_retry.log。首次ModelSim相对Tee路径失败，完整回归改绝对路径后通过。旧基线约束I/O/PLL/DDR缺口与两PLL反馈告警需继续如实记录，不放宽SDC。
- **区域/参数**：观测[256,768)×[172,428)，统计[472,552)×[260,340)共6400像素。青框取同一个穴内核心，不要求包整穴，需实物验证边界；MEAN/MIN/MAX/VALID仅来自青框。CLASS_CALIBRATED=0，T=0/亮侧/EXP2244/GAIN48占位；无实际分类/准确率。最近完整统计保留，新FS取消未完成计算；坏帧/配置/lane撤销有效；没有DDR显示帧绑定。未来启用分类须重新TD。
- **实物/镜头约束**：固定摄像头不能换；窗口1024×600保持。6504镜头4mm/F2手动对焦、标称近摄200mm；130mm为候选距离，用户已轻调焦。最佳焦点和最终距离/光源尚未冻结，不凭镜头PDF单独否定130mm。机构60～400mm不保证全程清晰。历史LM358DR约280mm不当作当前实物料号。
- **三轮照片**：20261005_130mm成像反馈轮次1/2/3各六张独立保留。轮次2同种载带旋转180°，不合并阈值。轮次3方向统一，前三空穴/后三有件，用户确认130mm且光源/焦点未调；EXP2244/GAIN48，大框空穴MEAN46/53/48、有件107/102/100，快照间隔47级，仅支持试小框。F/I/G可读均0，多处FPS/L遮挡留空；照片非原始像素。轮次3引用17稿已保留更新前docs_snapshot/17_before_implementation.md并改manifest指向原哈希，历史proposal_approved=false保持为当时状态。
- **下一条具体操作**：等待TD物理阶段完成，检查最终时序/TNS/覆盖和6条邮箱预算；运行save_roi_core_evidence.py，冻结release/roi_core_80_20261005、198输入/12测试WLF/TD及文档，生成验收记录并核对旧5bit哈希。然后用户自行下载，将同一穴内位置对青框，在130mm/EXP2244/GAIN48和相同光源/焦点下两类各10秒、至少重复摆放一次，再另行确认T/方向。实物准确率/30分钟/固化冷启动均未测。
- **运行进程/设备**：ModelSim已结束，TD物理阶段运行中（exec session94341），用户管理设备；助手不操作JTAG/USB。完成后必须更新此处并保存文档快照。
- **提交/推送**：未提交、未推送。git diff --check仅既有uii2c.v:148行尾空格，未修改该行；不要称已同步。
'''
agents.write_text(text,encoding='utf-8')
print('Current checkpoint saved: 12 ModelSim tests passed, TD physical stage running.')
