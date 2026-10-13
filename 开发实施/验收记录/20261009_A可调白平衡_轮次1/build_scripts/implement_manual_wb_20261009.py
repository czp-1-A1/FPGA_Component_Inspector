from pathlib import Path

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
hdl = project / 'user_source/hdl_source'

def patch(p, old, new):
    raw = p.read_bytes()
    old = old.encode('ascii')
    nl = b'\r\n' if raw.count(b'\r\n') * 2 > raw.count(b'\n') else b'\n'
    if b'\n' in old:
        if raw.count(old) == 1: nl = b'\n'
        else: old = old.replace(b'\n', b'\r\n'); nl = b'\r\n'
    new = new.encode('ascii').replace(b'\n', nl)
    assert raw.count(old) == 1, (p.name, old[:80], raw.count(old))
    p.write_bytes(raw.replace(old, new))

p = hdl / 'uiisp_beta/ae_set.v'
patch(p, '    parameter integer REPEAT_MS = 60', '    parameter integer REPEAT_MS = 60,\n    parameter integer WB_HOLD_MS = 1000')
patch(p, '    output reg [15:0] O_ae, O_ag', '    output reg [15:0] O_ae, O_ag,\n    output reg O_wb_tune,\n    output reg [31:0] O_wb_request')
patch(p, 'reg [1:0] request_state;', '''reg [1:0] request_state;
// Q2.6: code 64 = 1.0; 32..192 = 0.5..3.0, step 1/64.
// The epoch also distinguishes a quick change away and back while CSI is stopped.
reg [9:0] chord_count;
reg chord_used,chord_fired;
reg [1:0] click_pending;
wire chord_down = &btn_sync[1:0];
wire keys_allowed = !chord_down && !chord_used;
wire r_down = event_key[0] && !btn_sync[1] && O_wb_request[15:8]>32;
wire r_up = event_key[1] && !btn_sync[0] && O_wb_request[15:8]<192;
wire b_down = event_key[2] && !btn_sync[3] && O_wb_request[7:0]>32;
wire b_up = event_key[3] && !btn_sync[2] && O_wb_request[7:0]<192;
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin
        O_wb_tune<=0;O_wb_request<=32'h00004040;
        chord_count<=0;chord_used<=0;chord_fired<=0;
    end else begin
        if(chord_down) chord_used<=1;
        else if(btn_sync==0 && pressed==0) begin chord_used<=0;chord_fired<=0;end
        if(ms_tick) begin
            if(chord_down && &pressed[1:0] && !chord_fired) begin
                if(chord_count==WB_HOLD_MS-1) begin
                    O_wb_tune<=!O_wb_tune;chord_fired<=1;chord_count<=0;
                end else chord_count<=chord_count+1'b1;
            end else chord_count<=0;
        end
        if(O_wb_tune && keys_allowed) begin
            if(r_down) O_wb_request[15:8]<=O_wb_request[15:8]-1'b1;
            else if(r_up) O_wb_request[15:8]<=O_wb_request[15:8]+1'b1;
            if(b_down) O_wb_request[7:0]<=O_wb_request[7:0]-1'b1;
            else if(b_up) O_wb_request[7:0]<=O_wb_request[7:0]+1'b1;
            if(r_down || r_up || b_down || b_up)
                O_wb_request[31:16]<=O_wb_request[31:16]+1'b1;
        end
    end
end''')
patch(p, '        btn_meta<=0; btn_sync<=0; pressed<=0; event_key<=0; ms_count<=0;', '        btn_meta<=0; btn_sync<=0; pressed<=0; event_key<=0; ms_count<=0;click_pending<=0;')
patch(p, '                        hold_count[k]<=0; event_key[k]<=btn_sync[k];', '''                        hold_count[k]<=0;
                        // KEY1/2 clicks act on release; a chord cannot cause an
                        // initial exposure step, even with staggered debounce.
                        if(k<2) begin
                            if(btn_sync[k]) click_pending[k]<=1;
                            else begin
                                event_key[k]<=click_pending[k] && keys_allowed;
                                click_pending[k]<=0;
                            end
                        end else event_key[k]<=btn_sync[k];''')
