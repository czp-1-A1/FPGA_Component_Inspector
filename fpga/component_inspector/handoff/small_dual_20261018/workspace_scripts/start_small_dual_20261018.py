from pathlib import Path
import json,subprocess,sys
r=Path.cwd();rd=r/'tmp/small_dual_r0_20261018';procs={}
for action,extra in [('sim',['--modelsim-bin','D:/modelsim/win64']),('build',[])]:
 with (rd/(action+'.log')).open('w',encoding='utf-8') as out,(rd/(action+'.err')).open('w',encoding='utf-8') as err:
  z=subprocess.Popen([sys.executable,'-X','utf8',str(rd/'scripts/replay.py'),'--action',action,'--work',str(rd/'work'),'--td-root','D:/AAA/FPGA.....YZW',*extra],stdout=out,stderr=err,creationflags=0x08000000)
 procs[action]=z.pid
(rd/'processes.json').write_text(json.dumps(procs,indent=2)+'\n',encoding='utf-8')
q=r/'AGENTS.md';t=q.read_text('utf-8');t=t[:t.index('## 当前断点')]+'''## 当前断点（2026-10-18，小搜索区双路单目标版本验证中）

- lj4747-contest-work HEAD55090063；最新用户在方案讨论后指示搜索框改小，并纠正“文字还是随框动”，继续实施此连续请求。上路/下路两条载带水平方向，各一目标；主生产仍21dc549f未集成、正式/旧镜像/旧包不改，未提交/推送/JTAG/Flash。
- 冻结tmp/small_dual_r0_20261018，371输入manifest ebe9ee69e48ade3fd43a8b31cbaf59f4f2de4951b2a5e3c54f8c5038048c53c9。相对最新21dc：frame_shape_search新LANE_SINGLE常量分支、每区1记录，isp_top在REGIONS生产启用；inspection_region_config.COMPACT两区x560—720、y248—352/368—472（各160×104），T80缓存范围184—536保留64像素上下文。阈值与ISP/缩放/Sobel/DDR/时钟/SDC均不变。不是运动持久编号或绝对全检保证。
- experiment_osd包装生产compact分支：48像素顶部，缩小保留Logo/简要EXP/GAIN/FPS/视图/故障/SMALL DUAL R1；每路1动态框和跟随框的一行有件/空穴/有件复核标签，失效待检测。用户已否决固定结果文字，绝不能恢复固定有效标签。3-clock像素/同步/ENABLE旁路及首有效像素元数据快照不变。中文9字+blank小ROM，保留旧分支给既有非生产多模式；不是运行时调试页面。现有legacy测试保留，仅旧regions_osd显式COMPACT_UI0，另新增生产UI完整oracle。
- 新lane_search24全帧，双路正反方向3个器件依次经过、每路单槽、中心优先、侧立/低灰有件、定位孔剔除、边界完整轮廓、窗外拒绝、取消；lane_osd4完整栅格3686400独立像素、文字随框、忽略旧第二槽、无效清空、中途换元数据下帧生效、Logo字库/3-clock/ENABLE；lane_hd_pins用实际FIFO/DDR读/串行HDMI两完整720p60图核对新UI每像素。另跑原10项回归，总13项。所有输入/期望已冻结；未过不得边测边改。
- 基线资源Slice16442(77.50%)/ERAM104/DSP26/PLL5。下一步读13项日志与实际构建，失败保留新轮；最终完整路由setup/hold/约束覆盖/40max_delay与20Gray实际扇出都过才集成并打包，报告真实节省。未声称底图抖动或翻面盲点修复。无新代理或自动任务。
'''+f'- 当前后台进程{json.dumps(procs)}，无板卡操作。详细记录将保存开发实施/验收记录/20261018_A_中央小窗口双路单目标精简_轮次20.md。\n';q.write_text(t,encoding='utf-8')
print(json.dumps(procs,indent=2))
