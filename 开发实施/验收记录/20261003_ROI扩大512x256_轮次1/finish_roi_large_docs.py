from pathlib import Path
import json
import shutil
import hashlib

root = Path(__file__).resolve().parents[2]
project = root / 'fpga/component_inspector'
release = project / 'release/roi_statistics_large_20261003'
evidence = root / '开发实施/验收记录/20261003_ROI扩大512x256_轮次1'
m = json.loads((release / 'manifest.json').read_text(encoding='utf-8'))
t = m['timing']; r = m['resources']; bit = m['bitstream']; sha = bit['sha256']

record = root / '开发实施/验收记录/20261003_ROI扩大512x256_轮次1.md'
record.write_text(f'''# 中央ROI扩大512×256：验证与交付（2026-10-03）

用户反馈原中央256×128框偏小，并明确选择512×256。仅同步扩大显示灰度/绿色边框和统计范围，四键曝光−/＋、增益−/＋及默认参数保持；没有分类、按键ROI模式或字体改造。

## 改动与输入绑定

- 新半开区间：[256,768)×[172,428)，即x256～767、y172～427；131072像素，原窗口面积的4倍。
- 仅4个RTL文件的ROI常量变更：design_top_wrapper.v、experiment_osd.v、isp/isp_top.v、roi_statistics.v。对照前版冻结快照核对，其他193项构建输入相同。
- OSD测试改为新边界；真实链路测试更新独立参考范围、面积，并直接检查sample_pixels=131072。统计20位count、28位sum可容纳最大亮度和33423360，沿用前版两级流水和28拍除法。
- 分支hx1p35a-contest-work，HEAD f87ccf1c6a38e84b58a4f86cecd532a71ae56e89，未提交/推送。
- TD6.2.168116，PH1P35MDG324，速度级3；独立构建tmp/roi_statistics_large_td_build_20261003。
- 交付release/roi_statistics_large_20261003/camera_to_dsi_display.bit，{bit['bytes']:,}字节，SHA-256 `{sha}`。
- 197项当前/构建输入逐字节一致，快照、工程.al、仿真源码和证据校验见同名证据目录manifest.json。前256×128 bit与证据原样保留。

## 验证

| 项目 | 结果 |
|---|---|
| ModelSim OSD | 通过；逐像素验证新边框/框内灰度/框外原色、两拍流水与WAIT；全1024×600预览 |
| ModelSim ROI guard | 通过；保留非4对齐ROI独立参考、帧首末、双方完成顺序、异常/重叠/配置/通道拒绝与恢复，计算中调参取消样本 |
| ModelSim ROI chain | 通过；实际RAW10→uial2axis→demosaic→AWB→打包/统计，7帧1024×600，逐像素参考，正确131072像素计数及MEAN/MIN/MAX；valid间断、ready低、短行/长暂停拒绝及恢复 |
| TD综合/布局布线 | 完成；建立/保持WNS {t['setup_wns_ns']:.3f}/{t['hold_wns_ns']:.3f}ns，TNS均0，无违例端点 |
| 资源 | Slice {r['slice']}（{r['slice_percent']:.2f}%），31 ERAM，8 DSP；较前ROI版13998 Slice变化{r['slice']-13998:+d} |
| 约束覆盖 | STA {t['sta_coverage_percent']:.2f}%，无no_clock/invalid_constraint；新增邮箱6条预算均有效；SDC沿用前版 |
| 本扩大版上板 | 未测，由用户下载 |

本次只重跑受影响的三项；前版另外7项验证证据保留，不称本轮重新执行了10项。原厂ERAM/GSR/实际除法网表，没有强制RAM输入覆盖。全帧首帧学习回放可被拒绝，正常后续帧一次提交，短行/长暂停不提交，下一正常帧恢复。

基线外部输入delay缺37、输出delay缺63、部分输入1、dummy4、PLL检查7、两项DDR FIFO例外仍待核验；通用跨域预算2条被具体邮箱预算部分接管，保留报告，不声称全约束闭合。

## 现场反馈与后续

前256×128版：用户确认框外彩色和四键正常，四照片可见框内灰度/VALID；照片EXP2116/GAIN43，MEAN/MIN/MAX分别68/41/192、65/40/192、83/36/255、84/36/255；INPUT1024×600，图3/4输入FPS27/26。详见20261003_ROI上板反馈_轮次1。照片没有现场位流哈希/下载日志，属于预期前版绑定，不能移作扩大版验收。

扩大框会纳入更多载带、定位孔和背景，观测范围扩大后均值也可能变化；不沿用原ROI数值作为同一统计基准。正式单穴分类仍需另选ROI及实物真值/阈值。统计仍为最近完整有效采集样本，未与DDR显示帧绑定；停CSI时钟后约1～2秒WAIT；启动首帧可能WAIT。

重新下载后相机参数可能回到原默认EXP2244、GAIN48；用四键恢复此前照片的2116/43（或记录新条件）再比较。先确认框尺寸、框内灰度/框外原色、四键及VALID恢复，再固定放置记录约10秒的波动范围。距离、光源未新增确认，不套用旧280mm作为这次实测值。

| 待验收项目 | 扩大版记录 |
|---|---|
| 位流SHA/下载方式/日期 | 待用户操作 |
| 512×256框、框内灰度/框外原色、四键、VALID/WAIT | 未测 |
| INPUT/FPS、HDMI输出模式、L/F/I/G首尾值 | 未测；FPS不能用显示器刷新率替代 |
| 同条件正常/空穴静止10秒统计、重复取放 | 未测 |
| 30分钟无花屏/黑屏/冻结/撕裂/重启 | 未测 |
| Flash固化、启动方式及冷启动 | 未测；最终A整合还需再做冷启动 |
''', encoding='utf-8')

