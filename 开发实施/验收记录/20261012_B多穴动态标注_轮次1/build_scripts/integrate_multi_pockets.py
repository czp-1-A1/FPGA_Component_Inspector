from pathlib import Path
root=Path(__file__).resolve().parent.parent
hdl=root/'fpga/component_inspector/user_source/hdl_source'
def edit(path,fn):
    s=path.read_text(encoding='utf-8-sig');path.write_text(fn(s),encoding='utf-8')
def sobel(s):
    s=s.replace('output wire [31:0] timing_debug,','output wire [31:0] timing_debug,\n output wire gradient_valid,output wire [10:0] gradient_x,output wire [9:0] gradient_y,\n output wire [43:0] gradient_magnitudes,output wire [3:0] gradient_neighborhood,')
    s=s.replace('wire [3:0] selected=core4 & neighborhood4;', '''// Passive feature tap; the existing row replay and video schedule are unchanged.
assign gradient_valid=v4 && mode4[1] && !early_sof && !frame_bad && !cache_overrun;
assign gradient_x=x4;assign gradient_y=y4;assign gradient_neighborhood=neighborhood4;
assign gradient_magnitudes={magnitude[3],magnitude[2],magnitude[1],magnitude[0]};
wire [3:0] selected=core4 & neighborhood4;''')
    return s
edit(hdl/'roi_sobel_view.v',sobel)
def isp(s):
    s=s.replace('parameter HOLE_Y=220,LATE_HOLE=0','parameter HOLE_Y=220,LATE_HOLE=0,MULTI_POCKETS=0,\n    parameter META_WIDTH=178+340*MULTI_POCKETS')
    s=s.replace('output reg [177:0] frame_metadata','output reg [META_WIDTH-1:0] frame_metadata')
    s=s.replace('wire [23:0] edge_sum;', '''wire [23:0] edge_sum;
wire gradient_valid;wire [10:0] gradient_x;wire [9:0] gradient_y;
wire [43:0] gradient_magnitudes;wire [3:0] gradient_neighborhood;
wire [339:0] pocket_records;wire multi_new;
wire [43:0] pocket_x0;wire [39:0] pocket_y0;wire [3:0] pocket_mask,pocket_verified;
wire legacy_valid,legacy_new;wire [7:0] legacy_mean,legacy_min,legacy_max;wire [1:0] legacy_class;''')
    s=s.replace('roi_sobel_view #(.DYNAMIC_ROI(TRACKING),','roi_sobel_view #(.X0(MULTI_POCKETS ? 96 : 256),.X1(MULTI_POCKETS ? 928 : 768),.DYNAMIC_ROI(TRACKING),')
    s=s.replace('.out_x(),.out_y(),.core_pixels', '.gradient_valid(gradient_valid),.gradient_x(gradient_x),.gradient_y(gradient_y),\n .gradient_magnitudes(gradient_magnitudes),.gradient_neighborhood(gradient_neighborhood),\n .out_x(),.out_y(),.core_pixels')
    s=s.replace('localparam RESULT_ROW=(HOLE_Y','localparam RESULT_ROW=MULTI_POCKETS ? 456 : (HOLE_Y')
    s=s.replace('generate if(TRACKING) begin : tracking','''generate if(MULTI_POCKETS) begin : multi_tracking
 multi_pocket_tracker tracker(
  .clk(axi4s_video_aclk),.rst_n(I_rst_n),.frame_start(raw_start),.pixel_sof(awb_pixel_sof),
  .accept(roi_accept),.frame_commit(roi_commit),.invalidate(sample_cancel),.x(roi_x),.y(roi_y),.rgb(awb_O_tdata),
  .sample_x0(pocket_x0),.sample_y0(pocket_y0),.sample_mask(pocket_mask),.verified_mask(pocket_verified),.located(),.diagnostic(track_diagnostic));
 assign track_x0=pocket_x0[10:0];assign track_x1=pocket_x0[10:0]+11'd80;
 assign track_y0=pocket_y0[9:0];assign track_y1=pocket_y0[9:0]+10'd80;assign track_locked=|pocket_verified;
 multi_pocket_statistics statistics(
  .clk(axi4s_video_aclk),.rst_n(I_rst_n),.frame_start(raw_start),.pixel_sof(awb_pixel_sof),.accept(roi_accept),
  .commit(result_commit),.invalidate(sample_cancel),.x(roi_x),.y(roi_y),.rgb(awb_O_tdata),
  .x0(pocket_x0),.y0(pocket_y0),.sample_mask(pocket_mask),.verified_mask(pocket_verified),
  .edge_valid(gradient_valid),.edge_x(gradient_x),.edge_y(gradient_y),.magnitudes(gradient_magnitudes),.edge_neighborhood(gradient_neighborhood),
  .mode(observation_tag[1:0]),.calibration_ok(calibration_ok),.present_high(present_high),.threshold(threshold),
  .records(pocket_records),.sample_new(multi_new));
end else begin : legacy_geometry
 assign pocket_records=0;assign multi_new=0;assign pocket_x0=0;assign pocket_y0=0;assign pocket_mask=0;assign pocket_verified=0;
 if(TRACKING) begin : tracking''')
    s=s.replace('end endgenerate\n// The result settles','end\nend endgenerate\n// The result settles')
    s=s.replace('reg [5:0] metadata_wait','reg [7:0] metadata_wait')
    s=s.replace('metadata_wait<=48','metadata_wait<=MULTI_POCKETS ? 192 : 48')
    s=s.replace('frame_metadata<={track_diagnostic,frame_config,track_locked,track_x0,track_x1,observation_record};','''if(MULTI_POCKETS) frame_metadata<={pocket_records,track_diagnostic,frame_config,track_locked,track_x0,track_x1,observation_record};
   else frame_metadata<={track_diagnostic,frame_config,track_locked,track_x0,track_x1,observation_record};''')
    # Keep legacy instances at their existing hierarchy; synthesis removes unused banks in AUTO4.
    s=s.replace('.sample_valid(result_valid),\n    .mean(sample_mean),.minimum(sample_min),.maximum(sample_max),.sample_pixels(),.sample_sum(),.sample_new(sample_new)', '.sample_valid(legacy_valid),\n    .mean(legacy_mean),.minimum(legacy_min),.maximum(legacy_max),.sample_pixels(),.sample_sum(),.sample_new(legacy_new)')
    s=s.replace('.sample_valid(result_valid),.sample_new(sample_new),\n    .mean(sample_mean),.threshold', '.sample_valid(legacy_valid),.sample_new(legacy_new),\n    .mean(legacy_mean),.threshold')
    s=s.replace('.edge_sum(edge_sum),.state(result_class));','.edge_sum(edge_sum),.state(legacy_class));')
    s=s.replace('roi_result_snapshot u_roi_result_snapshot(','''assign result_valid=MULTI_POCKETS ? pocket_records[63] : legacy_valid;
assign sample_new=MULTI_POCKETS ? multi_new : legacy_new;
assign sample_mean=MULTI_POCKETS ? pocket_records[60:53] : legacy_mean;
assign sample_min=MULTI_POCKETS ? pocket_records[52:45] : legacy_min;
assign sample_max=MULTI_POCKETS ? pocket_records[44:37] : legacy_max;
assign result_class=MULTI_POCKETS ? pocket_records[62:61] : legacy_class;
roi_result_snapshot u_roi_result_snapshot(''')
    return s
