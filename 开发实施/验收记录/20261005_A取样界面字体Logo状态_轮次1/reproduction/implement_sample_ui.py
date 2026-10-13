from pathlib import Path
import shutil, re
root=Path(__file__).resolve().parents[2]
p=root/'fpga/component_inspector';h=p/'user_source/hdl_source'
baseline=root/'tmp/sample_ui_before_20261005'
baseline.mkdir(exist_ok=True)
for rel in ['AGENTS.md','开发实施/20_A结果显示字体Logo与状态处理_待确认方案.md',
 'fpga/component_inspector/user_source/hdl_source/experiment_osd.v',
 'fpga/component_inspector/user_source/hdl_source/isp/isp_top.v',
 'fpga/component_inspector/user_source/hdl_source/design_top_wrapper.v',
 'fpga/component_inspector/td_project/camera_to_dsi_display.al',
 'fpga/component_inspector/sim/tb_osd.v','fpga/component_inspector/sim/run_modelsim.ps1']:
 dst=baseline/rel;dst.parent.mkdir(parents=True,exist_ok=True)
 if not dst.exists():shutil.copy2(root/rel,dst)
def replace_bytes(path,old,new):
 data=path.read_bytes();assert data.count(old.encode('ascii'))==1,(path,old)
 path.write_bytes(data.replace(old.encode('ascii'),new.encode('ascii')))
replace_bytes(h/'isp/isp_top.v','output [1:0] class_state','output [1:0] class_state,\n    output [27:0] display_record')
marker='\n\r\n    data_96bit_to_128bit'
replace_bytes(h/'isp/isp_top.v',marker,'''\nroi_result_snapshot u_roi_result_snapshot(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.frame_start(raw_start),.invalidate(sample_cancel),
    .calibration_ok(calibration_ok),.sample_valid(sample_valid),.sample_new(sample_new),
    .class_state(class_state),.mean(sample_mean),.minimum(sample_min),.maximum(sample_max),
    .record(display_record));
\r\n    data_96bit_to_128bit''')
replace_bytes(h/'design_top_wrapper.v','wire [1:0] roi_class_state;','wire [1:0] roi_class_state;\nwire [27:0] roi_display_record;')
replace_bytes(h/'design_top_wrapper.v','.threshold(CLASS_THRESHOLD),.present_high(CLASS_PRESENT_HIGH),.class_state(roi_class_state),',
 '.threshold(CLASS_THRESHOLD),.present_high(CLASS_PRESENT_HIGH),.class_state(roi_class_state),.display_record(roi_display_record),')
replace_bytes(h/'design_top_wrapper.v','wire [26:0] roi_display;','wire [27:0] roi_display;')
replace_bytes(h/'design_top_wrapper.v','status_cdc #(.WIDTH(27)) u_roi_display','status_cdc #(.WIDTH(28)) u_roi_display')
replace_bytes(h/'design_top_wrapper.v','.S_data({roi_class_state,roi_sample_valid,roi_sample_mean,roi_sample_min,roi_sample_max}),.D_data(roi_display));',
 '''.S_data(roi_display_record),.D_data(roi_display));
    wire roi_display_valid;
    wire [1:0] roi_display_state_code;
    roi_display_state u_roi_display_state(
        .clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),.cfg_done(cam_display[0]),
        .exposure(cam_display[48:33]),.gain(cam_display[32:17]),.fps(mon_display[127:112]),
        .calibration_ok(CLASS_CALIBRATED && cam_display[48:33]==CLASS_EXPOSURE && cam_display[32:17]==CLASS_GAIN),
        .record(roi_display),.sample_valid(roi_display_valid),.state(roi_display_state_code));''')
replace_bytes(h/'design_top_wrapper.v',
 '.roi_valid(roi_display[24] && cam_display[0] && mon_display[127:112]!=0),\n        .roi_state(roi_display[26:25]==0 ? 2\'d0 : (!cam_display[0] || mon_display[127:112]==0 ? 2\'d1 : roi_display[26:25])),',
 '.roi_valid(roi_display_valid),\n        .roi_state(roi_display_state_code),')
