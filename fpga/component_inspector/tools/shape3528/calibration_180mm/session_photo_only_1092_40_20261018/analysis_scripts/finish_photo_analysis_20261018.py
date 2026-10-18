from pathlib import Path
import hashlib,json,shutil,zipfile
r=Path.cwd();p=r/'fpga/component_inspector';out=p/'tools/shape3528/calibration_180mm/session_photo_only_1092_40_20261018'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
load=lambda q:json.loads(q.read_text('utf-8-sig'))
def write(q,s):q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(s.encode())
def save(q,d):write(q,json.dumps(d,ensure_ascii=False,indent=2)+'\n')
src=load(out/'sources.json');m=load(out/'photo_geometry.json')
for row in src['images']:
 assert sha(out/row['archived'])==row['sha256']
 assert sha(Path(row['original']))==row['sha256']
assert len(src['images'])==12 and len(m['measurements'])==150
baseline=p/'handoff/calibration_video_credit_180mm_20261017/source_snapshot'
sources=['user_source/hdl_source/frame_shape_search.v','user_source/hdl_source/inspection_region_config.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/roi_sobel_view.v']
for n in sources:
 q=out/'code_reference'/n;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(baseline/n,q)
 # Analysis only: production remains exactly the user-selected c093 algorithms.
 assert sha(p/n)==sha(baseline/n),n
for n in ['analyze_photo_session_20261018.py','measure_photo_session_20261018.py','finish_photo_analysis_20261018.py']:
 q=out/'analysis_scripts'/n;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(r/'tmp'/n,q)
