from pathlib import Path
r=Path.cwd();p=r/'fpga/component_inspector';f=p/'user_source/hdl_source/isp/isp_top.v';t=f.read_text()
t=t.replace('parameter TRACKING=0,','parameter ASYNC_PROCESSING=0,TRACKING=0,',1)
t=t.replace('    input \t\t\taxi4s_video_aclk,','    input processing_clk,\n    input \t\t\taxi4s_video_aclk,',1)
# Native capture and proof remain on the original recovered clock.
start=t.index('roi_frame_guard u_roi_guard(');end=t.index('// Tracking coordinates',start)
guard=t[start:end];t=t[:start]+t[end:]
start=t.index('roi_sobel_view #(')
block='''// Native packet proof is never inferred from FIFO output or pixel count alone.
'''+guard+'''wire native_cancel=roi_invalidate || !config_ok || |lane_error || !observation_match || !wb_match;
wire [3:0] native_video_fault={(roi_invalidate && !raw_start),(|lane_error),!config_ok,1'b0};
wire post_clk=ASYNC_PROCESSING ? processing_clk : axi4s_video_aclk;
wire post_start,post_early,post_valid,post_sof,post_last,post_accept,post_commit,post_cancel,post_overflow;
wire [95:0] post_rgb;wire [3:0] post_native_fault;
wire [10:0] post_x;wire [9:0] post_y;
wire [17:0] post_tag;wire [31:0] post_wb,post_config;
generate if(ASYNC_PROCESSING)begin : continuous_processing
 reg cancel_d;reg [3:0] fault_d;
 always @(posedge axi4s_video_aclk or negedge I_rst_n)begin
  if(!I_rst_n)begin cancel_d<=0;fault_d<=0;end
  else begin cancel_d<=native_cancel;fault_d<=native_video_fault;end
 end
 wire [127:0] received;wire received_valid;
 wire send_event=raw_start || (awb_O_tuser && !frame_input_closed) || source_pixel_valid || roi_commit ||
  native_cancel!=cancel_d || native_video_fault!=fault_d;
 wire [115:0] payload=raw_start ? {33'd0,image_config,wb_request,observation_request,config_ok} : {20'd0,awb_O_tdata};
 frame_process_bridge bridge(.source_clk(axi4s_video_aclk),.process_clk(processing_clk),.rst_n(I_rst_n),
  .source_data({raw_start,(awb_O_tuser && !frame_input_closed),source_pixel_valid,source_pixel_sof,awb_O_tlast,
   roi_accept,roi_commit,native_cancel,native_video_fault,payload}),.source_valid(send_event),
  .process_data(received),.process_valid(received_valid),.process_overflow(post_overflow));
 assign {post_start,post_early,post_valid,post_sof,post_last,post_accept,post_commit,post_cancel,post_native_fault}=
  received_valid ? received[127:116] : 12'd0;
 assign post_rgb=received[95:0];
 reg [17:0] tag;reg [31:0] wb,cfg;
 reg [10:0] x;reg [9:0] y;
 always @(posedge processing_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin tag<=0;wb<=32'h00006464;cfg<=0;x<=0;y<=0;end
  else begin
   if(post_start)begin tag<=received[18:1];wb<=received[50:19];cfg<=received[82:51];x<=0;y<=0;end
   if(post_sof && post_valid)begin x<=4;y<=0;end
   else if(post_valid)begin
    if(post_last)begin x<=0;y<=y+1'b1;end else x<=x+11'd4;
   end
  end
 end
 assign post_x=post_sof ? 11'd0 : x;assign post_y=post_sof ? 10'd0 : y;
 assign post_tag=tag;assign post_wb=wb;assign post_config=cfg;
end else begin : native_processing
 assign post_start=raw_start;assign post_early=awb_O_tuser && !frame_input_closed;
 assign post_valid=source_pixel_valid;assign post_sof=source_pixel_sof;assign post_last=awb_O_tlast;
 assign post_accept=roi_accept;assign post_commit=roi_commit;assign post_cancel=native_cancel;assign post_overflow=0;
 assign post_rgb=awb_O_tdata;assign post_native_fault=native_video_fault;
 assign post_x=roi_x;assign post_y=roi_y;assign post_tag=observation_tag;assign post_wb=wb_frame_request;assign post_config=image_config;
end endgenerate
'''
t=t[:start]+block+t[start:]
# Guard coordinates must be declared before the new bridge/guard block.
t=t.replace('wire roi_accept,roi_commit,roi_invalidate,sample_new;','wire roi_accept,roi_commit,roi_invalidate,sample_new;\nwire [10:0] roi_x;wire [9:0] roi_y;',1)
t=t.replace('wire [10:0] roi_x;\nwire [9:0] roi_y;\n','',1)
# Everything after the bridge is a single, continuous processing domain.
a=t.index('roi_sobel_view #(');head=t[:a];tail=t[a:]
for old,new in [('axi4s_video_aclk','post_clk'),('raw_start','post_start'),('source_pixel_valid','post_valid'),('source_pixel_sof','post_sof'),('awb_O_tlast','post_last'),('awb_O_tdata','post_rgb'),('roi_accept','post_accept'),('roi_commit','post_commit'),('roi_x','post_x'),('roi_y','post_y'),('observation_tag','post_tag'),('wb_frame_request','post_wb'),('image_config','post_config')]:
 import re
 # Preserve named instance ports; replace expressions/identifiers only.
 tail=re.sub(r'(?<!\.)\b'+old+r'\b',new,tail)