(release / 'README.md').write_text(f'''# 中央512×256观测ROI版（2026-10-03）

下载camera_to_dsi_display.bit，{bit['bytes']:,}字节，SHA-256 `{sha}`。

中央窗口x=256～767、y=172～427，共131072像素；框内灰度/绿色边框、框外彩色；统计同一区域。四键曝光−/＋、增益−/＋及默认参数保持。本版只扩大观测ROI，没有正常/空穴分类。

受影响的3项ModelSim（OSD、ROI保护、真实7帧ISP统计）通过；其余7项沿用前版证据。TD综合及布局布线完成，建立/保持WNS {t['setup_wns_ns']:.3f}/{t['hold_wns_ns']:.3f}ns、TNS0，Slice{r['slice']}（{r['slice_percent']:.2f}%）、31 ERAM、8 DSP；197项输入与独立构建一致。部分基线约束待核验。全部证据在开发实施/验收记录/20261003_ROI扩大512x256_轮次1。

由用户下载。上板、30分钟、Flash和冷启动未测；前小框版反馈不作为新大框验收。启动可能先WAIT，完整采集/处理后VALID；停止CSI时钟到WAIT约1～2秒。统计显示最近有效采集样本，尚未绑定DDR显示帧。

重新下载可能回到默认EXP2244/GAIN48。可用四键恢复照片中的2116/43后比较；新ROI面积变化，均值不能直接按旧框数据判断正常/空穴。先把目标置入框，检查显示和按键，再保持同一成像条件记录统计波动范围。正式分类另选单穴ROI。
''', encoding='utf-8')

p = root / 'AGENTS.md'; s = p.read_text(encoding='utf-8')
lines = s.splitlines()
for i, line in enumerate(lines):
    if line.startswith('- **目标与断点**：'):
        lines[i] = '- **目标与断点**：用户确认将中央观测ROI从256×128扩大到512×256；最小尺寸变更、受影响三项ModelSim和TD构建已完成，新版冻结待用户下载。小框上板反馈已存四原始照片及读数；没有分类/字体美化/Logo实施，不当作完整A验收。'
    elif line.startswith('- **冻结镜像/TD**：'):
        lines[i] = f'- **冻结镜像/TD**：最新release/roi_statistics_large_20261003/camera_to_dsi_display.bit，{bit["bytes"]:,}字节，SHA-256 {sha}，197项当前/构建输入一致。TD6.2.168116，Slice{r["slice"]}（{r["slice_percent"]:.2f}%）、31ERAM/8DSP，Setup/Hold WNS {t["setup_wns_ns"]:.3f}/{t["hold_wns_ns"]:.3f}ns、TNS0、STA{t["sta_coverage_percent"]:.2f}%。SDC未改，6条邮箱预算有效；基线外部I/O/PLL/DDR约束未决保持。前roi_statistics_20261003 SHA53b6e341c02da01292067eb27bb7d0f456afded30602a449d79496b2051fabce保留。'
    elif line.startswith('- **下一条具体操作**：'):
        lines[i] = '- **下一条具体操作**：用户下载新512×256版，验证框内灰度/框外彩色/四键/VALID恢复；重新设置EXP2116/GAIN43或记录新条件，静止10秒记录统计范围。尺寸[256,768)×[172,428)，131072像素。新扩大版验证和197项快照见20261003_ROI扩大512x256_轮次1；前小框实物照片见20261003_ROI上板反馈_轮次1。正式单穴ROI/阈值及分类范围另行确认。'
    elif line.startswith('- **运行进程/设备**：'):
        lines[i] = '- **运行进程/设备**：扩大版ModelSim/TD已结束；本轮不操作下载服务/USB，硬件由用户管理。'
    elif line.startswith('- **现场条件/未决**：'):
        lines[i] = line.replace('临时ROI[384,640)×[236,364)', '临时ROI[256,768)×[172,428)') + ' 小框四照片条件EXP2116/GAIN43、INPUT1024×600、图3/4输入FPS27/26；新距离/光源未确认，不能混作原条件。'
    elif line.startswith('- **验证与证据**：'):
        lines[i] = line + ' 扩大版仅4个RTL常量变更，OSD/roi_guard/roi_chain三项重新通过，独立参考及sample_pixels核对131072；另外7项沿用前版未改路径证据。'
p.write_text('\n'.join(lines) + '\n', encoding='utf-8')

for name in ['04_FPGA接口与异常处理约定.md', '10_A阶段后续实施确认稿.md', '11_静态成像条件与样本记录.md',
             '12_A像素接口验证与接入约定.md', '14_A帧保护与ROI灰度统计_实施说明.md']:
    target = evidence / 'docs_snapshot' / name; target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / '开发实施' / name, target)
shutil.copy2(p, evidence / 'docs_snapshot/AGENTS.md')
shutil.copy2(record, evidence / 'acceptance_record.md')
shutil.copy2(release / 'README.md', evidence / 'release_README.md')
shutil.copy2(Path(__file__), evidence / 'finish_roi_large_docs.py')
manifest = json.loads((evidence / 'manifest.json').read_text(encoding='utf-8'))
manifest['evidence_files'] = [{'path': str(p.relative_to(evidence)).replace('\\', '/'),
                              'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'bytes': p.stat().st_size}
                             for p in sorted(evidence.rglob('*')) if p.is_file() and p.name != 'manifest.json']
(evidence / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Large ROI release README, acceptance record and final checkpoint saved')