patch(p, '                            event_key[k]<=1; hold_count[k]<=HOLD_MS-REPEAT_MS;', '                            event_key[k]<=1; hold_count[k]<=HOLD_MS-REPEAT_MS;\n                            if(k<2) click_pending[k]<=0;')
patch(p, '        btn_meta<=~I_btn; btn_sync<=btn_meta; event_key<=0;', '        btn_meta<=~I_btn; btn_sync<=btn_meta; event_key<=0;\n        if(chord_down || chord_used) click_pending<=0;')
patch(p, '    else begin\n        if(event_key[0] && !btn_sync[1])', '    else if(!O_wb_tune && keys_allowed) begin\n        if(event_key[0] && !btn_sync[1])')

p = hdl / 'awb.v'
patch(p, '    parameter FIXED_GAIN = 0,', '    parameter FIXED_GAIN = 0,\n    parameter MANUAL_GAIN = 0,')
patch(p, '    input                   O_tready\n', '    input                   O_tready,\n    input [31:0]            I_wb_request,\n    output [31:0]           O_wb_active\n')
patch(p, '        if(FIXED_GAIN)begin : fixed_gain', '''        if(MANUAL_GAIN)begin : manual_gain
            reg [31:0] pending,active;
            wire first_pixel = I_tuser_r1 && valid_d1;
            // Snapshot at AWB early SOF, apply at the first multiplication.
            // First-beat bypass avoids one pixel group using the old gains.
            wire [31:0] color_gain = first_pixel ? pending : active;
            assign in_r_r1 = {2'd0,color_gain[15:8],10'd0};
            assign in_b_r1 = {2'd0,color_gain[7:0],10'd0};
            assign O_wb_active = active;
            always @(posedge I_clk or negedge I_rst_n)begin
                if(!I_rst_n)begin pending<=32'h00004040;active<=32'h00004040;end
                else begin
                    if(I_tuser) pending<=I_wb_request;
                    if(first_pixel) active<=pending;
                end
            end
        end
        else if(FIXED_GAIN)begin : fixed_gain''')
patch(p, '            assign in_b_r1 = FIXED_B_GAIN;', '            assign in_b_r1 = FIXED_B_GAIN;\n            assign O_wb_active = 32\'h00004040;')
patch(p, '            assign in_b_r1 = blue_gain;', '            assign in_b_r1 = blue_gain;\n            assign O_wb_active = 32\'h00004040;')

p = hdl / 'isp/isp_top.v'
patch(p, '    output [82:0] observation_record,', '    input [31:0] wb_request,output [31:0] wb_active,\n    output [114:0] observation_record,')
patch(p, 'awb #(\n', '''reg [31:0] wb_frame_request;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
 if(!I_rst_n) wb_frame_request<=32'h00004040;
 else if(raw_start) wb_frame_request<=wb_request;
end
wire wb_match=wb_frame_request==wb_request || raw_start;
awb #(
''')
patch(p, '    .FIXED_GAIN(1) // Unity-gain imaging trial; optical thresholds need remeasurement.', '    .MANUAL_GAIN(1) // Frame-held Q2.6 red/blue gains; green remains unity.')
patch(p, '    .O_tready(awb_O_tready)\n', '    .O_tready(awb_O_tready),\n    .I_wb_request(wb_frame_request),.O_wb_active(wb_active)\n')
patch(p, ' .clk(axi4s_video_aclk),.rst_n(I_rst_n),.invalidate(sample_cancel),.tag(observation_tag),', ' .clk(axi4s_video_aclk),.rst_n(I_rst_n),.invalidate(sample_cancel),.tag(observation_tag),.wb_tag(wb_frame_request),')
patch(p, 'assign sample_cancel=roi_invalidate || !config_ok || |lane_error || !observation_match;', 'assign sample_cancel=roi_invalidate || !config_ok || |lane_error || !observation_match || !wb_match;')

p = hdl / 'roi_observation_snapshot.v'
patch(p, ' input wire clk,rst_n,invalidate,input wire [17:0] tag,', ' input wire clk,rst_n,invalidate,input wire [17:0] tag,input wire [31:0] wb_tag,')
patch(p, ' input wire [23:0] edge_sum,output reg [82:0] record', ' input wire [23:0] edge_sum,output reg [114:0] record')
patch(p, '  record<={edge_sum,edge_count,tag,legacy_record[27:25],(!tag[1] || core_pixels==CORE_AREA),legacy_record[23:0]};', '  record<={wb_tag,edge_sum,edge_count,tag,legacy_record[27:25],(!tag[1] || core_pixels==CORE_AREA),legacy_record[23:0]};')
patch(p, '// Bits: [82:59] G sum,', '// Bits: [114:83] WB epoch/red/blue, [82:59] G sum,')