al=p/'td_project/camera_to_dsi_display.al'
data=al.read_bytes();tag=b'        <Verilog>\r\n';assert data.count(tag)==1
names=['roi_result_snapshot','roi_display_state','osd_ascii_rom','osd_cjk_rom','osd_logo_rom']
rows=''.join(f'''            <File Path="../user_source/hdl_source/{name}.v">\r
                <FileInfo>\r
                    <Attr Name="UsedInSyn" Val="true"/>\r
                    <Attr Name="UsedInP&amp;R" Val="true"/>\r
                    <Attr Name="BelongTo" Val="design_1"/>\r
                    <Attr Name="CompileOrder" Val="{107+i}"/>\r
                </FileInfo>\r
            </File>\r
''' for i,name in enumerate(names))
al.write_bytes(data.replace(tag,tag+rows.encode()))
runner=p/'sim/run_modelsim.ps1';s=runner.read_text(encoding='utf-8')
s=s.replace('"$hdl/roi_classifier.v",\n        "$hdl/awb.v"','"$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v",\n        "$hdl/awb.v"')
s=s.replace('"$hdl/experiment_osd.v", "tb_osd.v"','"$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/experiment_osd.v", "tb_osd.v"')
s=s.replace('    $tests = @(\n','''    $tests = @(
        @{Name="display_state"; Pass="PASS display state:"; Sources=@("$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_display_state.v")},
''')
runner.write_text(s,encoding='utf-8')
doc=root/'开发实施/20_A结果显示字体Logo与状态处理_待确认方案.md'
s=doc.read_text(encoding='utf-8').replace('状态：**待用户确认，仅准备方案和预览，未修改RTL、约束或bit。**','状态：**用户已明确选择“直接用取样界面”，已批准本批RTL、ModelSim和TD实施；实施中。**')
s+='\n## 9. 用户选择\n\n2026-10-05用户选择“直接用取样界面”。本批仅实现取样布局；精简演示布局保留为历史讨论，不增加编译选择或菜单。保持CLASS_CALIBRATED=0，不启用T58。原待确认稿已保存tmp/sample_ui_before_20261005供本批证据冻结。\n'
doc.write_text(s,encoding='utf-8')
a=root/'AGENTS.md';s=a.read_text(encoding='utf-8');s=s[:s.index('## 当前断点')]+'''## 当前断点（2026-10-05）

- **目标/授权**：用户明确“直接用取样界面”，实施20方案的中文有限字模、安路Logo、最近采样状态撤销/恢复。仅取样界面，不实现演示模式选择。机构未固定，CLASS_CALIBRATED=0/T58不启用。
- **基线**：hx1p35a-contest-work，HEAD f87ccf1c6a38e84b58a4f86cecd532a71ae56e89；工作区已有改动保留。冻结roi_core_80_20261005 bit SHA 78d9a419cc75bae78655cc7608037959415ea67fd0452580446de0b7176c3c54和历史5版不覆盖；198输入基线/12项ModelSim/TD资源14122 Slice、31 ERAM、8 DSP，WNS建立1.437ns/保持.020ns。
- **当前变更/验证**：新增roi_result_snapshot/roi_display_state，接28位ROI邮箱；修改ISP和top接入，注册小ROM源文件及13项runner。本批尚未完成新RTL仿真/TD；原SDC不改。修改前文件已存tmp/sample_ui_before_20261005，待确认预览保持历史状态。
- **下一操作**：生成24×24中文字模/8×16 ASCII/96×64 Logo同步ROM和3级OSD；状态、字模、逐像素及真实RAW→ISP回归通过后隔离TD综合/布局布线。保存约束覆盖含既有缺口、资源和建立保持报告，冻结独立bit由用户下载。
- **现场/限制**：摄像头不能换，1024×600及四键不改；观测[256,768)×[172,428)，核心[472,552)×[260,340)。130mm为候选距离，最新照片有件MEAN78～88、空穴36～37是时点探索；正式同位完整范围和准确率等机构固定。30分钟/固化冷启动未测。没有DDR结果帧绑定。
- **进程/设备**：无后台构建；设备由用户管理，不操作JTAG/USB。
- **提交/推送**：未提交未推送。既有uii2c.v:148行尾空格不改，不称已同步。
''';a.write_text(s,encoding='utf-8')
print('Approved sampling UI connected; constraints and frozen releases unchanged.')
