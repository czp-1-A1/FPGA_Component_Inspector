from pathlib import Path
import shutil, json, hashlib
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
build=root/'tmp/tracking_black_repro_r1_td_20261011'
assert not build.exists()
inputs=json.loads((root/'tmp/tracking_late_r3_td_20261011/inputs.json').read_text(encoding='utf-8'))
for e in inputs:
 src=project/e['path']; dst=build/e['path']; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(src,dst)
shutil.copytree(project/'sim',build/'sim',ignore=shutil.ignore_patterns('modelsim_work','*.log','modelsim.ini','*.wlf','measured_events.csv'))
tb=build/'sim/tb_isp_writer_stop.v'
s=tb.read_text(encoding='utf-8')
s=s.replace('wire [114:0] record;', 'wire [177:0] metadata; wire metadata_ready;\nwire [114:0] record;')
s=s.replace('isp_top dut(', 'isp_top #(.TRACKING(1),.HOLE_Y(380),.LATE_HOLE(1)) dut(.image_config({16\'d2244,16\'d48}),.frame_metadata(metadata),.frame_metadata_ready(metadata_ready),')
s=s.replace('video_in vi(', 'video_in #(.METADATA(1),.META_WIDTH(178)) vi(.I_frame_metadata(metadata),.I_frame_metadata_ready(metadata_ready),.O_completed_metadata(),')
s=s.replace('integer selected_mode=2;', 'integer selected_mode=3;')
s=s.replace('  if(nrows==600 && (packed_count', '  $display("META_DIAG ready=%b pending=%b wait=%0d camera_epoch=%0d writer_epoch=%0d receive_ready=%b receive_epoch=%0d matches=%b",metadata_ready,dut.metadata_pending,dut.metadata_wait,vi.camera_epoch,vi.writer_epoch,vi.metadata_receive[178],vi.metadata_receive[194:179],vi.metadata_matches);\n  if(nrows==600 && (packed_count')
tb.write_text(s,encoding='utf-8')
(build/'inputs.json').write_text(json.dumps(inputs,indent=2),encoding='utf-8')
evidence=root/'开发实施/验收记录/20261011_B追踪黑屏排查_轮次1'
evidence.mkdir()
shutil.copy2('C:/Users/yiziw/AppData/Local/Temp/codex-clipboard-c9f8db7c-faa4-4138-9b71-594cbe052d7b.jpg',evidence/'onsite_black_screen.jpg')
shutil.copy2(root/'AGENTS.md',evidence/'AGENTS_before.md')
checkpoint='''## 当前断点（2026-10-11，追踪版黑屏回归排查）

- **目标/断点**：用户反馈下方定位孔版画面黑、OSD正常，FRAME STALE/ROW0，FPS27/CFG1，FR03F9/VF03F8，ER/OF/UF0。先恢复完整帧发布，再验证追踪；不以改孔门限解决视频丢帧。板上镜像SHA尚未核对。
- **分支/基线**：lj4747-contest-work，HEAD3be3967f2457622566fb20b7cef3aa5038e7d885；既有WIP保留、暂存区空；当前生产仍下方v1的210输入，未修改RTL。旧release/source_snapshot/全部证据不改。
- **核查/证据**：检查真实ISP与video_in，发现原isp_writer_stop仿真未启用METADATA，而ISP追踪仿真无DDR写入器；当前补齐真实ISP+178位metadata+writer+CSI停钟集成复现。照片保存开发实施/验收记录/20261011_B追踪黑屏排查_轮次1/onsite_black_screen.jpg。FR/VF仅支持完整帧未发布判断，根因尚未证实。
- **下一条操作**：运行tmp/tracking_black_repro_r1_td_20261011/sim/run_modelsim.ps1 -OnlyTests isp_writer_stop；检查metadata_ready、48拍等待、capture/epoch和原生CSI尾部停钟，再按复现修复并冻结测试构建。
- **进程/设备**：尚未运行本轮测试；无JTAG/Flash/板卡操作，无代理。现场RAW/复位结果已异步询问，不阻塞代码核查。
- **提交/回退**：未提交未推送。故障候选下方v1 SHA0c1fe0ded306b532e3cb31310e556387de2d4c6caceeb53d80195b33a380745f；上方版SHAa93d219750d3d76564a4677895f63c8f3b811277fcc8007a9828f38c4608a379；静态manualWB SHAf71b8d6cc7e8d90c04a84c9ce4916403e2d763c49c5d2c57a1ebf511e8e02800，历史发布不覆盖。
'''
p=root/'AGENTS.md'; old=p.read_text(encoding='utf-8'); p.write_text(old[:old.index('## 当前断点')]+checkpoint,encoding='utf-8')
print(build)