p = hdl / 'roi_display_state.v'
patch(p, ' input wire calibration_ok,input wire [27:0] record,input wire [17:0] observation_request,', ' input wire calibration_ok,input wire [27:0] record,input wire [17:0] observation_request,\n input wire [31:0] wb_request,')
patch(p, 'reg [17:0] observation_d;', 'reg [17:0] observation_d;reg [31:0] wb_d;')
patch(p, 'wire changed=exposure!=exposure_d || gain!=gain_d || observation_request!=observation_d;', 'wire changed=exposure!=exposure_d || gain!=gain_d || observation_request!=observation_d || wb_request!=wb_d;')
patch(p, 'observation_d<=0;token<=0;', 'observation_d<=0;wb_d<=0;token<=0;')
patch(p, 'observation_d<=observation_request;', 'observation_d<=observation_request;wb_d<=wb_request;')

p = hdl / 'design_top_wrapper.v'
patch(p, '  ae_set u_ae_set (', '  wire wb_tune;\n  wire [31:0] wb_request,wb_active;\n  ae_set u_ae_set (')
patch(p, '      .O_ag(S_ag)\n', '      .O_ag(S_ag),.O_wb_tune(wb_tune),.O_wb_request(wb_request)\n')
patch(p, 'wire [82:0] observation_record;', 'wire [114:0] observation_record;')
patch(p, 'wire [48:0] camera_receive;', 'wire [80:0] camera_receive;')
patch(p, 'status_cdc #(.WIDTH(49)) u_camera_receive(', 'status_cdc #(.WIDTH(81)) u_camera_receive(')
patch(p, '    wire [48:0] cam_display;', '    wire [81:0] cam_display;')
patch(p, 'status_cdc #(.WIDTH(49)) u_camera_display(', 'status_cdc #(.WIDTH(82)) u_camera_display(')
# Each held camera payload retains the existing low 49 camera bits.
raw = p.read_bytes()
old = b'.S_data({S_ae,S_ag,S_i2c_errors,(S_cam_cfg_done && S_ae_cfg_done && !S_ae_req)})'
assert raw.count(old)==2
raw = raw.replace(old, b'.S_data({wb_request,S_ae,S_ag,S_i2c_errors,(S_cam_cfg_done && S_ae_cfg_done && !S_ae_req)})', 1)
raw = raw.replace(old, b'.S_data({wb_tune,wb_request,S_ae,S_ag,S_i2c_errors,(S_cam_cfg_done && S_ae_cfg_done && !S_ae_req)})', 1)
p.write_bytes(raw)
patch(p, '.observation_request(observation_receive),.observation_record(observation_record)', '.observation_request(observation_receive),.observation_record(observation_record),\n.wb_request(camera_receive[80:49]),.wb_active(wb_active)')
patch(p, '    wire [82:0] observation_data;', '    wire [114:0] observation_data;')
patch(p, 'wire observation_match=observation_data[45:28]==observation_display;', 'wire observation_match=observation_data[45:28]==observation_display && observation_data[114:83]==cam_display[80:49];')
patch(p, 'status_cdc #(.WIDTH(83)) u_roi_display(', 'status_cdc #(.WIDTH(115)) u_roi_display(')
patch(p, '    wire [51:0] overflow_display;', '    wire [83:0] overflow_display;')
patch(p, 'status_cdc #(.WIDTH(52)) u_overflow_display(', 'status_cdc #(.WIDTH(84)) u_overflow_display(')
patch(p, '.S_data({video_diagnostics,overflow_frames})', '.S_data({wb_active,video_diagnostics,overflow_frames})')
patch(p, '.record(roi_display),.observation_request(observation_display),.sample_valid(roi_display_valid),', '.record(roi_display),.observation_request(observation_display),.wb_request(cam_display[80:49]),.sample_valid(roi_display_valid),')
patch(p, '        .diagnostics(overflow_display[51:16]),', '''        .diagnostics(overflow_display[51:16]),
        .wb_r(overflow_display[67:60]),.wb_b(overflow_display[59:52]),.wb_tune(cam_display[81]),
        .wb_pending(overflow_display[83:52]!=cam_display[80:49]),''')
print('PASS manual WB RTL patch: controls, frame-held colors, coherent sample tags and existing held CDC paths')
