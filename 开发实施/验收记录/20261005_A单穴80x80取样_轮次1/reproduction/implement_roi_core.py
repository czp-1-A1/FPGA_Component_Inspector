from pathlib import Path
import hashlib,json,shutil

root=Path(__file__).resolve().parents[2]
project=root/'fpga/component_inspector'
hdl=project/'user_source/hdl_source'
evidence=root/'开发实施/验收记录/20261005_A单穴80x80取样_轮次1'
evidence.mkdir(parents=True,exist_ok=False)

def replace_bytes(path,old,new):
    data=path.read_bytes()
    assert data.count(old)==1,(path,old,data.count(old))
    path.write_bytes(data.replace(old,new))

# Preserve the proposal bytes referenced by the existing optical evidence.
proposal=root/'开发实施/17_A单穴ROI实物标定_讨论稿.md'
photo=root/'开发实施/验收记录/20261005_130mm成像反馈_轮次3'
manifest_path=photo/'manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
snapshot=photo/'docs_snapshot/17_before_implementation.md'
snapshot.parent.mkdir(exist_ok=True)
shutil.copy2(proposal,snapshot)
assert hashlib.sha256(snapshot.read_bytes()).hexdigest()==manifest['proposal_sha256']
manifest['proposal_file']=str(snapshot.relative_to(root))
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(proposal,evidence/'approved_scope_before_status_update.md')
text=proposal.read_text(encoding='utf-8')
text=text.replace('状态：拟定范围，等待用户确认；没有据此修改RTL或生成新bit。','状态：2026-10-05用户回复“可以”，已批准以下范围；实现与验证进行中。')
text=text.replace('当前资料未批准此下一版；用户原要求仍为确认后生成。','本版范围已获用户批准；实际分类阈值及启用仍需后续实物标定与确认。')
proposal.write_text(text,encoding='utf-8')

top=hdl/'design_top_wrapper.v'
replace_bytes(top,b'localparam ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428;',
 b'localparam ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428;\r\n// One pocket core supplies the statistics; the large ROI remains a viewing aid.\r\nlocalparam SAMPLE_X0=472,SAMPLE_X1=552,SAMPLE_Y0=260,SAMPLE_Y1=340;')
replace_bytes(top,b'isp_top #(.ROI_X0(ROI_X0),.ROI_X1(ROI_X1),.ROI_Y0(ROI_Y0),.ROI_Y1(ROI_Y1))',
 b'isp_top #(.ROI_X0(SAMPLE_X0),.ROI_X1(SAMPLE_X1),.ROI_Y0(SAMPLE_Y0),.ROI_Y1(SAMPLE_Y1))')
replace_bytes(top,b'experiment_osd #(.ROI_X0(ROI_X0),.ROI_X1(ROI_X1),.ROI_Y0(ROI_Y0),.ROI_Y1(ROI_Y1))',
 b'experiment_osd #(.ROI_X0(ROI_X0),.ROI_X1(ROI_X1),.ROI_Y0(ROI_Y0),.ROI_Y1(ROI_Y1),\r\n .SAMPLE_X0(SAMPLE_X0),.SAMPLE_X1(SAMPLE_X1),.SAMPLE_Y0(SAMPLE_Y0),.SAMPLE_Y1(SAMPLE_Y1))')
replace_bytes(hdl/'isp/isp_top.v',b'parameter ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428',
 b'parameter ROI_X0=472,ROI_X1=552,ROI_Y0=260,ROI_Y1=340')

osd=hdl/'experiment_osd.v'
replace_bytes(osd,b'parameter ENABLE=1,ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428',
 b'parameter ENABLE=1,ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428,\r\n parameter SAMPLE_X0=472,SAMPLE_X1=552,SAMPLE_Y0=260,SAMPLE_Y1=340')
label=b''.join(f"  12'd{144+i}: character=8'd{ord(ch)};\r\n".encode('ascii') for i,ch in enumerate('CYAN 80X80'))
replace_bytes(osd,b"  12'd2243: character=digit(w_bcd[16+:4]);",label+b"  12'd2243: character=digit(w_bcd[16+:4]);")
replace_bytes(osd,b'wire [9:0] gray_sum=',
 b'wire sample_inside=x>=SAMPLE_X0 && x<SAMPLE_X1 && y>=SAMPLE_Y0 && y<SAMPLE_Y1;\r\nwire sample_border=sample_inside && (x==SAMPLE_X0 || x==SAMPLE_X1-1 || y==SAMPLE_Y0 || y==SAMPLE_Y1-1);\r\nwire [9:0] gray_sum=')
replace_bytes(osd,b"wire [23:0] picture_rgb=ENABLE && roi_inside ? (roi_border ? 24'h00ff40 : {gray,gray,gray}) : rgb;",
 b"wire [23:0] picture_rgb=ENABLE && sample_border ? 24'h00ffff :\r\n ENABLE && roi_inside ? (roi_border ? 24'h00ff40 : {gray,gray,gray}) : rgb;")

chain=project/'sim/tb_roi_chain.v'
replace_bytes(chain,b'xx+k>=256 && xx+k<768 && yy>=172 && yy<428',b'xx+k>=472 && xx+k<552 && yy>=260 && yy<340')
data=chain.read_bytes(); assert data.count(b'131072')==3
chain.write_bytes(data.replace(b'131072',b'6400'))

agents=root/'AGENTS.md'
text=agents.read_text(encoding='utf-8')
text=text.replace('17稿已修订为大框观察＋中央80×80穴内核心统计、默认UNCAL，等待用户确认后写RTL。',
 '用户2026-10-05回复“可以”，已批准17稿；正在实现大框观察＋中央80×80穴内核心统计、默认UNCAL。')
start=text.index('- **下一条具体操作**：')
end=text.index('- **提交/推送**：',start)
text=text[:start]+'''- **下一条具体操作**：完成本批80×80独立数值/框外亮点与OSD青框/旁路/同步测试，运行全部ModelSim；创建独立tmp/roi_core_td_build_20261005，完成TD并冻结新release/roi_core_80_20261005。顶层/ISP默认/OSD最小修改，单个统计单元算法及约束未改。旧198输入及全部release保留。用户自行下载，不操作JTAG/USB。
- **运行进程/设备**：当前无后台构建；接下来启动ModelSim/TD。设备由用户管理，尚无本版上板证据。
'''+text[end:]
agents.write_text(text,encoding='utf-8')
print('Approved core ROI implemented; optical proposal snapshot preserved; no constraints changed.')
