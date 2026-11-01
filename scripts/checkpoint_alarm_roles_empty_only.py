"""Keep this chat's handoff separate from the original V3 and older candidate."""
from pathlib import Path
import argparse,datetime,json,subprocess
ap=argparse.ArgumentParser();ap.add_argument('--phase',required=True);args=ap.parse_args()
repo=Path(__file__).resolve().parents[1];prefix=Path('D:/CodexWork/rl7_alarm_roles_empty_only_20261102')
base='904a2bb053a9e679b3f50378ca3163a55698b20e'
paths={k:Path(str(prefix)+suffix) for k,suffix in [('targeted','_checks_r0/verification.json'),('second','_second_r0/verification.json'),('roles','_roles_r0/verification.json'),('native','_native_r0/verification.json'),('physical','_build_r0/physical_verification.json')]}
proofs={k:json.loads(p.read_text())['status'] if p.exists() else 'PENDING' for k,p in paths.items()}
receipt=repo/'validation/delivery_receipt.json';delivery=json.loads(receipt.read_text(encoding='utf8')) if receipt.exists() else None
upload_path=repo/'validation/github_upload_state.json';upload=json.loads(upload_path.read_text(encoding='utf8')) if upload_path.exists() else {}
finished=all(value.startswith('PASS') for value in proofs.values())
data={'phase':args.phase,'baseline_commit':base,'branch':'codex/rl7-alarm-roles-empty-only-20261102','proofs':proofs,'delivery':delivery,'upload':upload,'board_operated':False,'updated':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()}
(repo/'validation/current_status.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
block=f'''<!-- ALARM_ROLES_EMPTY_ONLY_20261102_BEGIN -->
## RL7 AlarmRoles V3合入仅空穴停车（2026-11-02）

- 目标/断点：用户指定904a2bb0而非旧UIOptV2；当前{args.phase}。沿用此前上传授权，完成后同步本次独立分支，不合并主分支。
- 分支/基线：D:/CodexWork/rl7_alarm_roles_empty_only_20261102，codex/rl7-alarm-roles-empty-only-20261102，基线{base}，远端codex/rl7-v3-alarm-roles。旧empty_only_stop_20261101及其桌面bit/ZIP不改；旧版上传中断前仅只读核对，未提交/推送。单实现端，无子代理。
- 改动文件：top/isp_top/pocket_relay_stop_v2三生产源，635/638其余源逐SHA同904，尤其V3 compact_inspector_osd/独立alarm_tracking及全局账本、相机/视频/计数/SDC/引脚保留。运行异常只记原因并FEED，取消停止式REACQUIRE；不弹未完成队列、不伪造完成。第5合法EMPTY仍优先停车/蜂鸣，FIRST上下文不被报警覆盖；人工暂停停止清零/正常一秒保持不改。
- 验证/证据：{proofs}。新增20940检查含V3先局部LOST/不确定/签名错/段错但前4E不停、合法5E停且保留首错；旧65控制/27按键兼容。最终全部运行输入/日志SHA在各proof及validation，原V3合同/全空RGB/标签像素亦实际重跑；原生RAW/真实100MHz一秒及原SDC seed1物理单独核验，不冒用旧通过。
- 未决/下一条：{'已完成验证，进行交付/远端核验或等待人固定同一冻结镜像实板' if finished else '读取实际PID和冻结日志，等正在运行的native/物理；严格双角时序/全CDC/实际V2 C12审计后才封包/桌面交付/上传'}。识别失锁本身未修，继续送料不等于仍准确定位空穴，未获现场验证。
- 运行/设备：{'本轮仿真/TD/审计已退出，仅交付或Git核验' if finished else '本任务_build_r0(seed1)、_native_r0、_second_r0、_roles_r0，按命令行核对真实PID防复用'}；无板卡/JTAG/Flash/用户GUI操作，无新增定时，其他聊天进程不动。
- 提交/推送：{upload if upload else '尚未提交/推送，暂存0'}；实物未测，不能称实板通过。
'''
if delivery:block+='- 桌面交付：'+delivery['desktop_bit']+'；SHA256 '+delivery['bit_sha256']+'；完整ZIP '+delivery['desktop_zip']+'。\n'
block+='\n<!-- ALARM_ROLES_EMPTY_ONLY_20261102_END -->'
for path in [repo/'AGENTS.md',Path('C:/Users/Li47/Desktop/aa/AGENTS.md')]:
 text=path.read_text(encoding='utf8');begin='<!-- ALARM_ROLES_EMPTY_ONLY_20261102_BEGIN -->';end='<!-- ALARM_ROLES_EMPTY_ONLY_20261102_END -->'
 if begin in text:
  a=text.index(begin);b=text.index(end,a)+len(end);text=text[:a]+block+text[b:]
 else:text=block+'\n\n'+text if path.parent==repo else text+'\n\n'+block+'\n'
 path.write_text(text,encoding='utf8')
print(json.dumps({'phase':args.phase,'proofs':proofs},ensure_ascii=False),flush=True)
