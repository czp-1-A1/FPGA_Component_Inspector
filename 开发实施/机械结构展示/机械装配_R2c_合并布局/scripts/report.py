from pathlib import Path
import json,csv,html,shutil,hashlib,zipfile
Q=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局');E=Q/'evidence'
def read(n):return json.loads((E/n).read_text(encoding='utf8'))
def table(headers,rows):return '<table><thead><tr>'+''.join('<th>'+html.escape(str(v))+'</th>' for v in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(str(v))+'</td>' for v in row)+'</tr>' for row in rows)+'</tbody></table>'
def writecsv(name,headers,rows):
 with (Q/name).open('w',encoding='utf-8-sig',newline='') as f:w=csv.writer(f);w.writerow(headers);w.writerows(rows)
base=read('baseline_slicing.json');new=read('new_slicing.json');native=read('new_native.json');geom=read('geometry_check.json');board=read('board_checks.json');service=read('service_access_checks.json');access=read('access_checks.json');sweep=read('pose_sweep.json');reg=read('regression.json')
qty={'P01':2,'P02':4,'P03':1,'P04':2,'P05':2,'P08':2,'P09L':1,'P09R':1,'P10L':1,'P10R':1}
def count(r):return qty[r['part']]
def oldset(pct):return [r for r in base if r['fill_percent']==(100 if r['part']=='P08' else pct)]
def newset(pct):return [r for r in new if r['fill_percent']==pct and (not r['part'].startswith('P09') or r['orientation']=='sideX')]+[r for r in base if r['part'] in ['P04','P05','P08'] and r['fill_percent']==(100 if r['part']=='P08' else pct)]
def sums(rows):return {'mass_g':sum(r['mass_g']*count(r) for r in rows),'time_h':sum(r['time_seconds']*count(r) for r in rows)/3600,'support_g':sum(r['support_g']*count(r) for r in rows),'brim_g':sum(r['brim_g']*count(r) for r in rows)}
old,newtot=sums(oldset(100)),sums(newset(100));optold,optnew=sums(oldset(25)),sums(newset(25))
summary={'R2b_100':old,'R2c_100':newtot,'R2b_optional25_exceptP08':optold,'R2c_optional25_exceptP08':optnew,'mass_reduction_percent':100*(old['mass_g']-newtot['mass_g'])/old['mass_g'],'time_reduction_percent':100*(old['time_h']-newtot['time_h'])/old['time_h']}
(E/'cost_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf8')
quote_rows=[]
for scheme,rows in [('R2b',oldset(100)),('R2c',newset(100))]:
 for r in rows:quote_rows.append([scheme,r['id'],count(r),'PETG',100,'×'.join(f'{v:.2f}' for v in r['dimensions_mm']),r['orientation'],f"{r['mass_g']:.2f}",f"{r['support_g']:.2f}",f"{r['brim_g']:.2f}",r['time'],'','','','未实测；条件报价非订单'])
writecsv('主报价_100填充_供方填写.csv',['方案','零件','数量','材料','填充%','打印本体包络mm','方向','每件总用料g','每件支撑g约','每件附着边g约','每件机时预估','单件报价元','后处理费用元','备注或报价限制','状态'],quote_rows)
writecsv('可选比较_25填充_不替代默认.csv',['方案','总用料g','串行机时h','P08填充%','状态'],[['R2b',optold['mass_g'],optold['time_h'],100,'其他件25%，仅比较'],['R2c',optnew['mass_g'],optnew['time_h'],100,'其他件25%，仅比较']])
dimrows=[]
for p in native['parts']:
 b=p['bounds_mm'];dims=[b[i+3]-b[i] for i in range(3)];code=p['name'].split('_')[0]
 dimrows.append([code,1,'×'.join(f'{v:.2f}' for v in dims),f"{p['volume_mm3']/1000:.3f}",'PETG','100%','条件尺寸；实测后重算'])
 shutil.copyfile(E/('new_'+code+'.step'),Q/'询价参考'/(code+'_条件询价_禁止直接制造.step'))
