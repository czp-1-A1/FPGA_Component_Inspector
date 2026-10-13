from pathlib import Path
import re

r=Path(__file__).resolve().parents[2]
p=r/'fpga/component_inspector'
hdl=p/'user_source/hdl_source'
def edit(path,changes):
    s=path.read_text(encoding='utf-8')
    for old,new in changes:
        assert s.count(old)==1,(str(path),old[:100],s.count(old))
        s=s.replace(old,new)
    path.write_text(s,encoding='utf-8',newline='\r\n')

edit(hdl/'isp/isp_top.v',[
 ('    output [27:0] display_record','    input [17:0] observation_request,\n    output [82:0] observation_record,\n    output [27:0] display_record'),
 ('  assign O_tlast  = awb_O_tlast','  assign O_tlast  = view_last'),
 ('wire [10:0] roi_x;', '''reg [17:0] observation_tag;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
 if(!I_rst_n) observation_tag<=0;
 else if(raw_start) observation_tag<=observation_request;
end
wire observation_match=observation_tag==observation_request || raw_start;
wire view_valid,view_last,view_early;
wire [95:0] view_rgb;
wire [12:0] edge_pixels,edge_count;
wire [23:0] edge_sum;
roi_sobel_view #(.CORE_X0(ROI_X0),.CORE_X1(ROI_X1),.CORE_Y0(ROI_Y0),.CORE_Y1(ROI_Y1)) u_roi_sobel_view(
 .clk(axi4s_video_aclk),.rst_n(I_rst_n),.pixel_valid(awb_O_tvalid),
 .pixel_sof(awb_pixel_sof),.pixel_last(awb_O_tlast),.early_sof(awb_O_tuser),
 .rgb(awb_O_tdata),.mode(observation_tag[1:0]),.invalidate(sample_cancel),
 .out_valid(view_valid),.out_last(view_last),.out_early_sof(view_early),.out_rgb(view_rgb),
 .out_x(),.out_y(),.core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum));
roi_observation_snapshot #(.CORE_AREA((ROI_X1-ROI_X0)*(ROI_Y1-ROI_Y0))) u_roi_observation_snapshot(
 .clk(axi4s_video_aclk),.rst_n(I_rst_n),.invalidate(sample_cancel),.tag(observation_tag),
 .legacy_record(display_record),.core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),
 .record(observation_record));
wire [10:0] roi_x;'''),
 ('wire sample_cancel=roi_invalidate || !config_ok || |lane_error;', 'wire sample_cancel=roi_invalidate || !config_ok || |lane_error || !observation_match;'),
 ('.lane_error(lane_error),.config_ok(config_ok),','.lane_error(lane_error),.config_ok(config_ok && observation_match),'),
 ('( awb_O_tuser\t    )','( view_early        )'),
 ('( awb_O_tvalid \t\t)','( view_valid        )'),
 ('( awb_O_tdata\t\t)','( view_rgb          )')
])

edit(hdl/'design_top_wrapper.v',[
 ('    input wire [3:0]  I_button,','    input wire [3:0]  I_button,\n    input wire [1:0]  I_switch,'),
 ('wire [27:0] roi_display_record;', '''wire [27:0] roi_display_record;
wire [82:0] observation_record;
wire [17:0] observation_request,observation_receive,observation_display;
observation_controls u_observation_controls(
 .clk(I_sys_clk),.rst_n(S_rst_n),.switches(I_switch),.request(observation_request));
status_cdc #(.WIDTH(18)) u_observation_receive(
 .S_clk(I_sys_clk),.D_clk(S_csi_rx_clk),.rst_n(S_rst_n),
 .S_data(observation_request),.D_data(observation_receive));
status_cdc #(.WIDTH(18)) u_observation_display(
 .S_clk(I_sys_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
 .S_data(observation_request),.D_data(observation_display));'''),
 ('.sample_mean(roi_sample_mean),.sample_min(roi_sample_min),.sample_max(roi_sample_max)', '.sample_mean(roi_sample_mean),.sample_min(roi_sample_min),.sample_max(roi_sample_max),\n.observation_request(observation_receive),.observation_record(observation_record)'),
 ('    wire [27:0] roi_display;\n    status_cdc #(.WIDTH(28)) u_roi_display(', '    wire [82:0] observation_data;\n    wire [27:0] roi_display=observation_data[27:0];\n    wire observation_match=observation_data[45:28]==observation_display;\n    status_cdc #(.WIDTH(83)) u_roi_display('),
 ('.S_data(roi_display_record),.D_data(roi_display));','.S_data(observation_record),.D_data(observation_data));'),
 ('.clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),.cfg_done(cam_display[0]),','.clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),.cfg_done(cam_display[0] && observation_match),'),
 ('.exposure(cam_display[48:33]),.gain(cam_display[32:17]),\n        .roi_valid', '.exposure(cam_display[48:33]),.gain(cam_display[32:17]),\n        .view_mode(observation_display[1:0]),.edge_count(observation_data[58:46]),.edge_sum(observation_data[82:59]),\n        .roi_valid')
])

