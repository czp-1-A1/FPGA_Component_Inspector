from pathlib import Path
import hashlib,json,shutil

root=Path(__file__).resolve().parent.parent
record=root/'开发实施/验收记录/20261012_B定位孔灰度过渡修复_轮次1'
build=root/'tmp/hole_transition_r1_td_20261012'
audit=json.loads((build/'audit.json').read_text(encoding='utf-8'))
assert audit['status']=='PASS_source_simulation_and_routed_build'
p=root/'AGENTS.md'
s=p.read_text(encoding='utf-8')
start=s.index('## 当前断点')
s=s[:start]+'''## 当前断点（2026-10-12，孔边界有限灰度过渡修复v1已发布，待上板）

- **目标/断点**：用户确认后已完成孔搜索修复版。新镜像fpga/component_inspector/release/hole_transition_fix_v1_20261012/camera_to_dsi_display.bit；说明开发实施/44_B定位孔灰度过渡修复_上板说明.md；独立记录开发实施/验收记录/20261012_B定位孔灰度过渡修复_轮次1.md。软件验证/构建通过，现场未验收。
- **分支/基线**：lj4747-contest-work，HEAD3be3967f2457622566fb20b7cef3aa5038e7d885，暂存空，原有WIP保留。基于R100/B100 D3，冻结tmp/hole_transition_r1_td_20261012的210生产输入，仅tracker一个文件变化；其余209输入和第一endmodule后的追踪/状态子模块逐字节相同。冻结/构建/发布逐项散列一致。
- **改动**：hole_scanline仅新增两样点过渡计数及左暗边保持；每侧允许最多8像素101～119过渡，亮区宽度仍不包含灰带。≥120亮/≤100暗、20～64亮区宽、连续8像素两侧暗边、96±24孔距、三行372/380/388、运动与帧/分类门控均保留；默认R100/B100 /64，曝光2244/增益48未改，无新增菜单/失锁统计/自动ROI。
- **验证/镜像**：133项新边界要求及原失败模糊孔两帧获取锁定要求PASS（原fixture逐字节保留）；9项回归新跑PASS：tracking_late/status/age、tracking、isp_tracking_late、isp_tracking、isp_metadata_stop、isp_writer_stop、roi_chain，含原厂ERAM/真实ISP、四视图、6400像素统计、正反受限运动、失孔/恢复、残帧及中途调参撤销。TD6.2.168116综合/物理PASS；慢/快角Routed setup+0.536ns、hold+0.020ns、TNS0；Slice13508/21216=63.67%，ERAM48、DSP8，STA覆盖92.38%。37max_delay匹配/ignored0、SDC字节相同、124/10综合/物理告警内容与WB100相同。bit1789539字节，SHA ce410fe4c0d523307ebaae5c0952c1c2bc8e008f15ac28d6ea03f3912c2f149d；证据manifest逐项核对。
- **未决**：最新现场照片是修复前R100/B100、NO HOLE/ROW0及MEAN---。本轮仅证明并修复灰度过渡算法限制，不能断言现场唯一根因；实际孔亮暗、宽距、三行形状及位置未测。旧TAIL0遗漏与黑屏恢复原因未定保留。第一次准备脚本因换行判断中止及缺候选RTL编译失败日志保留，没有修改算法测试预期；原FAILED灰边记录、全部旧镜像及失败证据保留。
- **下一条操作**：人工核对本次新release路径/SHA（HDMI仍PFB W1C200，不能单凭它区分版本），下载复位后先静止对齐孔搜索三行/参考X464并保留相邻孔，观察连续两帧ROW7/LOCK，再慢左右/暂停/遮孔恢复、同位置有件/空穴验证；锁定后RAW/GRAY应恢复MEAN。若仍ROW0，采实际扫描灰度/宽距/拒绝原因再修，不取消定位分类门控，不放宽残帧检查或猜传感器寄存器。
- **进程/设备/提交**：本次单元仿真、ModelSim session83423及TD session30126均已结束，无运行中新构建/代理、JTAG/Flash操作；主线程唯一写入，未提交未推送。新镜像现场定位/分类、运动及显示验收待人工确认。
'''
p.write_text(s,encoding='utf-8')
proposal=root/'开发实施/42_B定位孔灰度过渡_修订待确认.md'
text=proposal.read_text(encoding='utf-8-sig')
note='> 状态更新（2026-10-12）：用户已确认并实施本提案的有限过渡范围；软件验证/镜像已完成，现场待验收。见[44上板说明](44_B定位孔灰度过渡修复_上板说明.md)。下文保留原提案记录。\n\n'
assert note not in text
pos=text.index('\n\n')+2
proposal.write_text(text[:pos]+note+text[pos:],encoding='utf-8')
for src,rel in [(p,'documents/AGENTS_final.md'),(proposal,'documents/'+proposal.name),(Path(__file__),'build_scripts/'+Path(__file__).name)]:
    dst=record/rel
    assert not dst.exists()
    dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(src,dst)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest_path=record/'manifest.json'
entries=json.loads(manifest_path.read_text(encoding='utf-8'))
for e in entries:assert sha(record/e['path'])==e['sha256'],e['path']
known={e['path'] for e in entries}
entries.extend(dict(path=q.relative_to(record).as_posix(),bytes=q.stat().st_size,sha256=sha(q)) for q in record.rglob('*') if q.is_file() and q!=manifest_path and q.relative_to(record).as_posix() not in known)
manifest_path.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for e in entries:assert sha(record/e['path'])==e['sha256'],e['path']
release=root/'fpga/component_inspector/release/hole_transition_fix_v1_20261012/camera_to_dsi_display.bit'
assert sha(release)==audit['bit']['sha256']
for e in json.loads((build/'inputs.json').read_text(encoding='utf-8')):
    assert sha(root/'fpga/component_inspector'/e['path'])==e['sha256']==sha(build/e['path'])
print(f'Final checkpoint and {len(entries)} evidence hashes verified; bit SHA {sha(release)}')