writecsv('报价用尺寸_非制造图.csv',['零件','数量','装配XYZ包络mm','实体体积cm3','材料','默认填充','状态'],dimrows)
writecsv('紧固件增删与试配记录.csv',['项目','R2b','R2c','核验内容'],[['压架贯穿M4x65螺栓',8,4,'当前夹持57mm+垫片1.6+螺母3.2，露出3.2mm；叠层改变重选'],['对应M4螺母',8,4,'采购尺寸/螺纹覆盖/工具空间实配'],['对应M4平垫片',16,8,'OD9/ID4.5/t0.8；支脚上完整支承'],['相机根部、P04/P05/P08紧固件','保留','保留','不因合并自动放行'],['P08 M3x12/平垫片','4/4','4/4','Q1暂选，名义2.5mm拧入，实际啮合/顶底待验证']])
writecsv('首侧试配与实际报价决策.csv',['阶段','检查项','结果或金额','说明'],[['实测','必测表全部填写','','缺失不放行正式件'],['模拟件','现有板材/垫块按实测叠层及外形制作','','非新增打印试片'],['首侧','P09R+P10R放入/四向限位/防脱','','先模拟件'],['真实板卡','另一侧稳定等高支承','','禁止单侧悬托'],['实配','承托/孔槽轻修/实际间隙/工具空间/接口插拔','','记录修整及耗时'],['实配','变形/松动/蠕变/温升','','未试验待验证'],['报价','R2b实际整套报价','',''],['报价','R2c实际整套报价','',''],['报价','R2c首侧P09R+P10R费用','',''],['返工','原方案局部P02/P03重做费用','','区别尺寸变更原因'],['返工','新方案P09R/P10R重做费用','','未通过首侧前不安排整套'],['决策','采用R2b或R2c及原因','','综合实际报价/装配便利/返工成本']])
partrows=[]
for r in new:
 if r['fill_percent']==100:partrows.append([r['part'],r['orientation'],'×'.join(f'{v:.1f}' for v in r['dimensions_mm']),f"{r['mass_g']:.2f}",f"{r['support_g']:.2f}",r['time'],r['bead_edge_fit_200']])
