from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,shutil

root=Path(__file__).resolve().parents[2]
project=root/'fpga/component_inspector'
directory=root/'开发实施/验收记录/20261005_80x80单穴反馈_轮次1'
record=directory.with_suffix('.md')
assert not directory.exists()
directory.mkdir(parents=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
temp=Path('C:/Users/yiziw/AppData/Local/Temp')
names=[
 'fb15551d-6dcb-4160-b37c-e9ebf2df6650',
 '4a849e17-5d00-4e26-9ae2-19aa74f1f684',
 '42297a9e-d5db-4bb4-be5b-7b64125c1bc8',
 '615875ea-efce-46c8-937f-8c9f7ea7a2d2',
 'a4b19bff-5414-4b86-a573-daa317e8c78d',
 '76bc5c87-6cd1-4b92-829b-971d39a6866d',
 '10701e4f-c773-47b6-baa4-2936d5a00951',
 'ac7d7c3d-da23-4282-aee0-805830b26e67',
 '0acbe629-020d-4659-8f5e-a06942a64538',
]
# Manually read FPGA OSD digits; no grayscale derived from phone photographs.
values=[(85,27,255,27),(88,27,255,27),(78,28,253,26),(82,27,255,27),
        (36,26,112,27),(37,26,112,26),(37,25,112,27),(37,26,112,26),(36,26,110,26)]
photos=[];seen={}
for n,(name,(mean,minimum,maximum,fps)) in enumerate(zip(names,values),1):
    source=temp/f'codex-clipboard-{name}.jpg';target=directory/f'photo_{n:02}.jpg'
    shutil.copy2(source,target);digest=sha(source);assert sha(target)==digest
    photos.append({'photo':n,'source_path':str(source),'file':target.name,'bytes':target.stat().st_size,
        'sha256':digest,'duplicate_bytes_of_photo':seen.get(digest),
        'same_display_snapshot_as_photo':6 if n==8 else None,
        'human_truth':'PRESENT' if n<=4 else 'EMPTY','exposure_half_lines':2244,'gain_index':48,
        'roi_mean':mean,'roi_min':minimum,'roi_max':maximum,'input_width':1024,'input_height':600,
        'input_fps_display':fps,'L':0,'F':0,'I':0,'G':0,'CFG':1,'roi_valid':True,'recent_state':'UNCAL',
        'label':'CYAN 80X80','observation_green_frame_visible':True,'sampling_cyan_frame_visible':True})
    seen.setdefault(digest,n)
release=project/'release/roi_core_80_20261005'
previous=json.loads((release/'manifest.json').read_text(encoding='utf-8'))
assert sha(release/'camera_to_dsi_display.bit')==previous['bitstream']['sha256']
for entry in previous['verified_build_inputs']:assert sha(project/entry['path'])==entry['sha256']
assert sha(project/'td_project/camera_to_dsi_display.al')==previous['project_sha256']
manifest={
 'recorded_at_utc':datetime.now(timezone.utc).isoformat(),
 'branch':previous['branch'],'head':previous['head'],'reported_working_distance_mm':130,
 'human_confirmation':'条件一致；照片是几个时点，未记完整10秒范围。确认本次130 mm，图1～4有件、图5～9空穴，光源及对焦未调整。',
 'light_and_focus_unchanged_between_groups_human_confirmed':True,
 'light_type_and_level_unknown':True,'component_part_number_unconfirmed':True,
 'full_10_second_mean_range_measured':False,'repeat_placement_protocol_completed':None,
 'repeat_placement_protocol_note':'User confirmed only time-point snapshots; formal repeat-placement completion is not established.',
 'statistics_scope':'80x80 cyan core ROI [472,552) x [260,340), 6400 pixels; 512x256 green region for viewing only',
 'present_means':[85,88,78,82],'empty_means':[36,37,37,37,36],
 'observed_present_mean_range':[78,88],'observed_empty_mean_range':[36,37],'observed_mean_gap':41,
 'candidate_only':{'threshold':58,'present_high':True,'comparison':'mean >= 58 PRESENT, mean < 58 EMPTY; only a candidate using displayed snapshots',
     'empty_max_margin_levels':21,'present_min_margin_levels':20,'approved_for_rtl':False},
 'formal_threshold_not_calibrated':True,'classification_accuracy_measured':False,
 'placement_note':'Object shifts relative to cyan ROI in photos 1-4; especially 3 and 4 include different portions of the component and dark surround. Pocket-core geometric fit not formally measured.',
 'same_display_snapshot_duplicate':[{'photo':8,'same_as_photo':6,'note':'Same photographed scene, MEAN/MIN/MAX/FPS and FR/SEC; not an independent temporal observation'}],
 'unique_file_count':len(seen),'maximum_independent_display_snapshots':8,
 'expected_release_bit':previous['bitstream']['path'],'expected_release_bit_sha256':previous['bitstream']['sha256'],
 'actual_programmed_bit_identity':'Unverified binary identity; dual frames and CYAN 80X80 photographed behavior matches expected release',
 'live_198_build_inputs_and_project_match_release':True,
 'photos':photos,'modified_rtl_this_turn':False,'modified_release_this_turn':False,
 'continuous_30min_test':False,'four_keys_verified_this_round':False,'cold_boot_verified':False,
}
duplicates=[(e['photo'],e['duplicate_bytes_of_photo']) for e in photos if e['duplicate_bytes_of_photo']]
dup_note='；原始JPEG字节重复：'+str(duplicates) if duplicates else '；JPEG字节未发现完全重复'
rows='\n'.join(f"| {e['photo']} | {'有件' if e['human_truth']=='PRESENT' else '空穴'} | {e['roi_mean']} | {e['roi_min']} | {e['roi_max']} | {e['input_fps_display']} | {'与图6同一显示快照' if e['photo']==8 else ''} |" for e in photos)
record.write_text(f'''# 80×80单穴上板反馈，轮次1

日期：2026-10-05。用户确认仍130mm，图1～4有件、图5～9空穴，两组光源及对焦未调整；本次是几个时点照片，未记录完整10秒MEAN范围。不能补填重复摆放协议已完成。

## 界面与实物观察

9张照片均显示绿色大观测框、青色80×80取样框和CYAN 80X80说明。EXP2244（half-line）、GAIN48（index），INPUT1024×600、ROI VALID、RECENT UNCAL、CFG1。大定位孔均在穴位上方，两类方向一致。小框未覆盖上方大定位孔，主要落在目标单穴区域；严格穴内核心边界是否全部落入仍需现场复核。

有件时元件相对青框位置有变化，尤其图3、4取入的主体和黑色周边比例不同。80×80不要求包整个元件或整个穴位，但两类应取同一穴内位置；下一次先对齐固定再观察。当前照片能观察到双框/灰度/有效统计，并不能独立证明四键、连续30分钟、无冻结/撕裂或冷启动。

## FPGA屏幕读数

以下数字由OSD人工读取，不计算手机拍屏灰度。输入FPS为工程输入帧计数显示，不是显示器刷新率。

| 图 | 真值 | MEAN | MIN | MAX | 输入FPS | 备注 |
|---|---|---:|---:|---:|---:|---|
{rows}

各图可读L/F/I/G均0000，仅为相应拍照时点。图8与图6的画面及FR/SEC/读数一致，不算独立时点{dup_note}。共9个附件，最多8个独立显示快照。

## 判断与候选阈值

有件MEAN快照78～88，空穴36～37，观测间隔78−37=41级。与上一轮大框统计分别记录，不能混合标定。当前支持均值特征继续试验，不等于完整时间稳定范围、泛化保证或分类准确率。

仅作讨论的阈值候选为T=58、亮侧有件：有效且已标定时mean≥58为PRESENT，mean<58为EMPTY。对当前快照，离空穴最高37为21级，离有件最低78为20级；这只是快照余量。尚未批准写入RTL，交付bit继续CLASS_CALIBRATED=0/UNCAL。

有件MAX253～255说明后AWB的8位灰度至少有一个像素接近/达到上限，不足以确定RAW饱和或高亮面积；当前无需增加曝光/增益。空穴内部的小亮孔已取入统计，这可以作为固定区域特征的一部分，但不能把上方大定位孔或框外亮区混进取样。

## 下一步现场记录

继续使用当前bit，固定130mm/EXP2244/GAIN48、同一焦点/光源和同向载带。将同一个穴内位置对准青框，固定观察10秒；分别记录有件和空穴的MEAN最低/最高、MIN/MAX、VALID、INPUT FPS、L/F/I/G。每类移开后重新摆放，再记录一次。总共4段10秒，只需记数字即可，不必每帧拍照。

获得完整范围后再确认T/方向与启用批次；若范围仍有足够间隔，可以从T=58候选开始验证，重做ModelSim/TD并测真实分类准确率。若覆盖混入邻穴/台面或边界不适配，先反馈青框与穴位边界再调整ROI。

## 证据和代码状态

9个JPEG按原字节归档为photo_01.jpg～photo_09.jpg，副本SHA逐项一致；manifest保存来源、读数、重复、条件确认和未测项。冻结bit本机SHA再次核对为{previous['bitstream']['sha256']}；198项输入及.al仍匹配冻结版。照片界面与roi_core_80_20261005一致，实际下载的二进制身份未经下载日志核验。

本轮仅新增实物反馈记录/manifest/照片并更新AGENTS；未改RTL/约束/release，未生成新bit，未运行ModelSim/TD/JTAG，未提交/推送。旧冻结验收文档和镜像保持。
''',encoding='utf-8')
manifest['report_file']=record.name;manifest['report_sha256']=sha(record)
(directory/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(Path(__file__),directory/'record_roi_core_feedback.py')

agents=root/'AGENTS.md';text=agents.read_text(encoding='utf-8')
text=text.replace('独立版本已冻结，等待用户下载采样；未上板，不当作完整A验收。',
 '独立版本已冻结，收到双框/CYAN与有效统计的上板照片；当前快照两类分离，完整10秒范围和重复摆放待记录，不当作完整A验收。')
# Remove only this task's duplicate checkpoint line; preserve frozen evidence snapshots.
lines=text.splitlines();seen_freeze=False;filtered=[]
for line in lines:
    if line.startswith('- **冻结镜像**：'):
        if seen_freeze:continue
        seen_freeze=True
    filtered.append(line)
text='\n'.join(filtered)+'\n'
start=text.index('- **下一条具体操作**：');end=text.index('- **运行进程/设备**：',start)
text=text[:start]+'''- **最新单穴实物反馈**：20261005_80x80单穴反馈_轮次1保存9原始JPEG/manifest及报告。用户确认130mm、图1～4有件/5～9空穴、光源和焦点未调，仅几个时点、未记完整10秒范围。有件MEAN85/88/78/82（78～88），空穴36/37/37/37/36（36～37），快照间隔41级；图8与图6同一显示快照不算独立。EXP2244/GAIN48、VALID/UNCAL/CFG1、INPUT1024×600及FPS26/27，可读L/F/I/G均0。青框相对元件位置有变化，需固定同一穴内取样位置；不是原始图像标定或准确率。T58/亮侧仅讨论候选，尚未批准写RTL；下载二进制身份未从日志核验。198输入/.al和本机冻结bit哈希核对一致，本轮未改RTL/约束/release/bit。
- **下一条具体操作**：继续当前UNCAL版，130mm/EXP2244/GAIN48及同一焦点/光源，两类对齐同一个穴内核心；每类固定10秒记MEAN最低/最高，再移开重新摆放重复一次，共4段10秒，并记录MIN/MAX/VALID/INPUT FPS/L/F/I/G。取得范围后再确认T/方向与启用批次；若ROI不适配先调整取样。分类准确率/30分钟/固化冷启动未测。
'''+text[end:]
text=text.replace('最终说明18及验收记录已保存。','18及离线验收保持冻结，最新实物记录另存。')
agents.write_text(text,encoding='utf-8')
manifest['checkpoint_file']='AGENTS.md';manifest['checkpoint_sha256']=sha(agents)
# Save the dated handoff separately without rewriting any frozen build evidence.
shutil.copy2(agents,directory/'AGENTS_snapshot.md')
manifest['evidence_files']=[{'path':f.name,'bytes':f.stat().st_size,'sha256':sha(f)} for f in sorted(directory.iterdir()) if f.is_file() and f.name!='manifest.json']
(directory/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for entry in manifest['evidence_files']:assert sha(directory/entry['path'])==entry['sha256']
print('9 photographs copied and verified;',len(seen),'unique byte files; snapshot 8 duplicates 6; mean gap 41, T58 candidate only.')
print('Current inputs match release; no RTL/constraints/release changed; records and checkpoint saved.')
