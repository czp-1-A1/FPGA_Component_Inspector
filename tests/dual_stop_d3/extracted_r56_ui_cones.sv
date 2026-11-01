module extracted_r56_ui_cones #(parameter ESSENTIAL_UI=1,PUBLISH_BITS=27)(
 input wire S_process_clk,S_hdmi_pixel_clk,I_sys_clk,S_csi_rx_clk,S_ddr_clk,S_rst_n,
 input wire motor_output,input wire [2:0] relay_mode,input wire [191:0] relay_diagnostic,input wire [127:0] relay_status,
 input wire [15:0] mon_width,mon_height,mon_fps,mon_lane,mon_format,mon_gap,
 input wire [31:0] mon_frames,mon_seconds,wb_active,input wire [35:0] video_diagnostics,
 input wire [15:0] overflow_frames,lost_frames,input wire capture_ok,input wire [PUBLISH_BITS-1:0] publish_diagnostic
);
 wire [127:0] relay_display_status;wire [191:0] relay_display_diagnostic;
 wire [2:0] relay_display_mode;wire relay_display_motor;wire [159:0] mon_display;
 wire [16:0] transport_display;wire [PUBLISH_BITS-1:0] publish_display;
// R56 relay display cone begin: keep original SDC instance binding.
localparam RELAY_UI_BITS=ESSENTIAL_UI ? 12 : 324;
wire [RELAY_UI_BITS-1:0] relay_ui_snapshot;
wire [323:0] relay_ui_source=ESSENTIAL_UI ?
 {312'd0,motor_output,relay_mode,relay_status[92:89],relay_status[28:25]} :
 {motor_output,relay_mode,relay_diagnostic,relay_status};
status_cdc #(.WIDTH(RELAY_UI_BITS)) u_relay_display(
 .S_clk(S_process_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
 .S_data(relay_ui_source[RELAY_UI_BITS-1:0]),.D_data(relay_ui_snapshot));
generate if(ESSENTIAL_UI)begin : essential_relay_ui
 assign relay_display_motor=relay_ui_snapshot[11];
 assign relay_display_mode=relay_ui_snapshot[10:8];
 assign relay_display_status={35'd0,relay_ui_snapshot[7:4],25'd0,35'd0,relay_ui_snapshot[3:0],25'd0};
 assign relay_display_diagnostic=0;
end else begin : legacy_relay_ui
 assign {relay_display_motor,relay_display_mode,relay_display_diagnostic,relay_display_status}=relay_ui_snapshot;
end endgenerate
// R56 relay display cone end.

    // R56 monitor display cone begin: keep original SDC instance binding.
    localparam MONITOR_UI_BITS=ESSENTIAL_UI ? 48 : 160;
    wire [MONITOR_UI_BITS-1:0] monitor_ui_snapshot;
    wire [159:0] monitor_ui_source=ESSENTIAL_UI ? {112'd0,mon_width,mon_height,mon_fps} :
     {mon_width,mon_height,mon_fps,mon_lane,mon_format,mon_gap,mon_frames,mon_seconds};
    status_cdc #(.WIDTH(MONITOR_UI_BITS)) u_monitor_display(
     .S_clk(I_sys_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data(monitor_ui_source[MONITOR_UI_BITS-1:0]),.D_data(monitor_ui_snapshot));
    assign mon_display=ESSENTIAL_UI ? {monitor_ui_snapshot[47:0],112'd0} : monitor_ui_snapshot;
    // R56 monitor display cone end.

    wire [83:0] overflow_display;
    status_cdc #(.WIDTH(17)) u_transport_display(
     .S_clk(S_ddr_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data({capture_ok,lost_frames}),.D_data(transport_display));
    generate if(ESSENTIAL_UI)begin : essential_diagnostics_ui
     assign publish_display=0;assign overflow_display=0;
    end else begin : legacy_diagnostics_ui
    status_cdc #(.WIDTH(PUBLISH_BITS)) u_publish_display(
     .S_clk(S_ddr_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data(publish_diagnostic),.D_data(publish_display));
    wire [31:0] wb_process;
    status_cdc #(.WIDTH(32)) u_wb_process(
     .S_clk(S_csi_rx_clk),.D_clk(S_process_clk),.rst_n(S_rst_n),.S_data(wb_active),.D_data(wb_process));
    status_cdc #(.WIDTH(84)) u_overflow_display(
     .S_clk(S_process_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data({wb_process,video_diagnostics,overflow_frames}),.D_data(overflow_display));
    end endgenerate
endmodule