fail_sweep=[r for r in sweep if r['clashes']]
body='''<h1>R2c 合并布局与询价</h1><p class="lead">PETG · 100%填充为默认 · 条件布局 · 未放行制造 · 不下单</p><p>R2b及P08 Q1为基线，旧版保留。打印件16→10是数量目标，不等同成本或可靠性结论。尚未下单CT暂停；旧P06暂停，HT02取消。</p>'''
body+='<h2>1. 新旧成本：相同切片口径</h2>'+table(['方案','件数','总用料g（含支撑/附着）','串行机时h','支撑g约','附着边g约'],[[name,n,f"{r['mass_g']:.2f}",f"{r['time_h']:.2f}",f"{r['support_g']:.2f}",f"{r['brim_g']:.2f}"] for name,n,r in [('R2b 100%',16,old),('R2c 100%',10,newtot)]])
body+=f"<p>离线估算用料变化：−{summary['mass_reduction_percent']:.1f}%；机时变化：−{summary['time_reduction_percent']:.1f}%。不是人民币报价或实际节省承诺。PrusaSlicer 2.9.6；0.4喷嘴、0.2层高、4圈壁、上下5层、100%直线填充；25%陀螺填充仅可选比较，P08仍100%。</p>"
body+='<p>供方报价需分别填写材料/机时/支撑清理/最低开机费/紧固件/装配成本。总价比较采用实际整套报价；另列首侧费用及尺寸修改后的重做范围。未取得报价前不决定采用R2c。</p>'
body+='<h2>2. 整体及局部布局</h2>'
for name in ['整体轴测','整体正视','整体俯视','整体右视','承托局部','右侧正式件']:body+=f'<figure><img src="视图/{name}.png"><figcaption>{name} · 默认占位尺寸，非实物验收</figcaption></figure>'
body+='<h2>3. 实体尺寸与减料措施</h2>'+table(['零件','数量','装配XYZ包络mm','体积cm³','材料','填充','状态'],dimrows)
body+='''<p>P09由受约束草图及特征重新建立：删除旧承托安装长槽、每角第二套贯穿孔/螺栓、74mm宽的整条高墙及多余前伸段。四点承托面保留，板外高支脚改为18×18mm；压架每侧两颗M4贯穿螺栓。P10使用10×6mm板外连接条，左右独立编号。收窄支脚和减少紧固件为试制选择，承载及抗扭可靠性尚未验证。</p><p>当前P09前端由板宽及lens_dy驱动，不能把178mm视为全部参数下的固定长度；旧56mm承托安装槽已取消，相机28mm高度短槽保留。压架孔距113mm，支脚至上压架的夹持厚57mm；M4x65名义螺母外露3.2mm，实际叠层改变须重选。</p>'''
body+='<h2>4. 打印方向与边界</h2>'+table(['零件','方向','本体打印包络mm','每件用料g','支撑g约','机时','含线宽路径适配200³'],partrows)
body+='''<p>主报价P09选侧面朝下：主要悬臂的Y/Z弯曲截面位于层内，仍须验证X向层间连接；根部及收窄支脚不作强度通过声明。底面朝下列为比较方向，悬臂底部需要较多支撑。P10顶面贴床，止挡朝上；需验证翘曲及止挡根部层间受力。P09支撑应从开放侧拆除，孔道需逐孔检查，不允许残留支撑影响垫片或硬限位贴合。</p><p>3mm附着边为切片口径，另计挤出线宽并核对实际路径；200³只是名义空间，供方须核对夹具/边缘禁区。切片输出仅留内部估算，不提供机器G-code。25%不改变默认100%。</p>'''
body+='<h2>5. 装配与几何复核</h2>'+table(['检查','结果'],[['默认实体体积干涉',len(geom['clashes_mm3'])],['布尔失败',len(geom['boolean_failures'])],['特征警告',len(geom['health'])],['板卡垂直放入失败姿态',sum(bool(x['clashes']) for x in board['board_insertion'])],['两压架竖直装入失败姿态',sum(bool(x['clashes']) for x in board['cap_insertion'])],['四向极限/最大抬起失败姿态',sum(bool(x['clashes']) for x in board['extremes'])],['D120/H60灯组件装入失败姿态',sum(bool(x['clashes']) for x in service['insertion'])],['默认接口/工具包络失败项',sum(bool(x['clashes']) for x in access['tools'])]])
body+='<p>四处承托按亚克力/实体/软垫交集检查；默认右侧名义17×19mm，扣5mm预算后12×14mm。孔均在接触区以外。当前矩形接口是假设，实际禁碰区与上下板错位须实测。上方名义0.5mm间隙不承担锁紧力；下Y止挡在抬起0.5mm后仍有0.5mm名义啮合。支脚18×18上Ø9垫片边距4.5mm。支承面积不等于薄亚克力挠曲通过。</p>'
body+='<h2>6. 行程、维护与参数回归</h2><p>相机微调28−4.5−2=21.5mm，与20mm分档交叠1.5mm；灯高双螺栓槽140−4.5−16−2=117.5mm；前后72−4.5−36−2=29.5mm。槽行程不等于整机可用范围。</p><p>沿用为检查上限的R2b保守窗口：D50–200、H10–92、D≥H+40；H&lt;16时Y≥−13，否则Y±14.75。Y0为同轴工作位。新扫描失败记录保留，最终结论以检查附表及限制为准，不扩大范围。</p>'
body+=f'<p>本次组合检查{len(sweep)}姿态，其中{len(fail_sweep)}姿态有干涉（包含故意检查窗口外的失败姿态）；详细数据见evidence/pose_sweep.json。离散采样不能证明连续全行程。</p>'
body+='<p><strong>维护固定步骤：D120/H60、Y0；拆外侧M4，将灯/P08整组抬高5mm，从前方送入后下降5mm落座，再装M4。M3在台面操作。恢复工作高度前检查线缆。</strong></p>'
body+=table(['回归参数','测试值','特征异常数','承托宽度达标'],[[r['parameter'],r['test'],len(r['health']),r['support_pass']] for r in reg])
body+='<p>偏心22mm及板长128mm测试用于证明失败会被识别，不是允许制造值。模型能重算不代表尺寸满足；实测后重新执行接口、承托和全行程检查。</p>'
body+='<h2>7. 必测与首次件</h2><p>先填合并前必测表：上下亚克力外形/错位、四角叠层、承托禁碰区、镜头XY及突出量、实际使用接口和线缆路径。未确定相机位置仍由参数驱动，不能按−20mm默认偏置放行。</p><p>实测后，首侧P09R＋P10R先配现有板材/垫块模拟件，不增加独立打印试片。真实板卡试装必须有稳定等高的另一侧支承。记录孔槽修整、装配耗时、变形、松动、蠕变及温升；模拟件通过不能替代真实板卡验收。</p><p>P08 Q1保持：四脚落点按用户可贴平确认；M3x12为暂选，名义拧入2.5mm，公差预算2.05–2.95mm；4mm仅图纸孔深，不是厂家确认全深可用。不得扩大灯壳螺纹孔。P08实物互换、承载、温升仍待验证。</p>'
body+='<h2>8. 文件入口</h2><ul>'
for name in ['FPGA_Inspector_R2c_Conditional.f3d','合并前必测表.csv','报价用尺寸_非制造图.csv','主报价_100填充_供方填写.csv','可选比较_25填充_不替代默认.csv','紧固件增删与试配记录.csv','首侧试配与实际报价决策.csv']:body+=f'<li><a href="{name}">{name}</a></li>'
body+='</ul><p>询价参考目录中的STEP仅对应未实测条件布局，不是制造放行文件。旧版文件校验与脚本、切片及几何证据保留。</p>'
css='body{font:16px/1.65 "Microsoft YaHei",sans-serif;color:#233043;background:#f5f7fa;max-width:1160px;margin:35px auto;padding:0 24px}h1{font-size:32px}h2{margin-top:42px;border-bottom:2px solid #237a83;padding-bottom:8px}.lead{background:#fff0cf;padding:18px;font-weight:bold}table{border-collapse:collapse;width:100%;background:white;font-size:14px}th,td{border:1px solid #d9e1e8;padding:9px;text-align:left}th{background:#e6eff3}figure{margin:22px 0;background:white;padding:12px}img{width:100%;height:auto}figcaption{color:#536775}a{color:#00677d}strong{color:#994100}@media print{body{background:white;margin:0}figure,table{break-inside:avoid}}'
(Q/'R2c_条件布局与报价比较.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>R2c条件布局与报价比较</title><style>'+css+'</style><body>'+body+'</body></html>',encoding='utf8')
print(json.dumps(summary,ensure_ascii=False))
