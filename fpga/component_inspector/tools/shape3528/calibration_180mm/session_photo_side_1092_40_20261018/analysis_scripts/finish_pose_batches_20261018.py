from pathlib import Path
import hashlib,json,shutil,zipfile
from PIL import Image,ImageDraw
r=Path.cwd();p=r/'fpga/component_inspector';cal=p/'tools/shape3528/calibration_180mm'
side=cal/'session_photo_side_1092_40_20261018';flip=cal/'session_photo_flip_1092_40_20261018'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def write(q,s):q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(s.encode())
def save(q,d):write(q,json.dumps(d,ensure_ascii=False,indent=2)+'\n')
load=lambda q:json.loads(q.read_text('utf-8-sig'))
flip.mkdir(exist_ok=False)
uids=['c503b4a9-8cc4-4161-80b2-6ff37a6d4b45','9b5be48d-82bd-4ed4-bea5-e32199ba0f8f','ee7a239f-f3d3-433e-9827-f2a4192c9119','7cb8014d-2f45-424a-86a5-c9aad257990c','9d721019-8c6d-4fbc-b587-7f5cbff1567e','12847b97-b8f2-43aa-9975-d6cad9caaae5','c785ce9e-dfca-4b66-aaca-d98afdd3f3ec','c8dc4e30-4a8b-43c3-87cb-e4ea0547c4bc']
modes=['GRAY+EDGE','GRAY+EDGE','EDGE','EDGE','GRAY','GRAY','RAW','RAW']
boxes=[(650,492,988,669),(663,486,996,666),(631,496,979,678),(628,498,976,679),(663,505,981,671),(682,502,1008,675),(660,493,986,665),(713,512,1027,682)]
canvas=Image.new('RGB',(800,920),(235,235,235));draw=ImageDraw.Draw(canvas);photos=[]
for i,(uid,mode,box) in enumerate(zip(uids,modes,boxes),1):
 src=Path('C:/Users/yiziw/AppData/Local/Temp')/f'codex-clipboard-{uid}.jpg';dst=flip/f'F{i:02d}.jpg';shutil.copy2(src,dst);assert sha(src)==sha(dst)
 crop=Image.open(dst).crop(box);crop.save(flip/f'F{i:02d}_carrier_crop.png')
 x=((i-1)%2)*400;y=((i-1)//2)*230;canvas.paste(crop,(x+6,y+25));draw.text((x+6,y+5),f'F{i:02d} {mode} - user confirmed flipped',fill='black')
 photos.append(dict(id=i,archived=dst.name,original=src.as_posix(),sha256=sha(dst),bytes=dst.stat().st_size,mode=mode,physical_truth='flipped_user_confirmed',presence='present',quality='placement_abnormal',objects_left_to_right=[dict(index=k,presence='present',quality='placement_abnormal',truth='flipped_user_confirmed') for k in range(1,5)],photo_crop_xyxy=list(box),requires_existing_detection=False))
canvas.save(flip/'flip_contact_sheet.jpg',quality=94)
save(flip/'sources.json',dict(photos=photos,independent_scenes=1,visible_title='PHOTO ONLY / DETECT OFF',camera=dict(exposure=1092,gain=40,wb_r=100,wb_b=100),hardware_hash_readback=False))
side_text='''# 侧立样本：有件·摆放异常

用户确认这8张为器件侧立，按整组真实摆放标注，左至右4颗均保留有件/摆放异常真值；第三颗投影较方、斜置，不自行改标翻面或正常。S01/02/07/08 GRAY+EDGE，S03/04 GRAY，S05/06 EDGE。与上一批相同PHOTO ONLY / DETECT OFF、1092/40/WB100，识别关闭，不依赖旧检测输出。8张是同一场景重复/模式照片，不当8个独立姿态。

GRAY局部对比度35/50/65%扫描的photo_measurements.json有42条分量记录，均为屏摄像素，不是FPGA原生格数或80/100灰度。50%时前两颗宽32—34、高58—60，长短比1.735—1.812；第四颗宽31—32、高49，比1.531—1.581。正常上一批宽45—49、高54—60，侧立多数是投影变窄、发光面亮圆消失，长边仍明显大于22—25像素的大定位孔。不能只按短边接近孔径判孔。

第三颗50%照片分量48—50×38—39、轴向长宽比1.263—1.282，已接近正常正面长宽比，单靠长宽比过大无法抓全侧立；该照片分量填充0.708—0.739，与正常同法测量0.880—0.953不同，且亮带和外轮廓不同。这是本场景特征证据，不是跨姿态准确率，也不能直接把照片填充边界写入FPGA。

c093已经有POSE_LONG_MIN14/POSE_SHORT_MIN5、长宽比≤4、填充≥0.45的异常有件保留分支，并通过尺寸/比例/填充/参考原因提示复核；不能误称要从零添加，也不能把放宽正常尺寸范围当作解决侧立。应保留较宽的有件候选范围，再用正常模板的严格尺寸、比例、填充及外轮廓证据确认正常。反光条断裂时要避免一颗器件的多个亮片算成多颗。未改代码或新建bit，不做异常子类输出。
'''
flip_text='''# 翻面样本：有件·摆放异常

用户明确这8张是翻面，F01/02 GRAY+EDGE、F03/04 EDGE、F05/06 GRAY、F07/08 RAW，左至右4颗均标有件/摆放异常；下方大圆孔仍为定位孔，两端半孔不当空穴。统一输出语义与侧立相同，只在标定真值里保留翻面来源，避免混淆样本。曝光1092/增益40/WB100，现场标题PHOTO ONLY / DETECT OFF，无识别输出要求。8张为同一翻面摆放的重复/视图照片，不等于8个独立工况。

翻面与侧立的主要差异：翻面仍有完整、较宽的矩形主体，外形尺寸和比例可能接近正常正面。因此单纯扩大/缩小主体尺寸范围，或要求长宽比很大，不能可靠区分翻面。它仍是有件，不能因没有正常正面的大亮圆而判空穴。

RAW/GRAY可见反光主要集中在上下较亮的条带，中间是较灰的矩形面及小圆印迹；正常批则有较明显的大面积中央亮圆。EDGE/GRAY+EDGE也显示条带和内部轮廓分布不同。应将完整外矩形用于确认有件，再用目标内部中央与上下带的相对亮度/亮像素占比、内部边缘分布作摆放复核的候选特征。不是仅以圆亮斑缺失判空，也不是对整幅橙色像素计数。

这些是已看到的相对外观证据，不保证任意光照/反光/翻面角度都分离。屏摄Gamma/手机曝光使绝对灰度不可当FPGA阈值；此轮没有做原生80/100分量测量，没有确定可直接烧录的中央亮度阈值，未实施边缘融合。c093的POSE保留范围可帮助确认有件，但外形接近正常的翻面可能仍需内部特征才能提示异常，不能把既有POSE分支当所有翻面已识别。

侧立、翻面统一有件·摆放异常，穴内偏移项仍取消，整条载带旋转不等于器件摆放异常。本批没有正常/翻面混排或同载带有件/空穴混排，不能宣称混排稳定或不再uncertain。
'''
write(side/'ANALYSIS.md',side_text);write(flip/'ANALYSIS.md',flip_text)
save(side/'findings.json',dict(status='ANALYSIS_ONLY',truth='side_standing_user_confirmed',output='present_placement_abnormal',scene_count=1,photo_count=8,axis_aspect_alone_insufficient=True,third_object_relabelled=False,native_threshold_measured=False,rtl_changed=False))
save(flip/'findings.json',dict(status='ANALYSIS_ONLY',truth='flipped_user_confirmed',output='present_placement_abnormal',scene_count=1,photo_count=8,outer_geometry_alone_insufficient=True,internal_luminance_and_edge_distribution_candidate=True,native_threshold_measured=False,rtl_changed=False))
receipts=[]
for directory,prefix in [(side,'SIDE'),(flip,'FLIP')]:
 for entry in load(directory/'sources.json')['photos']:
  assert sha(directory/entry['archived'])==entry['sha256']==sha(Path(entry['original']))
 script=directory/'analysis_scripts';script.mkdir(exist_ok=True)
 shutil.copy2(r/'tmp/finish_pose_batches_20261018.py',script/'finish_pose_batches_20261018.py')
 if prefix=='SIDE':shutil.copy2(r/'tmp/archive_side_photos_20261018.py',script/'archive_side_photos_20261018.py')
 save(directory/'package_sha256.json',{q.relative_to(directory).as_posix():sha(q) for q in sorted(directory.rglob('*')) if q.is_file() and q.name!='package_sha256.json'})
 archive=directory/f'{prefix}_SOURCES_AND_ANALYSIS_1092_40_20261018.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for q in sorted(directory.rglob('*')):
   if q.is_file() and q!=archive:z.write(q,q.relative_to(directory).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for n,h in load(directory/'package_sha256.json').items():assert hashlib.sha256(z.read(n)).hexdigest()==h,n
 receipts.append(dict(kind=prefix,photos=8,analysis=(directory/'ANALYSIS.md').relative_to(r).as_posix(),archive=archive.relative_to(r).as_posix(),bytes=archive.stat().st_size,sha256=sha(archive),sources_sha256=sha(directory/'sources.json')))
save(r/'tmp/pose_photo_delivery_20261018.json',dict(batches=receipts,code_changed=False,new_bit=False))
q=p/'td_project/current_calibration_handoff.json';d=load(q);d['pose_photo_analysis_20261018']=dict(status='ANALYSIS_ONLY',batches=receipts,classification='present / placement_abnormal',subtype_only_in_truth_manifest=True,code_changed=False,new_bit=False)
d['next_action']='28 observer photos archived:12 basic,8 side standing,8 flipped. User currently supplying truth samples; analyze/collect, no new RTL or bit until subsequent action request. Side aspect alone and flipped external geometry alone insufficient; examine same-target internal contrast/contours without treating absence of central bright disk as empty.';save(q,d)
record=r/'开发实施/验收记录/20261018_A_侧立及翻面真实样本分析_轮次18.md'
assert not record.exists();write(record,side_text+'\n'+flip_text+'\n## 归档验证\n\n'+json.dumps(receipts,ensure_ascii=False,indent=2)+'\n\n16原图逐一SHA相同、ZIP逐文件SHA与CRC通过，无新代码/bit/构建/仿真/提交/推送/JTAG/Flash。前轮12图原包保持不变。\n')
base=p/'handoff/calibration_video_credit_180mm_20261017/source_snapshot'
for n in ['user_source/hdl_source/frame_shape_search.v','user_source/hdl_source/inspection_region_config.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/roi_sobel_view.v']:assert sha(p/n)==sha(base/n),n
q=r/'AGENTS.md';t=q.read_text('utf-8');previous=t[t.index('## 当前断点'):]
t=t[:t.index('## 当前断点')]+'''## 当前断点（2026-10-18，28张纯观察图已归档：基本三类/侧立/翻面；未改检测代码）

- lj4747-contest-work HEAD55090063；用户继续补真实样本，最新明确翻面8张，上轮侧立8张被新消息打断但已补齐归档/分析。两组均统一有件·摆放异常，侧立/翻面只作标定真值来源，不做细分输出；第三颗侧立较方的投影不自行改标翻面/正常。穴内偏移仍取消，整条载带旋转不当缺陷。
- calibration_180mm/session_photo_only_1092_40_20261018保留12基本图及旧包；新增session_photo_side_1092_40_20261018（S01—08，GRAY/EDGE/GRAY+EDGE）、session_photo_flip_1092_40_20261018（F01—08，四种视图）。全部PHOTO ONLY / DETECT OFF、1092/40/WB100，无旧识别结果要求，三组各是一种摆放场景重复视图，不当28独立工况。无硬件bit哈希读回/稳定性验收。
- 侧立S03/S04纯GRAY门槛扫描42记录：前两颗照片W32—34/H58—60，比1.735—1.812；第四W31—32/H49，比1.531—1.581；第三48—50×38—39、比1.263—1.282，近正常比例、fill0.708—0.739（正常照片0.880—0.953）。侧立长边仍比大孔大，但亮圆消失/短边变窄。不能只用长宽比、不能判空，避免亮片重复成多件；所有数字是照片分量不是原生80/100格数。
- 翻面保留完整宽矩形，外尺寸/比例可接近正常；RAW/GRAY上下亮条/中央较灰面与正常中央大亮圆不同。确认有件与判正常分开，内部中央/上下带相对亮度和边缘分布是候选复核特征，未生成绝对阈值、未实施边缘融合，不因无正面亮圆判空。c093已含POSE保留分支（Lmin14/Smin5/ratio≤4/fill≥0.45），但不能声称外形接近正常的翻面必被捕获。
- 本轮只新增两批原图/裁剪/测量/结论/压缩包/记录与指针；16原图SHA、两ZIP逐文件SHA与CRC通过。包路径与SHA见tmp/pose_photo_delivery_20261018.json和开发实施/验收记录/20261018_A_侧立及翻面真实样本分析_轮次18.md。主生产/阈值/正式构建/既有bit和旧包不变，无提交/推送/JTAG/Flash。
- 基本批结论仍有效：小孔/大定位孔按用户真值，照片大/小孔径比1.533/1.586，面积比2.396/2.545；不能直接用照片灰度/尺寸改FPGA80/100或半分辨率格数。c093已T100主体/T80孔双遍，整大孔确认后剔除内部碎片。四目标搜索实际主要pre-Sobel灰度几何，橙色叠边不等于Sobel已参与分类；后续融合须同目标/同帧对齐，各区域最多2目标/总4。
- 仍用D:/fpga_download/3528_photo_only_66f9be7c.bit收集，抖动排查暂停；没有同条载带正常/异常/空穴混排证据，不宣称混排稳定。下一步按用户后续动作请求再改参数/验证，当前仅数据分析，不自行生成新bit。无运行中构建/仿真/新代理/新自动任务。
''';q.write_bytes(t.encode())
print(json.dumps(receipts,ensure_ascii=False,indent=2))