edit(hdl/'isp/isp_top.v',isp)
def top(s):
    s=s.replace('parameter ENABLE_TRACKING=1','parameter ENABLE_TRACKING=1,ENABLE_MULTI_POCKETS=1')
    s=s.replace('wire [177:0] camera_metadata,completed_metadata,active_metadata;', '''localparam MULTI_POCKETS=ENABLE_TRACKING && ENABLE_MULTI_POCKETS;
localparam FRAME_META_WIDTH=178+340*MULTI_POCKETS;
wire [FRAME_META_WIDTH-1:0] camera_metadata,completed_metadata,active_metadata;''')
    s=s.replace('isp_top #(.TRACKING(ENABLE_TRACKING),','isp_top #(.MULTI_POCKETS(MULTI_POCKETS),.TRACKING(ENABLE_TRACKING),')
    s=s.replace('.META_WIDTH(178)', '.META_WIDTH(FRAME_META_WIDTH)')
    s=s.replace('wire [180:0] active_frame_display;', 'wire [FRAME_META_WIDTH+2:0] active_frame_display;')
    s=s.replace('.WIDTH(181)', '.WIDTH(FRAME_META_WIDTH+3)')
    s=s.replace('active_frame_display[180]', 'active_frame_display[FRAME_META_WIDTH+2]')
    s=s.replace('active_frame_display[179:178]', 'active_frame_display[FRAME_META_WIDTH+1:FRAME_META_WIDTH]')
    s=s.replace('experiment_osd #(.TRACKING(ENABLE_TRACKING),', '''wire pocket_overlay_ok=tracking_fresh && cam_display[0] && mon_display[127:112]!=0 && transport_ok && tracking_match && observation_match;
    wire [339:0] display_pockets;
    generate if(MULTI_POCKETS) begin : multi_display
     assign display_pockets=active_frame_display[178+:340];
    end else begin : single_display
     assign display_pockets=0;
    end endgenerate
    wire any_pocket_valid=display_pockets[63] || display_pockets[148] || display_pockets[233] || display_pockets[318];
    experiment_osd #(.MULTI_POCKETS(MULTI_POCKETS),.TRACKING(ENABLE_TRACKING),''')
    s=s.replace('.track_valid(roi_display_valid && active_frame_display[137]),', '.pocket_records(display_pockets),.pocket_enable(pocket_overlay_ok),\n        .track_valid(MULTI_POCKETS ? (pocket_overlay_ok && any_pocket_valid) : (roi_display_valid && active_frame_display[137])),')
    return s
