"""Archive a frozen, completed HDMI TPG diagnostic and prepare desktop files."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,zipfile

engine=Path(__file__).resolve().parents[1]
repo=engine.parents[1]
ap=argparse.ArgumentParser();ap.add_argument('freeze',type=Path)
ap.add_argument('--desktop',type=Path);args=ap.parse_args()
root=args.freeze.resolve();meta=json.loads((root/'freeze.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for e in meta['inputs']:assert sha(root/e['path'])==e['sha256'],e['path']
sim=(root/'sim/console.log').read_text(errors='replace')
assert 'PASS TPG transport counts:' in sim and '** Fatal:' not in sim and '** Error:' not in sim
runs=root/'td_project/hdmi_tpg_Runs';phy=runs/'phy_1'
timing=(phy/'final_timing.rpt').read_text(errors='replace')
console=(phy/'console.log').read_text(errors='replace')
assert re.search(r'Setup\s*:.*TNS\s+0ps\s+NUM_FEPS\s+0',console)
assert re.search(r'Hold\s*:.*TNS\s+0ps\s+NUM_FEPS\s+0',console)
bit=phy/'hdmi_tpg.bit';assert bit.stat().st_size>100000
out=engine/'release/native_1080p30/hdmi_tpg_diagnostic_20261008'
if out.exists():raise SystemExit('Refusing to replace existing diagnostic package')
out.mkdir(parents=True);shutil.copy2(bit,out/'hdmi_tpg.bit')
shutil.copy2(root/'freeze.json',out/'input_snapshot.json')
with zipfile.ZipFile(out/'input_snapshot.zip','w',zipfile.ZIP_DEFLATED) as z:
 for e in meta['inputs']:z.write(root/e['path'],e['path'])
for d in ('syn_1','phy_1'):
 for p in (runs/d).iterdir():
  if p.is_file() and (p.suffix in ('.log','.logw','.rpt','.txt','.area','.stat','.cfg','.tcl','.prj') or 'report' in p.name):
   dest=out/'reports'/d/p.name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
for p in (root/'sim').glob('*.log'):
 dest=out/'simulation'/p.name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
model_names=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v',
 'ph1p/ph1p_logic_hrio.v','ph1p/ph1p_logic_ramfifo.v','ph1p/ph1p_phy_hr_pad.v']
model_manifest=[dict(path='D:/td6.2.1/sim_release/'+n,sha256=sha(Path('D:/td6.2.1/sim_release')/n)) for n in model_names]
(out/'vendor_models.json').write_text(json.dumps(model_manifest,indent=2)+'\n')
shutil.copy2(engine/'tools/native_toolchain.json',out/'toolchain.json')
readme=f'''# HDMI1080p30色条隔离诊断（未验收）

镜像：hdmi_tpg.bit，SHA-256 `{sha(bit)}`，{bit.stat().st_size}字节。
用途：厂商HDMI核直接生成色条；相机、ISP、DDR、原VTC、OSD及按键模式不运行。
原相机诊断候选7b8c08c…保持不变，用户上板报告“输入不支持”，未进入阶段3。

目标参数1920×1080、2200×1125、74.25/371.25 MHz、VIC34；同一HDMI_PLL参数、加密核、串行器和已核实TMDS引脚，独立布局。不是相机修复版，不替代原像素/采集FPS/DDR或完整功能验收。

冻结：{root.name}，输入/源代码身份见input_snapshot.json/zip，TD6.2.178840、ModelSim10.5。
完整锁定后VS到VS计数测试通过：真实加密核及原厂ODDR，严格5:1理想时钟（约1ppm误差）；实际PLL全帧组合仿真未运行，旧vendorPLL频率测试另有证据，不能把两者称作同一个端到端验证。
仿真测到同步脉冲为负极性（HS低44、VS低11000），目标VIC34正极性仍待处理；本镜像特意保留厂商核输出，以判断实际设备接受情况，不宣称目标格式全部通过。
TD最终建立/保持TNS为0、违例端点0，细值及资源见reports。一个复位输入、四个TMDS输出没有板级外部延迟预算，ACR常量dummy警告已保留；不宣称所有路径已验收。

在TD使用易失Download/JTAG选择本bit，观察是否出现内置色条，并记录显示器信息页的分辨率/刷新率、照片和本SHA。现场操作由用户完成；本端没有烧录。该诊断不写Flash或替换旧永久启动镜像。
若能显示，继续查原VTC/输入握手/混合器与原布局；若仍“输入不支持”，继续查PLL实测、TMDS/同步极性与设备识别。成功色条不能证明相机底座通过；失败原样留证据。
回退文件为原候选目录中的rollback.bit，SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65，桌面准备包亦保留同一回退副本。仅按既有人工操作恢复。
'''
(out/'README.md').write_text(readme,encoding='utf-8')
(out/'SHA256SUMS.txt').write_text(''.join(sha(p)+'  '+p.relative_to(out).as_posix()+'\n' for p in sorted(out.rglob('*')) if p.is_file()),encoding='utf-8')
if args.desktop:
 desktop=args.desktop.resolve()
 if desktop.exists():raise SystemExit('Refusing to replace existing desktop directory')
 desktop.mkdir(parents=True)
 for e in meta['inputs']:
  p=desktop/e['path'];p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/e['path'],p)
 shutil.copytree(runs,desktop/'td_project/hdmi_tpg_Runs')
 al=desktop/'td_project/hdmi_tpg.al'
 al.write_text(re.sub(r'(<Project[^>]* Path=")[^"]+',lambda m:m[1]+al.parent.as_posix(),al.read_text(),count=1))
 for e in meta['inputs']:
  if e['path']!='td_project/hdmi_tpg.al':assert sha(desktop/e['path'])==e['sha256']
 shutil.copy2(bit,desktop/'hdmi_tpg.bit');shutil.copy2(out/'README.md',desktop/'README.md')
 rollback=engine/'release/native_1080p30/stage2_base_20261008/rollback.bit'
 assert sha(rollback)=='bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
 shutil.copy2(rollback,desktop/'rollback.bit')
 assert sha(desktop/'hdmi_tpg.bit')==sha(bit)
print(json.dumps(dict(package=str(out),bit_sha256=sha(bit),desktop=str(args.desktop)),ensure_ascii=False))
