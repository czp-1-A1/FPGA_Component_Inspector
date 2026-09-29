from pathlib import Path
import sys,subprocess,json,re,os,concurrent.futures
R=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2\P01修订_R2a'); EXE=Path(r'E:\fusion360_codex_skill\.tools\PrusaSlicer2.9.6\PrusaSlicer-2.9.6\prusa-slicer-console.exe')
mesh=R/'evidence/打印方向网格';out=R/'evidence/slice_estimate';out.mkdir(exist_ok=True);env=os.environ.copy();env['TEMP']=env['TMP']=r'E:\fusion360_codex_skill\.tools\tmp'
codes=[p.stem for p in sorted(mesh.glob('*.stl')) if not p.stem.endswith('_cad')]
def job(c):
 supported=c in ['P01','P02','P05','CT01'];base=[str(EXE),'--datadir',r'E:\fusion360_codex_skill\.tools\slicer-config','--load',str(R/'通用PETG_仅预估.ini'),'--threads','2','--center','100,100','--brim-width','4' if c=='P01' else '3']
 if not supported:base+=['--no-support-material']
 def run(label,args):
  cmd=base+args;res=subprocess.run(cmd,env=env,capture_output=True,text=True,encoding='utf8',errors='replace');(out/(label+'.log')).write_text(res.stdout+'\n'+res.stderr,encoding='utf8');return res.returncode
 dest=out/(c+'.gcode');rc=run(c,['--export-gcode','--output',str(dest),str(mesh/(c+'.stl'))])
 result={'code':c,'exit':rc,'support_enabled':supported,'brim_mm':4 if c=='P01' else 3}
 if rc==0:
  s=dest.read_text(encoding='utf8');result['stats']={k:v.strip() for k,v in re.findall(r'^; (filament used \[[^\]]+\]|estimated printing time \([^\)]+\)) = (.*)$',s,re.M)}
  result['warnings']=[line for line in (out/(c+'.log')).read_text(encoding='utf8').splitlines() if re.search('warning|error|support|outside',line,re.I)]
  # An additional no-support run isolates the support overhead under the same setup.
  if supported:
   dest2=out/(c+'_no_support.gcode');rc2=run(c+'_no_support',['--no-support-material','--export-gcode','--output',str(dest2),str(mesh/(c+'.stl'))]);result['no_support_exit']=rc2
   if rc2==0:result['no_support_stats']={k:v.strip() for k,v in re.findall(r'^; (filament used \[[^\]]+\]|estimated printing time \([^\)]+\)) = (.*)$',dest2.read_text(encoding='utf8'),re.M)}
 return result
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 for q in pool.map(job,codes):
  results.append(q);print(q['code'],q['exit'],q.get('stats',{}).get('filament used [g]'),flush=True)
  (R/'evidence/slice_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
