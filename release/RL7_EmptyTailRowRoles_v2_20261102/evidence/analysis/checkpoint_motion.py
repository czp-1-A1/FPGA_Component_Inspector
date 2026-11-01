from pathlib import Path
import json
root=Path(__file__).resolve().parent;repo=Path('D:/CodexWork/erole_fix_20261102')
assert json.loads((root/'motion_run_r3/verification.json').read_text())['status']=='PASS'
assert json.loads((root/'motion_run_r2/verification.json').read_text())['status']=='FAIL_RETAINED'
a='<!-- EMPTY_TAIL_ROLE_20261102_BEGIN -->';b='<!-- EMPTY_TAIL_ROLE_20261102_END -->'
lines='''
- 运动验收新证据：motion_r2旧RTL同171完整1280×720源帧只31/23P/8E/1R，尾段仅2E且无报警，原失败保留；motion_r3当前RTL同一刺激完整36/23P/13E/1R（界面正常22），第34号/第5追加E独立报警且feed=0。输入在报警后仍由测试台外部推进，明确不是电机闭环；未虚称停机后仍实际经过36穴。245655对独立36形状穷举参考核对优化像素生成PASS。前29个E/R位置为合成例，不冒充用户逐穴真值。
- 新合同：13完整RGB源帧的断帧/取消/复位/无定位孔/只有当前有件/上下行错误/极弱定位孔/无穴亮证据断言PASS；原20940停车+65控制+27键、V3报警碰撞/21蜂鸣与18完整720p标签66355200参考像素对本轮实际PASS。tests/pocket_row_roles与scripts/check_pocket_row_roles.py新增，生产仍仅三源且冻结后未再改。
- 当前运行：D:/CodexWork/erole_build_r0_20261102冻结638源/106依赖，delta恰3、原SDC/引脚/seed1，TD综合进行；native_r0为启用POCKET_ROW_ROLES1的原12RAW原断言派生，ModelSim进行；contracts_r0继续完整运动+7个6px亮空穴无P的电机反馈闭环。以上均独立冻结，实际结果以各verification.json为准，无新交付/提交/推送。原有TD GUI不动；未操作板卡/JTAG/Flash/用户GUI。
- 下一条具体操作：检查上述完整合同和native/TD实际退出；若实际失败保留冻结输入/原目标并定位，不能边测边改答案。全部PASS后完整50约束/20FIFO/64时间Gray/V2/C12路由审计及资源复核，再桌面新版本bit、ZIP、说明、SHA和远端独立下载核对。
'''.strip()
for p in [repo/'AGENTS.md',Path('C:/Users/Li47/Desktop/aa/AGENTS.md')]:
 t=p.read_text(encoding='utf8');i=t.index(a);j=t.index(b,i)
 block=t[i:j]
 # Update stale current status while preserving earlier diagnostic limits.
 block=block.replace('当前底层原型82组合检查完成，尚无新bit/路由/实板通过。','当前82组合原型与完整29+7运动对照完成，native/物理冻结验收进行，尚无新bit交付/实板通过。')
 block=block.replace('当前只原型，原生RAW与真实运动/闭环/物理尚未跑。','完整RGB运动已PASS；原生RAW、闭环和物理当前运行，未判通过。')
 marker='- 运动验收新证据：'
 if marker in block:block=block[:block.index(marker)]
 t=t[:i]+block+'\n'+lines+'\n'+t[j:];p.write_text(t,encoding='utf8')
record=repo/'开发实施/验收记录/20261102_C_全空尾段角色_轮次2.md'
record.write_text('# 全空尾段：冻结运动对照与集成验收\n\n'+lines+'\n',encoding='utf8')
print('Checkpoint updated: old actual failure/new full36 and fifth34; native/TD still running')
