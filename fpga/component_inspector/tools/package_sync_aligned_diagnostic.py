"""Package immutable C outputs, old-A negative evidence and AVI observation."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,zipfile
engine=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser()
ap.add_argument('freeze',type=Path);ap.add_argument('negative',type=Path);ap.add_argument('avi',type=Path)
ap.add_argument('--desktop',type=Path,required=True)
ap.add_argument('--early',type=Path,nargs='*',default=[]);args=ap.parse_args()
root=args.freeze.resolve();neg=args.negative.resolve();avi=args.avi.resolve();desktop=args.desktop.resolve()
out=engine/'release/native_1080p30/sync_aligned_diagnostic_20261009'
if out.exists() or desktop.exists():raise SystemExit('Refusing existing release or desktop folder')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def validate_inputs(tree):
 meta=json.loads((tree/'freeze.json').read_text(encoding='utf-8-sig'))
 for e in meta['inputs']:assert sha(tree/e['path'])==e['sha256'],e['path']
 for e in meta['vendor_models']:
  p=Path(e['path'])
  if not p.is_absolute():p=Path('D:/td6.2.1/sim_release')/p
  assert sha(p)==e['sha256'],p
 return meta
meta=validate_inputs(root);negative_meta=validate_inputs(neg);avi_meta=validate_inputs(avi)
for e in meta['inputs']:
 if not e['path'].endswith('.al'):
  other=next(n for n in negative_meta['inputs'] if n['path']==e['path'])
  assert other['sha256']==e['sha256'],e['path']
positive=(root/'sim/aligned_pins.console.log').read_text(errors='replace')
assert 'PASS aligned pin frame: words2475000 pixels2073600 lines1080' in positive
assert 'HS/VS edges coincident' in positive and '** Fatal:' not in positive and '** Error:' not in positive
negative=(neg/'sim/legacy_negative.console.log').read_text(errors='replace')
assert '** Fatal: VS leading edge does not coincide with HS leading edge' in negative
assert 'PASS aligned pin frame:' not in negative and '** Error:' not in negative
observation=(avi/'sim/avi.console.log').read_text(errors='replace')
assert 'PASS AVI actual encrypted core:' in observation and '** Fatal:' not in observation and '** Error:' not in observation
name=meta['project'];runs=root/'td_project'/(name+'_Runs');phy=runs/'phy_1'
console=(phy/'console.log').read_text(errors='replace')
timing={}
for key in ('Setup','Hold'):
 matches=re.findall(key+r'\s*:\s*WNS\s+(-?\d+)ps\s+TNS\s+(-?\d+)ps\s+NUM_FEPS\s+(\d+)',console)
 assert matches,key+' timing missing'
 wns,tns,endpoints=map(int,matches[-1])
 assert wns>=0 and tns==0 and endpoints==0,key+' final timing not passing'
 timing[key.lower()+'_wns_ns']=wns/1000
assert 'ERROR' not in console and 'Error' not in console
area=(phy/(name+'_phy.area')).read_text()
resources={}
for key in ('slice','eram','dsp','pll','gclk'):
 m=re.search(r'(?m)^#'+key+r'\s+(\d+)\s+out of\s+(\d+)',area)
 assert m and int(m[1])<=int(m[2]),key
 resources[key]=dict(used=int(m[1]),capacity=int(m[2]))
final=(phy/'final_timing.rpt').read_text()
assert float(re.search(r'SWNS:\s*([\d.-]+)ns',final)[1])==timing['setup_wns_ns']
assert float(re.search(r'HWNS:\s*([\d.-]+)ns',final)[1])==timing['hold_wns_ns']
coverage=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',final)[1])
assert 'clkc[0] ->' in final and 'clkc[1]' in final
bit=phy/(name+'.bit');assert bit.stat().st_size>100000
al=(root/'td_project'/(name+'.al')).read_text()
refs=re.findall(r'<File Path="([^"]+)"',al)
assert len(refs)==9 and 'hdmi_ideal_pll' not in al and 'native_hdmi_pll.v' in al and name+'_top' in al
assert all((root/'td_project'/r).resolve().exists() for r in refs)
out.mkdir(parents=True);desktop.mkdir(parents=True)
def snapshot(tree,metadata,destination):
 destination.mkdir(parents=True,exist_ok=True)
 shutil.copy2(tree/'freeze.json',destination/'input_snapshot.json')
 with zipfile.ZipFile(destination/'input_snapshot.zip','w',zipfile.ZIP_DEFLATED) as z:
  for e in metadata['inputs']:z.write(tree/e['path'],e['path'])
 for p in (tree/'sim').glob('*.log'):
  q=destination/'simulation'/p.name;q.parent.mkdir(exist_ok=True);shutil.copy2(p,q)
snapshot(root,meta,out);snapshot(neg,negative_meta,out/'legacy_a_negative');snapshot(avi,avi_meta,out/'vendor_avi_observation')
for early in args.early:
 early=early.resolve();early_meta=validate_inputs(early)
 target=out/'early_rounds'/early.name;snapshot(early,early_meta,target)
 early_runs=early/'td_project'/(early_meta['project']+'_Runs')
 for run in ('syn_1','phy_1'):
  p=early_runs/run/'console.log'
  if p.exists():
   q=target/'td'/run/'console.log';q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
 early_bit=early_runs/'phy_1'/(early_meta['project']+'.bit')
 if early_bit.exists():shutil.copy2(early_bit,target/'early_candidate.bit')
shutil.copy2(avi/'sim/avi_packets.txt',out/'vendor_avi_observation/avi_packets.txt')
build_inputs=[]
for run in ('syn_1','phy_1'):
 for p in (runs/run).iterdir():
  if p.is_file() and (p.suffix in ('.log','.logw','.rpt','.txt','.area','.stat','.cfg','.tcl','.prj','.ts','.timing') or 'report' in p.name):
   q=out/'reports'/run/p.name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
  if p.name in ('settings.cfg','build.tcl',name+'.prj'):
   build_inputs.append(dict(path=p.relative_to(root).as_posix(),sha256=sha(p)))
(out/'generated_build_inputs.json').write_text(json.dumps(build_inputs,indent=2)+'\n')
shutil.copy2(bit,out/'C_1080p30_sync.bit');shutil.copy2(bit,desktop/'C_1080p30_sync.bit')
for e in meta['inputs']:
 q=desktop/e['path'];q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/e['path'],q)
shutil.copytree(runs,desktop/'td_project'/(name+'_Runs'))
for p in [desktop/'td_project'/(name+'.al'),*list((desktop/'td_project'/(name+'_Runs')).glob('*/*.prj'))]:
 p.write_text(re.sub(r'(<Project[^>]* Path=")[^"]+',lambda m:m[1]+(desktop/'td_project').as_posix(),p.read_text(),count=1))
for r in re.findall(r'<File Path="([^"]+)"',(desktop/'td_project'/(name+'.al')).read_text()):
 p=(desktop/'td_project'/r).resolve();assert p.is_relative_to(desktop) and p.exists(),r
assert sha(bit)==sha(desktop/'C_1080p30_sync.bit')==sha(desktop/'td_project'/(name+'_Runs')/'phy_1'/(name+'.bit'))
rollback=engine/'release/native_1080p30/stage2_base_20261008/rollback.bit'
assert sha(rollback)=='bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
shutil.copy2(rollback,desktop/'rollback.bit')
shutil.copy2(engine/'tools/native_toolchain.json',out/'toolchain.json')
summary=dict(bit='C_1080p30_sync.bit',sha256=sha(bit),bytes=bit.stat().st_size,
 desktop_bit=(desktop/'C_1080p30_sync.bit').as_posix(),desktop_al=(desktop/'td_project'/(name+'.al')).as_posix(),
 source_freeze=root.name,negative_freeze=neg.name,avi_freeze=avi.name,physical_acceptance='NOT_RUN',
 setup_tns_ns=0,hold_tns_ns=0,violating_endpoints=0,sta_coverage_percent=coverage,
 all_paths_timing_accepted=False,resources=resources,**timing)
(out/'diagnostic.json').write_text(json.dumps(summary,indent=2)+'\n')
readme='''# C 1080p30 同步对齐色条（诊断，待上板）

TD易失下载根目录C_1080p30_sync.bit；AL为td_project/sync_aligned_fhd30.al。
旧Flash、A/B、原相机和厂商TPG包保留。人操作板卡，本端不烧录。

相对于失败A，C仅将VS首尾边沿与HS前沿对齐。RGB色条、1920×1080、2200×1125、
74.25/371.25MHz级联PLL、串行器/ODDR和四对TMDS引脚保持原方案。独立布局。
HS为[2008,2052)，VS从活动坐标(y1083,x2008)至(y1088,x2008)，5整行；
前沿定义的front=4、back=36，总1125，30Hz目标不变。没有AVI/音频、相机或DDR。
正确相位是CTA官方Figure2的HS定义行语义，不是减少帧总数或改变采集目标。
这是具体时序差异修正，尚未证明它是实物失败的根因。

参考依据：https://www.cta.tech/cta-861-ovt-calculator/ （公开Figure2）
作者实现交叉核对：https://raw.githubusercontent.com/hdl-util/hdmi/master/src/hdmi.sv
新接收参考在运行前冻结：反解三个实际串行数据引脚，比较2073600个RGB像素、1080行、
2475000符号和全部边界；VS区间按平坦像素坐标计算并断言首尾与HS沿重合，PASS。
旧A新相位准则反例明确失败，raw Fatal日志保留于legacy_a_negative；这不是C失败，
也不事后改写原A旧计数准则PASS的有限范围。全帧采用严格5:1理想时钟＋原厂ODDR，
真实生产PLL源码与A/B相同；本轮未重跑真实PLL模型或实测板上时钟。
独立厂商核AVI观察：6630包ECC、2个RGB/VIC34包校验通过，见vendor_avi_observation；
只是实际核并行符号的理想时钟测试，不据此认定原物理链信息包通过或误VIC为根因。

TD6.2.178840完整综合/P&R/bitgen，setup/hold TNS0、违例端点0，WNS见diagnostic.json，
详细资源/时钟地点/相关像素至串行路径/告警见reports。复位和4路TMDS板级预算仍开放，
PHY-5016保留，不能称完整物理路径闭合或上板已通过。原25相机测试本轮未重跑。
15项预冻结输入＋6项由冻结脚本生成的构建文件另存SHA；参考、模型SHA和日志均归档。
early_rounds保留第一轮参考/输入/日志：C完整帧和TD通过，旧A触发预期相位Fatal，
但运行脚本错误依赖ModelSim进程退出码将其归为执行失败。修正只涉及结果归类；
参考和RTL不改，第二轮重新冻结并运行正反例/完整TD。不抹去第一轮记录。

用户已确认A输入不支持、B能显示色条，B不是相机/DDR/采集FPS验收。
C只验证这一个同步差异；记录是否色条/输入不支持，若能显示还需信息菜单实际分辨率/Hz。
阶段2人工门槛没有通过，完整EDGE/组合不准入，分类UNCAL。
rollback.bit为仓库旧候选，SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65；
不声称它就是用户Flash中能用的旧文件。烧录及回退沿用人工易失操作。
'''
(out/'README.md').write_text(readme,encoding='utf-8');(desktop/'README.md').write_text(readme,encoding='utf-8')
(out/'SHA256SUMS.txt').write_text(''.join(sha(p)+'  '+p.relative_to(out).as_posix()+'\n'
 for p in sorted(out.rglob('*')) if p.is_file()),encoding='utf-8')
print(json.dumps(summary,indent=2))
