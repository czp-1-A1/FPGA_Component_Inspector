"""Refresh the short handoff checkpoint without accumulating history."""
from pathlib import Path
import argparse, subprocess,datetime

ap=argparse.ArgumentParser()
ap.add_argument('checkpoint')
ap.add_argument('--next',required=True)
ap.add_argument('--commit-status',default='本轮变更尚未提交/推送；基线3be3967已在远端')
args=ap.parse_args()
repo=Path(__file__).resolve().parents[3]
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
summary=f'''## 当前断点（{datetime.date.today().isoformat()}，SC500原像素1080p30迁移）

- **目标与断点**：用户已批准实施1080p30分阶段迁移；{args.checkpoint}。阶段2仅RAW/GRAY，人工上板门槛通过后才集成完整EDGE。
- **分支/代码基线**：lj4747-contest-work；开始HEAD3be3967f2457622566fb20b7cef3aa5038e7d885；记录时HEAD{head}，交付提交身份以git log -1核对。开始工作区干净，未覆盖其他改动。
- **改动文件**：相机尺寸、统一几何/位宽、ISP/保护/统计、DDR写读与50MHz PLL/IP参数、独立HDMI PLL、SDC、OSD/监测、冻结/测试/交付工具及native_1080p30诊断包；详见开发实施/验收记录/20261008_原像素1080p30_轮次2.md。原Example、旧release及历史证据保留。
- **验证及证据**：207旧输入/旧bit已冻结；25类仿真最终PASS，早期失败独立保留；完整TD建立/保持WNS+0.143/+0.020ns，两种TNS/违例端点0；资源14911/21216 Slice、45/108 ERAM、8/40 DSP、5/6 PLL。候选release/native_1080p30/stage2_base_20261008新bit SHA 7b8c08c27582960da985b52102c0c9273533c3bf5cabc89d757cbfee7588e709；191文件/282冻结输入完整性通过。仅诊断、未验收。
- **未决事项**：STA覆盖95.31%，39输入/63输出延迟、partial/dummy等审计后仍待板级预算闭合；FHD RAW→去马赛克/AWB独立数值参考未运行；物理DDR训练/写读/压力、实际输入尺寸/30秒采集FPS、HDMI识别、RAW/GRAY各2分钟均未测。DDR50MHz方案已一致改PLL/tCK/CL/CWL/刷新，不能以STA消警告代替实物。完整EDGE/组合及最终30分钟/20轮/3冷启动未进入。CLASS_CALIBRATED=0，不启用T58。
- **下一条具体操作**：{args.next}。
- **运行中进程/设备**：最后查询用户TD GUI41952、bw15004、hwserver17224/31504/32148保留；助手TD CLI/ModelSim均退出。未烧录或操作唯一板卡；本端保存交付后停止实现，接棒仍先确认前端停止。
- **提交/推送状态**：{args.commit_status}。仅续接个人分支，不pull/reset/强推。
'''
for path in (repo/'AGENTS.md',repo.parent/'AGENTS.md'):
    old=path.read_text(encoding='utf-8-sig').split('## 当前断点')[0]
    path.write_text(old+summary,encoding='utf-8')
(repo/'交接说明.md').write_text('# 当前接力说明\n\n'+summary+'\n历史冻结镜像、失败与复测证据保留在原release及验收记录。\n',encoding='utf-8')
print('Updated repository and outer handoff checkpoints')