tail=tail.replace('awb_O_tuser && !frame_input_closed','post_early')
tail=tail.replace('assign sample_cancel=roi_invalidate || !config_ok || |lane_error || !observation_match || !wb_match;','assign sample_cancel=post_cancel || post_overflow;')
tail=tail.replace('wire [3:0] video_fault={(roi_invalidate && !post_start),(|lane_error),!config_ok,view_frame_bad};','wire [3:0] video_fault=post_native_fault | {3\'d0,(view_frame_bad || post_overflow)};')
t=head+tail;f.write_text(t)
# The wrapper uses the existing continuous 100MHz PLL output. Frontend stays CSI.
f=p/'user_source/hdl_source/design_top_wrapper.v';t=f.read_text()
t=t.replace('localparam LOCAL_SEARCH=ENABLE_LOCAL_SEARCH && ENABLE_SHAPE_MODEL && !ENABLE_TRACKING && !MULTI_POCKETS;','localparam LOCAL_SEARCH=ENABLE_LOCAL_SEARCH && ENABLE_SHAPE_MODEL && !ENABLE_TRACKING && !MULTI_POCKETS;\nwire S_process_clk=LOCAL_SEARCH ? S_100m_clk : S_csi_rx_clk;')
t=t.replace('isp_top #(.LOCAL_SEARCH(LOCAL_SEARCH),','isp_top #(.ASYNC_PROCESSING(LOCAL_SEARCH),.LOCAL_SEARCH(LOCAL_SEARCH),',1)
t=t.replace('.axi4s_video_aclk(S_csi_rx_clk),','.processing_clk(S_process_clk),\n.axi4s_video_aclk(S_csi_rx_clk),',1)
t=t.replace('.I_camera_clk         ( S_csi_rx_clk          ),','.I_camera_clk         ( S_process_clk         ),',1)
# Payload WB is frame-held native data; synchronize it with post-clock diagnostics.
t=t.replace('wire [83:0] overflow_display;','wire [83:0] overflow_display;\n    wire [31:0] wb_process;\n    status_cdc #(.WIDTH(32)) u_wb_process(\n     .S_clk(S_csi_rx_clk),.D_clk(S_process_clk),.rst_n(S_rst_n),.S_data(wb_active),.D_data(wb_process));')
t=t.replace('.S_clk(S_csi_rx_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),\n        .S_data(observation_record)', '.S_clk(S_process_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),\n        .S_data(observation_record)')
t=t.replace('.S_clk(S_csi_rx_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),\n     .S_data({wb_active,video_diagnostics,overflow_frames})','.S_clk(S_process_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),\n     .S_data({wb_process,video_diagnostics,overflow_frames})')
# Debug seen flags are local to the ISP output clock.
t=t.replace('always @(posedge S_csi_rx_clk or negedge S_rst_n) begin\n        if(!S_rst_n)\n            S_dbg_isp_seen','always @(posedge S_process_clk or negedge S_rst_n) begin\n        if(!S_rst_n)\n            S_dbg_isp_seen')
for n in ['S_dbg_isp_fs_seen','S_dbg_isp_valid_seen']:
 t=t.replace('always @(posedge S_csi_rx_clk or negedge S_rst_n) begin\n        if(!S_rst_n)\n            '+n,'always @(posedge S_process_clk or negedge S_rst_n) begin\n        if(!S_rst_n)\n            '+n)
f.write_text(t)
# Add the FIFO bridge to project and simulation compilation, without new IP.
f=p/'td_project/camera_to_dsi_display.al';t=f.read_text();line=next(l for l in t.splitlines() if 'frame_shape_search.v' in l);t=t.replace(line,line.replace('frame_shape_search','frame_process_bridge')+'\n'+line);f.write_text(t)
f=p/'sim/run_modelsim.ps1';t=f.read_text().replace('"$hdl/frame_shape_search.v", "$hdl/roi_shape_search.v"','"$hdl/frame_process_bridge.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "$hdl/frame_shape_search.v", "$hdl/roi_shape_search.v"',1);f.write_text(t)
print('Installed continuous post-AWB processing bridge')