edit(hdl/'design_top_wrapper.v',top)
def osd(s):
    s=s.replace('parameter TRACKING=0,ENABLE=1','parameter TRACKING=0,MULTI_POCKETS=0,ENABLE=1')
    s=s.replace('input wire track_valid,', 'input wire [339:0] pocket_records,input wire pocket_enable,\n input wire track_valid,')
    s=s.replace('reg vs_d,de_d;', 'reg [339:0] pockets_s;reg pockets_enabled_s;\nreg vs_d,de_d;')
    s=s.replace('if(!rst_n) begin\n  track_valid_s', 'if(!rst_n) begin\n  pockets_s<=0;pockets_enabled_s<=0;\n  track_valid_s')
    s=s.replace('if(start) begin\n   track_valid_s','if(start) begin\n   pockets_s<=pocket_records;pockets_enabled_s<=pocket_enable;\n   track_valid_s')
    # One font port multiplexes the four labels. Records stay immutable for this raster.
    idx=s.index('wire [10:0] sample_x0=')
    # definitions can be later in Verilog; insert before glyph combinational block instead for clarity
    marker='reg [6:0] glyph;'
    assert marker in s
    s=s.replace(marker,'''reg pocket_border,pocket_label;reg [23:0] pocket_color;
reg [1:0] pocket_state;reg [10:0] pocket_label_x;reg [9:0] pocket_label_y;
integer pi;reg [10:0] px;reg [9:0] py;reg [1:0] ps;
always @* begin
 pocket_border=0;pocket_label=0;pocket_color=24'hffff00;pocket_state=1;pocket_label_x=0;pocket_label_y=0;px=0;py=0;ps=0;
 for(pi=0;pi<4;pi=pi+1) begin
  px=pockets_s[pi*85+74+:11];py=pockets_s[pi*85+64+:10];ps=pockets_s[pi*85+61+:2];
  if(MULTI_POCKETS && pockets_enabled_s && pockets_s[pi*85+63]) begin
   if((x>=px && x<px+80 && y>=py && y<py+80 && (x==px || x==px+79 || y==py || y==py+79)) ||
      (x>=px && x<px+72 && y>=py-26 && y<py-2)) begin
    pocket_color=ps==2 ? 24'h74dbc7 : ps==3 ? 24'hffae64 : 24'hffff00;
    if(y>=py) pocket_border=1;
    else begin pocket_label=1;pocket_state=ps;pocket_label_x=px;pocket_label_y=py-26;end
   end
  end
 end
end
reg [6:0] glyph;''')
    marker='end\nwire roi_inside='
    assert marker in s
    s=s.replace(marker,''' if(MULTI_POCKETS && y>=8 && y<24 && x>=128 && x<232) begin
  glyph_cjk=0;glyph_row=y-8;glyph_col=(x-128)%8;
  case((x-128)/8)
   0:glyph="A";1:glyph="U";2:glyph="T";3:glyph="O";4:glyph="4";5:glyph=" ";
   6:glyph="E";7:glyph="X";8:glyph="P";9:glyph=" ";10:glyph="V";11:glyph="1";default:glyph=" ";
  endcase
 end
 if(pocket_label) begin
  glyph_cjk=1;glyph_row=y-pocket_label_y;glyph_col=(x-pocket_label_x)%24;
  glyph=result_glyph(pocket_state,(x-pocket_label_x)/24);ink_color=pocket_color;
 end
end
wire roi_inside=''')
    s=s.replace("wire [23:0] picture=ENABLE && sample_border ? 24'h00ffff :", "wire [23:0] picture=MULTI_POCKETS ? (ENABLE && pocket_border ? pocket_color : rgb) :\n ENABLE && sample_border ? 24'h00ffff :")
    s=s.replace('(de && (y<80 || y>=504 ||', '(de && (pocket_label || y<80 || y>=504 ||')
    return s
edit(hdl/'experiment_osd.v',osd)
al=root/'fpga/component_inspector/td_project/camera_to_dsi_display.al'
def project(s):
    marker='            <File Path="../user_source/hdl_source/tape_hole_tracker.v">'
    assert marker in s
    s=s.replace(marker,'''            <File Path="../user_source/hdl_source/multi_pocket_detector.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="120"/>
                </FileInfo>
            </File>
'''+marker)
    return s
edit(al,project)
print('Integrated AUTO4 tracker, shared gradient, 518-bit frame metadata, independent OSD labels')