findings=dict(status='ANALYSIS_ONLY_NO_RTL_OR_BIT_GENERATED',source_images=12,truth='large round openings=locating holes; small round openings=empty sites; P07-P12 visibly four front-facing devices',photo_scale_measurements=m['summary'],local_contrast_sweep=[.35,.50,.65],photo_diameter_ratio_large_to_small=[1.5333,1.5862],photo_area_ratio_large_to_small=[2.3964,2.5449],native_gray_thresholds_measured=False,native_1280x720_pixel_measurements=False,quality_truth_not_inferred_from_internal_light_spot=True,mixed_present_empty_same_strip_covered=False,rotated_carrier_new_session_covered=False,current_code=dict(body_gray_threshold=100,small_hole_gray_threshold=80,edge_gradient_threshold=80,half_mask_body=dict(long=[20,39],short=[16,36],aspect=[1.05,1.55],fill_min=.8),half_mask_empty=dict(long=[3,5],short=[3,5],aspect_max=1.4,fill=[.6,.9],max_T100_cells=5),half_mask_locating=dict(long=[7,9],short=[6,9],aspect_max=1.4,fill=[.6,.9]),units='640x360 half-resolution mask cells after 2x2 mean, not photo pixels or padded display box pixels',gray_edge_fusion_for_local_search=False,max_objects_per_region=2,max_objects_total=4),conclusions=['Three visible classes have separated external geometry in this session.','Large-hole diameter/area ratios in same photo are more credible than uncalibrated phone brightness.','High threshold may retain only LED central bright disk and lose rectangular body; body presence must use complete external component.','Large-hole interior background texture may fragment a high-threshold mask; reject using complete large-hole contour before admitting small/uncertain fragments. Mechanism hypothesis, not a replayed FPGA failure.','Small holes and locating holes must be discriminated by size plus contour, not brightness, row-above/below rule, or all orange edge pixels.','Present and empty do not share a single bright-object threshold; preserve separate gray masks and inspect their geometry margins.','Current search detector receives pre-Sobel RGB only. The orange overlay is not evidence of edge features participating in four-target classification. Native Sobel features must be explicitly routed/aligned if used for verification.','Threshold changes require synthetic geometry/boundary regression and same-board validation. No numeric native threshold derived directly from this phone batch.'],next_scope='Basic present/empty/locating class gates, maintain disabled observer build for acquisition; no code/build without later action request. No revival of jitter investigation.')
save(out/'findings.json',findings)
report='''# 1092/40纯观察照片：有件、空穴、定位孔分析

用户要求先分析三类状态，并明确“大的是定位孔”，允许一张图同时标注空穴和定位孔。本轮只归档与分析，没有修改RTL、没有调整运行阈值、没有生成新bit。继续使用66f9be7c纯观察版；照片可见PHOTO ONLY / DETECT OFF、EXP1092、GAIN40、WB R100 B100，没有检测框卡。该标题是现场版本对应线索，不代替硬件bit哈希读回或整机稳定性验收。

## 原图真值与分组

- P01/P02：全空载带，GRAY+EDGE；P03/P04同类场景EDGE；P05/P06同类场景RAW。上排小圆孔标空穴，下排完整大圆孔标定位孔。两端裁成半圆的定位孔不参加圆孔尺寸统计。
- P07/P08：四个正面器件，RAW；P09/P10同类场景GRAY；P11/P12同类场景GRAY+EDGE。大孔仍是定位孔。右边器件的内部亮斑与左边不同，但外矩形主体完整，不能因为亮斑偏形或内部暗块判成空穴；本轮不从这种差异推断质量合格或缺陷。
- 12张是两种摆放场景的重复/视图照片，不是12个独立工况。新批没有同一条载带有件与空穴混排、不同照明/曝光、明显旋转载带或摆放异常，不能据此宣布这些情况均已通过。

## 可复核的照片测量

只用未叠橙色边缘的P05—P10测量，手工按真实行列标中心、用原始图像局部暗载带与亮目标的对比度做35%/50%/65%门槛扫描，8邻域提取中心附近主分量；未做膨胀/闭运算。标注图用框核对选中的是孔外缘/器件主体，不凭原检测结果分类。

| 类别 | 重复照片中的目标数 | 50%局部对比度下照片宽×高 | 照片前景面积 | 照片填充率 |
|---|---:|---|---|---|
| 小空穴 | 12 | 12—15 × 14—16 | 148—181 | 0.769—0.857 |
| 大定位孔 | 22 | 22—25 × 22—25 | 380—463 | 0.725—0.806 |
| 有件外主体 | 16 | 45—49 × 54—60 | 2311—2501 | 0.880—0.953 |

单位是原始屏摄照片像素，受拍摄透视、显示器缩放、Gamma、手机曝光/JPEG影响；没有把它们当1280×720处理像素，也没有把手机灰度当FPGA灰度。重复目标数不代表独立样本量。P05/P06各自比较，大孔/小孔中位直径比分别1.533/1.586，面积比2.396/2.545，可确认本批两类孔的尺度分离。

门槛从35%升到65%时，小孔照片长边范围15—17变成13—15，大孔24—26变成20—23，仍有间隔；有件长边从59—61变成32—54，部分只剩内部亮圆/反光片。这个结果支持用较完整的矩形外主体判有件，不能靠过高门槛保留下来的中心亮斑判状态。门槛是局部照片对比度比例，只说明敏感性，不能据此将FPGA T100改成某个照片像素值。

## 对照c093代码的实际含义

frame_shape_search对处理RGB先算floor((R+2G+B)/4)，每2×2求均值，内部640×360。主体T100、孔T80；inspection_region_config两区实际教导范围：主体长20—39、短16—36格，长短比1.05—1.55、填充至少0.8；小孔长/短3—5格；大孔长7—9、短6—9格。圆孔共用长短比≤1.4、填充0.6—0.9，小孔另外限制T100亮格≤5。所有几何数字都是半分辨率格数；显示框另外外扩，不应拿显示框尺寸直接标这些范围。

新照片说明三类可用外观分离，但没有逆推原生T80/T100分量，不能把照片14像素直接写成empty_max14，也不能凭相机数值读数缺失排除样本。下轮可以检验小孔/大孔边界格数和2×2采样相位余量；若要改范围，需要在源像素/RTL回归里确认两类不重叠，同时保留大孔优先排除。

c093已有T100主体与T80小孔双遍，并在完整T80孔轮廓被确认后删除其中T100碎片。因此建议是针对整孔是否因范围/形状门槛而未被确认去验证，不能误称原先完全没有双门槛或定位孔排除。大孔内背景纹理可能让高门槛分量碎裂，若低门槛整孔也没确认，残留碎片有机会成为uncertain；这是代码机制与照片现象一致的假设，本批识别关闭，尚不是原失败的输入重放证明。

主体与空穴共存时应保留两遍检测各自候选，不能因为当前区域发现亮主体而忽略所有空穴。当前候选排序把有件和空穴同列优先，再按区域中心距离排，两个区域各最多2个，总4个；四个排在同一区域并不是4个都显示的保证。三类状态参数与名额/搜索范围是不同问题，后续不要拿范围外无结果当作真实类别错误，也不能拒收这种照片作为外观真值。

## GRAY和EDGE各自应承担什么

GRAY负责主体/孔的亮暗分离和面积；EDGE负责检查外矩形或整圆外轮廓，帮助排除背景纹理碎片，不能把整幅橙色像素数量当作有件。P01—P04/P11—P12背景同样有大量橙色边缘，说明“边缘多”本身不够。

已核对c093实际连接：frame_shape_search只接pre-Sobel post_rgb，输出搜索状态；roi_mode_classifier虽然有固定核心Sobel统计输入，但USE_SHAPE/USE_SEARCH最终选shape_state。因此四目标搜索分类主要还是灰度分量+几何，画面出现GRAY+EDGE不代表Sobel边缘已参与这三类状态判定。若后续要做用户要求的灰度+边缘共同确认，必须显式接入同一目标/同一帧的轮廓证据，核对延迟/模式与时序资源；不是只换显示MODE文字。

不按上下排固定类别。这次大孔在下、小孔或器件在上，载带转180度上下会交换；大小与主体轮廓不应因此改变含义。半孔、载带边缘和背景纹理不列为有效空穴候选。

## 下一步范围

这批足够建立三类基本外观及尺寸分离证据，先保留双灰度门槛T100/T80为现有基线，随后围绕完整主体、两类孔互斥范围和定位孔碎片抑制验证参数。原生亮度门槛不能用屏摄灰度直接替换。混排稳定性/边界摆放尚需后续同板证据，不在本轮宣称通过；不恢复抖动调查，不判摆放质量，不修改新bit。

sources.json保留12张原始来源路径、字节及SHA；photo_geometry.json包含150条门槛扫描测量，findings.json为结论与当前参数，code_reference为c093相关原源，analysis_scripts保留可复现方法。原图不改写，裁剪/标注只用于审阅。主生产源、正式构建指针、纯观察bit和旧包不变，未提交/推送/JTAG/Flash，无运行中构建/仿真。
'''
write(out/'ANALYSIS.md',report)
record=r/'开发实施/验收记录/20261018_A_纯观察照片三类状态分析_轮次17.md';assert not record.exists();write(record,report)
save(out/'package_sha256.json',{q.relative_to(out).as_posix():sha(q) for q in sorted(out.rglob('*')) if q.is_file() and q.name!='package_sha256.json'})
zipname=out/'PHOTO_SOURCES_AND_ANALYSIS_1092_40_20261018.zip'
with zipfile.ZipFile(zipname,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for q in sorted(out.rglob('*')):
  if q.is_file() and q!=zipname:z.write(q,q.relative_to(out).as_posix())
with zipfile.ZipFile(zipname) as z:
 assert z.testzip() is None
 for n,h in load(out/'package_sha256.json').items():assert hashlib.sha256(z.read(n)).hexdigest()==h,n
receipt=dict(status=findings['status'],photos=12,archive=out.relative_to(r).as_posix(),analysis=(out/'ANALYSIS.md').relative_to(r).as_posix(),package=zipname.relative_to(r).as_posix(),package_bytes=zipname.stat().st_size,package_sha256=sha(zipname),source_manifest_sha256=sha(out/'sources.json'),code_changed=False,new_bit_generated=False)
save(r/'tmp/photo_analysis_receipt.json',receipt)
q=p/'td_project/current_calibration_handoff.json';d=load(q);d['photo_state_analysis_20261018']=receipt
d['photo_only_trial']['field_photos_received']=dict(count=12,visible_header='PHOTO ONLY / DETECT OFF',visible_camera='1092/40 WB100/100',overlay_absence_visually_confirmed=True,bit_hash_read_back=False,stability_not_inferred=True)
d['next_action']='Basic present/empty/large locating-hole analysis received. Await later action request before RTL/build; do not change native80/100 based directly on phone gray. Verify separated geometry, full-body contrast, whole large-hole exclusion and explicit Sobel participation if fusion requested; mixed same-strip stability not covered.';save(q,d)
with record.open('a',encoding='utf-8') as f:f.write('\n原图及分析包 '+receipt['package']+'，'+str(receipt['package_bytes'])+'B，SHA256 '+receipt['package_sha256']+'，原图SHA与ZIPCRC通过。\n')
q=r/'AGENTS.md';t=q.read_text('utf-8');t=t[:t.index('## 当前断点')]+f'''## 当前断点（2026-10-18，纯观察新照片三类分析完成；未改检测代码）

- 用户本轮仅要求先分析有件/空穴/定位孔，明确大孔为定位孔、同图可分析两孔。12张原图已保存标定来源{out.relative_to(r).as_posix()}，P01—06全空+大定位孔（GRAY+EDGE/EDGE/RAW），P07—12四正面有件+大孔（RAW/GRAY/GRAY+EDGE）。标题PHOTO ONLY / DETECT OFF，1092/40/WB100；可见无框卡，不代表硬件bit哈希读回/稳定性通过。
- lj4747-contest-work HEAD55090063；主生产/当前阈值/正式构建/旧包不变；本轮只新增标定来源/报告与指针记录，没有新RTL/bit/提交/推送/JTAG/Flash。抖动排查仍暂停。仍用D:/fpga_download/3528_photo_only_66f9be7c.bit（此前六测试+实际路由通过，现场待完整验收）。
- RAW/GRAY原图中心标签局部对比度35/50/65%扫描150记录；50%时照片小孔12—15×14—16（12个重复目标）、大孔22—25×22—25（22个）、器件45—49×54—60（16个）。同图大/小孔径比1.533/1.586，面积比2.396/2.545。照片像素/灰度不等于1280×720或原生80/100；不拒收无检测值照片。高照片门槛会丢主体只剩内部亮斑，有件按完整外矩形；不凭内部暗斑判质量。
- 已核对c093：T100主体/T80孔双遍及整大孔确认后碎片剔除已存在；半分辨率主体L20—39/S16—36、empty3—5格、locating L7—9/S6—9格、圆形aspect≤1.4/fill0.6—0.9，empty亮格≤5。不能把照片尺寸直接写参数，也不能误说原先无双门槛。完整大孔没确认导致碎片保留是假设，未输入重放证明。
- 当前四目标搜索frame_shape_search接pre-Sobel RGB，最终USE_SHAPE选shape_state；GRAY+EDGE只是显示和固定核心统计，Sobel尚未参与这些搜索对象的类别决策。若后续实现双算法确认，须显式同目标/同帧对齐；本轮未接新算法。不固定上排/下排类别。各区2目标总4，按中心距离选，单区四件并非四件都显示。两场景重复照片未覆盖同载带混排/旋转/异常/照明变化。
- 包{receipt['package']}，{receipt['package_bytes']}B，SHA{receipt['package_sha256']}，12原图/对照裁剪/测量标注/150记录/c093参考/脚本/结论全SHA与ZIPCRC通过；验收记录开发实施/验收记录/20261018_A_纯观察照片三类状态分析_轮次17.md。下一步按用户后续指令再做参数修改/回归/同板验证，分析已完成不自行生成新bit。无运行中构建/仿真/新代理/新自动任务。
''';q.write_bytes(t.encode())
print(json.dumps(receipt,ensure_ascii=False,indent=2))
