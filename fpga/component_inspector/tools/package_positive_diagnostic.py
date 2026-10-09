"""Package both frozen pin-verified diagnostic builds, with portable TD files."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,zipfile
engine=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser()
ap.add_argument('fhd30',type=Path);ap.add_argument('hd60',type=Path)
ap.add_argument('--desktop',type=Path,required=True)
args=ap.parse_args()
out=engine/'release/native_1080p30/positive_sync_diagnostic_20261009'
desktop=args.desktop.resolve()
if out.exists() or desktop.exists():raise SystemExit('Refusing existing release/desktop directory')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
prepared=[]
for key,root,label in [('fhd30',args.fhd30.resolve(),'A_1080p30'),('hd60',args.hd60.resolve(),'B_720p60')]:
 meta=json.loads((root/'freeze.json').read_text());assert meta['mode']==key
 for e in meta['inputs']:assert sha(root/e['path'])==e['sha256'],e['path']
 sim=(root/'sim/pins.console.log').read_text(errors='replace')
 assert 'PASS positive pin frame:' in sim and '** Fatal:' not in sim and '** Error:' not in sim
 if key=='fhd30':assert 'words2475000 pixels2073600 lines1080' in sim
 else:assert 'words1237500 pixels921600 lines720' in sim
 name=meta['project'];runs=root/'td_project'/(name+'_Runs');phy=runs/'phy_1'
 console=(phy/'console.log').read_text(errors='replace')
 assert re.search(r'Setup\s*:.*TNS\s+0ps\s+NUM_FEPS\s+0',console)
 assert re.search(r'Hold\s*:.*TNS\s+0ps\s+NUM_FEPS\s+0',console)
 assert 'ERROR' not in console and 'Error' not in console
 bit=phy/(name+'.bit');assert bit.stat().st_size>100000
 al=(root/'td_project'/(name+'.al')).read_text()
 refs=re.findall(r'<File Path="([^"]+)"',al)
 assert len(refs)==8 and all((root/'td_project'/r).resolve().exists() for r in refs)
 assert 'hdmi_ideal_pll' not in al and 'native_hdmi_pll.v' in al and name+'_top' in al
 prepared.append((key,root,label,meta,name,runs,bit))
probe=(args.hd60.resolve()/'sim/native_probe.console.log').read_text(errors='replace')
assert 'PASS native PLL:' in probe and '** Fatal:' not in probe and '** Error:' not in probe
out.mkdir(parents=True);desktop.mkdir(parents=True)
summary=[]
for key,root,label,meta,name,runs,bit in prepared:
 package=out/label;package.mkdir()
 shutil.copy2(bit,package/(label+'.bit'));shutil.copy2(root/'freeze.json',package/'input_snapshot.json')
 with zipfile.ZipFile(package/'input_snapshot.zip','w',zipfile.ZIP_DEFLATED) as z:
  for e in meta['inputs']:z.write(root/e['path'],e['path'])
 build_inputs=[]
 for run in ('syn_1','phy_1'):
  for p in (runs/run).iterdir():
   if p.is_file() and (p.suffix in ('.log','.logw','.rpt','.txt','.area','.stat','.cfg','.tcl','.prj','.ts','.timing') or 'report' in p.name):
    q=package/'reports'/run/p.name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
   if p.name in ('settings.cfg','build.tcl',name+'.prj'):
    build_inputs.append(dict(path=p.relative_to(root).as_posix(),sha256=sha(p)))
 (package/'generated_build_inputs.json').write_text(json.dumps(build_inputs,indent=2)+'\n')
 for p in (root/'sim').glob('*.log'):
  q=package/'simulation'/p.name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
 target=desktop/label;target.mkdir()
 for e in meta['inputs']:
  q=target/e['path'];q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/e['path'],q)
 shutil.copytree(runs,target/'td_project'/(name+'_Runs'))
 for p in [target/'td_project'/(name+'.al'),*list((target/'td_project'/(name+'_Runs')).glob('*/*.prj'))]:
  p.write_text(re.sub(r'(<Project[^>]* Path=")[^"]+',lambda m:m[1]+(target/'td_project').as_posix(),p.read_text(),count=1))
 for e in meta['inputs']:
  if not e['path'].endswith('.al'):assert sha(target/e['path'])==e['sha256']
 shutil.copy2(bit,desktop/(label+'.bit'))
 assert sha(desktop/(label+'.bit'))==sha(bit)==sha(target/'td_project'/(name+'_Runs')/'phy_1'/(name+'.bit'))
 for r in re.findall(r'<File Path="([^"]+)"',(target/'td_project'/(name+'.al')).read_text()):
  resolved=(target/'td_project'/r).resolve()
  assert resolved.is_relative_to(target) and resolved.exists()
 summary.append(dict(mode=key,bit=label+'/'+label+'.bit',sha256=sha(bit),bytes=bit.stat().st_size,
  freeze=root.name,desktop_bit=(desktop/(label+'.bit')).as_posix(),
  desktop_al=(target/'td_project'/(name+'.al')).as_posix(),physical_acceptance='NOT_RUN'))
models=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v','ph1p/ph1p_logic_hrio.v','ph1p/ph1p_phy_hr_pad.v']
(out/'vendor_models.json').write_text(json.dumps([dict(path='D:/td6.2.1/sim_release/'+n,
 sha256=sha(Path('D:/td6.2.1/sim_release')/n)) for n in models],indent=2)+'\n')
shutil.copy2(engine/'tools/native_toolchain.json',out/'toolchain.json')
(out/'diagnostics.json').write_text(json.dumps(summary,indent=2)+'\n')
readme='''# SC500 HDMI 正同步对照诊断（未验收）

先在TD易失下载根目录A_1080p30.bit，观察是否出现八条竖向色条。
若A仍输入不支持，再下载B_720p60.bit，分别记录A/B显示结果、照片和信息菜单读数。
两份对应AL在A_1080p30/td_project/positive_fhd30.al和B_720p60/td_project/positive_hd60.al。
人负责板卡操作。本端不写Flash、不停止用户工具，旧永久启动镜像保留。

A:1920×1080、2200×1125、30Hz，正HS[2008,2052)、正VS[1084,1089)。
B:1280×720、1650×750、60Hz，正HS[1390,1430)、正VS[725,730)。
二者都是独立DVI兼容RGB色条，同一整数级联PLL74.25/371.25MHz、原厂ODDR/串行器和TMDS引脚；独立布局。
没有相机、ISP、DDR、OSD、音频或HDMI AVI包，因此A没有VIC34 AVI元数据，B不替代1080p30迁移目标。
文件SHA和冻结身份见diagnostics.json；原7b8c08c相机bit、8d0098b厂商TPG失败镜像不覆盖。

仿真：严格5:1理想PLL时钟约1ppm偏差＋原厂ODDR；从三个串行数据引脚LSB反解，
A完整比较2073600个RGB像素/1080行/2475000个符号周期，B完整比较921600个像素/720行/1237500周期，
核对首末像素、全部有效行、同步区间、正极性和TMDS运行偏差。参考接收器在运行前冻结。
另在B冻结树运行相同生产PLL源码的原厂频率模型短测试，测得74.25/371.25MHz、5:1。
这两种测试不合并称为真实PLL＋全帧串行链验证；板上实际频率/锁定没有测量。

TD6.2.178840完整综合/P&R/bitgen：两份最终setup/hold TNS0、违例端点0，详细时序/资源见reports。
A WNS+0.334/+0.030ns，88/21216 Slice；B WNS+0.166/+0.022ns，90/21216 Slice。
均ERAM0/108、DSP0/40、PLL2/6、GCLK3/32。像素→串行相关路径实际在最终时序报告中，未设异步豁免。
一项异步复位输入延迟、四项TMDS输出板级延迟预算开放；不能声称所有路径/物理输出已验收。
预布局阶段PHY-5016（PLL输出驱动未定位或非时钟IO）告警保留；最终六个外部引脚与差分伴随脚均匹配。
这项告警没有被证实为根因，也没有凭正WNS判定为板级通过。内部check_timing无no_clock、PLL频率不匹配、
非法、dummy、组合环、遗漏路径或忽略约束。串行约束371.333MHz来自报告时间离散，不是实测频率。
15项输入预冻结（含参考测试），另保存6项由冻结准备脚本生成的构建控制文件及其SHA。

用户实测Q24G51F接受其他设备1080p30，保留这一现场事实。官方手册只列48～144Hz范围/60Hz预设，
不能据此直接判定不支持30Hz。A失败/B成功也不能单独判定30Hz兼容性：还涉及DVI模式、格式识别及布局。
两份均未上板；任何色条成功均不证明相机尺寸、采集FPS、物理DDR、RAW/GRAY稳定性或完整功能通过。
本轮不恢复EDGE/组合，分类继续UNCAL。

回退rollback.bit为原工程旧候选，SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65；
不声称它就是用户Flash中已知可用的文件，后者现场身份尚未取得。仅按既有人工操作回退。
'''
(out/'README.md').write_text(readme,encoding='utf-8');(desktop/'README.md').write_text(readme,encoding='utf-8')
rollback=engine/'release/native_1080p30/stage2_base_20261008/rollback.bit'
assert sha(rollback)=='bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
shutil.copy2(rollback,desktop/'rollback.bit')
(out/'SHA256SUMS.txt').write_text(''.join(sha(p)+'  '+p.relative_to(out).as_posix()+'\n'
 for p in sorted(out.rglob('*')) if p.is_file()),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