pin=p/'user_source/constraints_source/pin.adc'
with pin.open('a',encoding='utf-8',newline='\r\n') as f:
    f.write('\n// Physical SW1/SW2; schematic nets SW0/SW1. Up=1, down=0.\n')
    f.write('set_pin_assignment { I_switch[0] } { LOCATION = A4; IOSTANDARD = LVCMOS33; PULLTYPE = NONE; }\n')
    f.write('set_pin_assignment { I_switch[1] } { LOCATION = B4; IOSTANDARD = LVCMOS33; PULLTYPE = NONE; }\n')
sdc=p/'td_project/camera_to_dsi_display.sdc'
with sdc.open('a',encoding='utf-8',newline='\r\n') as f:
    f.write('\n# SW levels feed only the first synchronizer in the independent 50MHz domain.\n')
    f.write('set_false_path -from [get_ports {I_switch[*]}]\n')
    for module,budget in [('u_observation_receive',8.0),('u_observation_display',19.0)]:
        f.write(f'set_max_delay -datapath_only {budget:.1f} -from [get_regs {{{module}/payload*}}] -to [get_regs {{{module}/D_data*}}]\n')
        f.write(f'set_max_delay -datapath_only {budget:.1f} -from [get_regs {{{module}/req}}] -to [get_regs {{{module}/req_sync[0]}}]\n')
        f.write(f'set_max_delay -datapath_only 19.0 -from [get_regs {{{module}/ack}}] -to [get_regs {{{module}/ack_sync[0]}}]\n')

al=p/'td_project/camera_to_dsi_display.al'
names=['observation_controls','roi_sobel_view','roi_observation_snapshot']
fragment=''
for i,name in enumerate(names,112):
    fragment+=f'''            <File Path="../user_source/hdl_source/{name}.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{i}"/>
                </FileInfo>
            </File>
'''
edit(al,[('        <Verilog>\n','        <Verilog>\n'+fragment)])

gen=p/'sim/generate_osd_assets.py'
edit(gen,[
 ("ANLOGICEXPGIMNFRCSTUYDH0123456789ABCDEF-", "ANLOGICEXPGIMNFRCSTUYDHW0123456789ABCDEF-+"),
 ("field(784,44,'档号',kind='cjk')", """field(784,44,'档号',kind='cjk')
field(864,8,'MODE',scale=2,color="24'hb0c0d4")
field(864,40,' '*9,scale=2,dynamic=[f'mode_glyph(mode_s,{i})' for i in range(9)])"""),
 ("field(304,548,' '*len(diag),dynamic=diag)", """field(304,548,' '*len(diag),dynamic=diag)
diag=[];literal('EC ')
diag.extend(f"edge_sample_s ? hexchar(edge_count_s[{(3-i)*4}+:4]) : 7'd45" for i in range(4))
literal(' GS ')
diag.extend(f"edge_sample_s ? hexchar(edge_sum_s[{(5-i)*4}+:4]) : 7'd45" for i in range(6))
literal(' T 80')
field(808,548,' '*len(diag),color="24'hffae64",dynamic=diag)"""),
 (' input wire [15:0] exposure,gain,', ' input wire [15:0] exposure,gain,\n input wire [1:0] view_mode,input wire [12:0] edge_count,input wire [23:0] edge_sum,'),
 ('reg sample_s,cfg_s,error_s;reg [1:0] class_s,reason_s;', 'reg sample_s,cfg_s,error_s,edge_sample_s;reg [1:0] class_s,reason_s,mode_s;\nreg [15:0] edge_count_s;reg [23:0] edge_sum_s;'),
 ('  class_s<=1;reason_s<=0;lane_s<=0;', '  mode_s<=0;edge_sample_s<=0;edge_count_s<=0;edge_sum_s<=0;\n  class_s<=1;reason_s<=0;lane_s<=0;'),
 ('  if(start) begin\n   sample_s', '  if(start) begin\n   mode_s<=view_mode;edge_count_s<={3\'d0,edge_count};edge_sum_s<=edge_sum;\n   edge_sample_s<=roi_valid && cfg_done && fps!=0 && view_mode[1];\n   sample_s'),
 ("base+=glyph_func('result_glyph',state_words,2)+glyph_func('reason_glyph',reasons,2)", """base+=glyph_func('result_glyph',state_words,2)+glyph_func('reason_glyph',reasons,2)
base+='function [6:0] mode_glyph;\\n input [1:0] code;input [3:0] position;\\n begin\\n mode_glyph=7\\'d32;\\n case(code)\\n'
for code,word in enumerate(['RAW','GRAY','EDGE','GRAY+EDGE']):
 base+=f' {code}: case(position)\\n'+''.join(f" {i}: mode_glyph=7'd{ord(ch)};\\n" for i,ch in enumerate(word))+" default: mode_glyph=7'd32;\\n endcase\\n"
base+=' endcase\\n end\\nendfunction\\n'"""),
 (" ENABLE && roi_inside ? (roi_border ? 24'h00ff40 : {gray,gray,gray}) : rgb;", " ENABLE && roi_border ? 24'h00ff40 : rgb;")
])

