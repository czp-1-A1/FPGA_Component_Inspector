from pathlib import Path
import hashlib, json, shutil

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
record = root / '开发实施/验收记录/20261012_B定位孔灰度过渡修复_轮次1'
unit = root / 'tmp/hole_transition_unit_r1_20261012'
assert not record.exists() and not unit.exists()
record.mkdir(parents=True)
unit.mkdir()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
rel = Path('user_source/hdl_source/tape_hole_tracker.v')
before = record / 'before' / rel
before.parent.mkdir(parents=True)
shutil.copy2(project / rel, before)
shutil.copy2(root / 'AGENTS.md', record / 'AGENTS_before.md')
old = root / 'tmp/hole_scan_boundary_20261012_r1'
shutil.copy2(old / 'tb_hole_soft_requirement.v', unit / 'tb_hole_soft_requirement.v')
assert sha(old / 'tb_hole_soft_requirement.v') == sha(unit / 'tb_hole_soft_requirement.v')
(record / 'approval.json').write_text(json.dumps(dict(
    user_reply='确认，生成修复版', transition_max_pixels_per_side=8,
    preserved=dict(bright=120, dark=100, bright_width=[20,64], dark_margin_pixels=8,
                   pitch=96, pitch_tolerance=24, scan_rows=[372,380,388], wb=[100,100]),
    baseline_before_sha256=sha(before), original_unmet_requirement_sha256=sha(unit / 'tb_hole_soft_requirement.v'),
    scope='Only hole_scanline boundary handling; tracking/classification gates unchanged; onsite root cause unproven'
), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
record.with_suffix('.md').write_text('''# B 定位孔灰度过渡修复，轮次1

2026-10-12。用户明确确认“确认，生成修复版”。基于R100/B100 D3镜像；旧失败记录和旧镜像保留。

仅允许孔边界最多8像素的101～119灰度过渡，孔宽只计≥120亮区。保留≤100暗区的连续8像素两侧边界、20～64孔宽、96±24孔距、三条扫描行、运动/帧/分类门控及默认R100/B100。不增加失锁调试统计、自动ROI或标定菜单。

原失败可用性测试逐字节复制，新增有限过渡及误锁拒绝要求在实现前保存。仿真使用冻结源码，测试失败/修改轮次分别留档；不修改历史测试预期。

验证/构建进行中，尚未发布新镜像。源码证明原算法拒绝灰度过渡；现场亮暗值及是否还有其他原因尚未确认。软件验证不能替代现场定位与有件/空穴验收。
''', encoding='utf-8')
p = root / 'AGENTS.md'
s = p.read_text(encoding='utf-8-sig')
start = s.index('## 当前断点')
s = s[:start] + '''## 当前断点（2026-10-12，孔边界有限灰度过渡已确认，实施中）

- **目标/断点**：用户已明确确认生成孔搜索修复版。只允许每侧最多8像素101～119过渡，保持亮暗门限、孔宽/孔距/三行/运动/分类门控和默认R100/B100。新增要求和修改前源码见tmp/hole_transition_unit_r1_20261012、开发实施/验收记录/20261012_B定位孔灰度过渡修复_轮次1；尚未发布新bit。
- **分支/基线**：lj4747-contest-work，HEAD3be3967f2457622566fb20b7cef3aa5038e7d885，暂存空，原WIP保留。基线tmp/wb100_d3_r1_td_20261012的210生产输入，已发布bit SHA be9da1c3856162cab4de89188b614e218d48990657d958009c81133e8d0a78a7。
- **改动/验证**：准备只改tape_hole_tracker.v的hole_scanline，其他子模块不改。原FAILED soft requirement原样保留并复制；先冻结新增测试与候选源码验证，再冻结全210输入进行真实ISP回归及TD时序构建。不能引用历史PASS冒充本次验证。
- **未决/现场**：最新照片R100/B100、NO HOLE/ROW0，MEAN---；黑屏已由用户确认消失。原灰度过渡限制已在仿真复现，现场根因未定；旧TAIL0与黑屏恢复原因未定保留。定位/分类尚未现场通过，不能取消门控强行显示空穴。
- **下一条操作**：实现有限左右过渡状态，原soft fixture必须通过；过长过渡、灰带、孤立/分裂亮斑及孔宽孔距界限必须拒绝。通过后冻结、回归、构建、发布并绑定SHA/证据。
- **进程/设备/提交**：主线程唯一写入，无新代理或JTAG/Flash操作；尚无新运行进程，未提交未推送。旧镜像和证据保留。
'''
p.write_text(s, encoding='utf-8')
print(f'Approval and before-source saved: {record}')
