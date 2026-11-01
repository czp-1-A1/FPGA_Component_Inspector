"""Update only this task's handoff marker, preserving other tasks verbatim."""
from pathlib import Path
import argparse,hashlib,json,subprocess
repo=Path(__file__).resolve().parents[1];analysis=Path('D:/CodexWork/empty_tail_role_20261102');work=Path('D:/CodexWork/erole_build_r1_20261102')
a=argparse.ArgumentParser();a.add_argument('--phase',required=True);args=a.parse_args()
validation=repo/'validation/pocket_row_roles';validation.mkdir(parents=True,exist_ok=True)
def load(p):return json.loads(p.read_text(encoding='utf8')) if p.exists() else None
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
branch=subprocess.check_output(['git','branch','--show-current'],cwd=repo,text=True).strip()
groups={n:(load(analysis/n/'verification.json') or {}).get('status','RUNNING_OR_NOT_COMPLETED') for n in ['stop_r1','second_r0','alarm_r1','contracts_r1','native_r1']}
physical=load(work/'physical_verification.json');delivery=load(validation/'delivery_receipt.json');upload=load(validation/'github_upload_state.json')
state={'phase':args.phase,'branch':branch,'head':head,'baseline_commit':'1b8a097f9dd7d7dee2783e9dcbcf43986f7650f4','analysis':str(analysis),'build':str(work),'software':groups,'physical':physical,'delivery':delivery,'upload':upload,'board_operated':False}
(validation/'current_status.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
phy='物理未审计通过'
if physical:
 t=physical['timing_ns'];r=physical['resources']
 phy=f"Routed seed1 Slice{r['slice']}/21216、ERAM{r['eram']}/108、DSP{r['dsp']}/40、PLL{r['pll']}/6；setup{t['SWNS']:+.3f}ns/hold{t['HWNS']:+.3f}ns/双TNS0；50maxdelay匹配忽略0、20FIFO Gray/64时间Gray/控制邮箱按键/实际V2 C12完整审计PASS，资源>80%复核在validation/pocket_row_roles/resource_review.json。"
desktop='无新镜像交付，不能用中间bit替代冻结旧v1。'
if delivery:desktop=f"新交付{delivery['desktop_bit']}，SHA256 {delivery['bit_sha256']}；完整包{delivery['desktop_zip']}，SHA256 {delivery['zip_sha256']}，说明/散列/回执同前缀，{delivery['payload_files']}载荷/638生产输入全部ZIP恢复与桌面逐SHA及portable准备PASS；旧v1 SHA48a30fb2原样保留。"
publ='未提交/未推送。'
if upload:publ=json.dumps({k:upload.get(k) for k in ['stage','source_commit','committed','pushed','remote_verified']},ensure_ascii=False)
block=f'''<!-- EMPTY_TAIL_ROLE_20261102_BEGIN -->
## 29穴后接7全空穴：当前帧孔角色修复（2026-11-02）

- 目标/断点：{args.phase}。用户同规格同中心线、原29真值正常22/空6/复核1，追加7全空；全部外部经过目标36/22/13/1；正确第5追加E停在34号/空11，余2未经过不能虚计。现场实板尚未验收。
- 分支/基线：D:/CodexWork/erole_fix_20261102，{branch}，HEAD {head}；基线1b8a097/源22b1531d/旧bit48a30fb2，旧交付/原V3和其他分支不动。分析{analysis.as_posix()}；单实现端、无子代理。
- 改动：生产仅frame_shape_search/isp_top/top三源，POCKET_ROW_ROLES顶层1/内部默认0；当前源帧上排定位孔或真实有件辅助下排小空穴，排除上排孔、保留原局部亮暗/形状/Sobel证据；不预测、不复用旧行、不把未知/复核当E。635/638其余源与原停车器/独立5E账本/四键/OSD字体/相机视频/SDC引脚字节不变。新增tests/pocket_row_roles及5个工作脚本、说明和验收记录。
- 现场取证：用户视频842fdf839cb7732fbce1f734d295812a.mp4 SHA1c86564aec54b2eca5c6b6d42b699d98e7db4bb5219c757ee173c0645739a445，15.77s/手机30FPS，非传感器像素。最终33/21/10/2，尾段新增030..033仅4E，额外复核在尾段前；所选框在下排穴内亮点，不能称视频已证明上排误计E。field_facts.json与完整原视频/抽帧保留。
- 旧失败/新证据：旧42+40静态完整RGB复现上排弱8px灰95误E与6px亮孔双奇相位无P漏E；新82组合上排误E/P 2→0、旧正例全部保留，40空孔扫描仍12组未知、42角色扫描另6组行界/孔形边界未知。相同171完整1280×720合成29+7运动，旧RTL仅31/23P/8E/1R且不报警，新完整36/23P/13E/1R且34号报警feed0；P含复核，正常22。输入报警后由外部推进，是完整分类观察器，独立67帧7小空穴电机反馈闭环在5E停车并保持；13帧当前证据/取消/复位/缺孔/错行/暗穴负例PASS。245655对36形状独立像素参考PASS；合成前29穴排列不是用户逐穴真值。旧失败/草稿未运行r0r1/编码工具失败分别保留。
- r0边界失败与r1修正：phases_r0原8相位合同第7组实际E0/目标E1，phase_trace_r0复现弱8px灰95上排孔量化3×3实心9格，不满足圆形填充率而丢失行参考；r0因此拒绝交付，即使native_r0/24栅格22940496像素/OFUF0及build_r0已经结束，也不能冒用为最终源通过。隔离refine_phase_r1保持原8目标并通过4个RGB合同后迁入r1：仅上排角色允许实际3×3/9格量化圆盘，下排证据不变。生产frame SHA041a3bd76716f162ef9f46a0840f2ecdf539455ed1d1f4df134e5ca0e5d85a64；最终contracts_r1另有16相位/组合弱孔/仅定位孔负例，frozen_r4/r5/run_r4/r5重跑原82刺激，probe_comparison_r1.json；全部最终proof必须绑定本r1。
- 软件冻结状态：{json.dumps(groups,ensure_ascii=False)}。新增20940停车/旧65控制/27键、100MHz完整100000000拍一秒、报警碰撞/21蜂鸣/18完整720p标签66355200参考像素对均本轮实际运行；原生12RAW仅加新参数/模块名，旧断言未改，以native_r0/verification.json为准；所有实际输入逐SHA绑定，不冒用旧通过。
- 物理：638源/106依赖冻结D:/CodexWork/erole_build_r1_20261102，delta恰3，原SDC/引脚/seed1。{phy}
- 桌面交付：{desktop}
- 下一条具体操作：未完成软件/物理先检查实际进程与proof，不重复成功构建，不边测边改；全部通过才交付/普通推送独立分支并远端下载核验。已交付则由人同一冻结镜像SRAM下载复测原29及拼接7空，期待34号/空11五连停车，记录全上下栏/空号/视频；前段额外复核仍须现场确认，不能声称已修现场所有误判。
- 进程/设备：完成情况以当前proof为准，未完成时仅本聊天ModelSim原生链/TD构建审计；软件均PASS且physical存在则本轮验证已退出。既有TD GUI不动；无板卡/JTAG/Flash/用户GUI操作。本轮定时继续已结束，等待人反馈实板；其他聊天/r12不动。
- 提交/推送：{publ} 不合并主分支。远端源码/bit/ZIP及全部载荷独立下载核验才称同步，发布最终HEAD以桌面GitHub回执为准。
<!-- EMPTY_TAIL_ROLE_20261102_END -->'''
for p in [repo/'AGENTS.md',Path('C:/Users/Li47/Desktop/aa/AGENTS.md')]:
 t=p.read_text(encoding='utf8');a='<!-- EMPTY_TAIL_ROLE_20261102_BEGIN -->';b='<!-- EMPTY_TAIL_ROLE_20261102_END -->'
 if a in t:i=t.index(a);j=t.index(b,i)+len(b);t=t[:i]+block+t[j:]
 else:t=block+'\n\n'+t
 p.write_text(t,encoding='utf8')
print('Updated row-role handoff:',args.phase,flush=True)