edit(p/'sim/render_osd_reference.py',[
 ('fill=(102,102,102),outline=(0,255,64)', 'fill=(85,102,119),outline=(0,255,64)'),
 ("text(784,44,'档号',cjk=True)", "text(784,44,'档号',cjk=True)\ntext(864,8,'MODE',2,'muted');text(864,40,'RAW',2)"),
 ("text(304,548,'IN  1024X  600 FPS    30 CFG 1 L 0001 F 0002 I 0003 G 0004 HEX')", "text(304,548,'IN  1024X  600 FPS    30 CFG 1 L 0001 F 0002 I 0003 G 0004 HEX')\ntext(808,548,'EC ---- GS ------ T 80',color='orange')"),
 ("colors={'bg':", "colors={'orange':(255,174,100),'bg':"),
 (" text(304,548,f'IN  1024X  600 FPS {fps:5d} CFG {cfg} L 0001 F 0002 I 0003 G 0004 HEX')", " text(304,548,f'IN  1024X  600 FPS {fps:5d} CFG {cfg} L 0001 F 0002 I 0003 G 0004 HEX')\n text(808,548,'EC ---- GS ------ T 80',color='orange')")
])

tb=p/'sim/tb_osd.v'
s=tb.read_text(encoding='utf-8')
old=' .exposure(ex),.gain(ga),.roi_valid'
assert s.count(old)==2
s=s.replace(old,' .exposure(ex),.gain(ga),.view_mode(2\'d0),.edge_count(13\'d12),.edge_sum(24\'d345),.roi_valid')
tb.write_text(s,encoding='utf-8',newline='\r\n')
edit(p/'sim/tb_roi_chain.v',[
 ('.calibration_ok(1\'b1),.threshold', ".observation_request(18'd1),.observation_record(),\n .calibration_ok(1'b1),.threshold")
])
runner=p/'sim/run_modelsim.ps1'
edit(runner,[
 ('"$hdl/roi_result_snapshot.v",\n        "$hdl/awb.v"', '"$hdl/roi_result_snapshot.v", "$hdl/roi_sobel_view.v", "$hdl/roi_observation_snapshot.v",\n        "$hdl/awb.v"'),
 ('    $tests = @(\n', '''    $tests = @(
        @{Name="sobel_view"; Pass="PASS Sobel view:"; Sources=@("$hdl/roi_sobel_view.v", "$hdl/isp/data96_128/data96_128.v", "tb_sobel_view.v")},
        @{Name="observation"; Pass="PASS observation:"; Sources=@("$hdl/observation_controls.v", "$hdl/roi_observation_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_observation.v")},
''')
])
print('Integrated source view, 83-bit snapshot, SW pins/physical CDC budgets and UI generator; classification unchanged.')
