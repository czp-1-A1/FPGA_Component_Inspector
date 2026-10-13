// Measurement tap before uial2axis (which uses configured image dimensions).
// RAW10: four pixels per valid beat, with bubbles. Packet end comes from
// physical HS-valid falling; allow 16 cycles for the CSI/RAW pipeline to drain.
// Counters saturate. Lane counter counts error assertion edges, not bad pixels.
module input_monitor #(parameter integer REF_HZ=50000000)(
 input wire rx_clk, ref_clk, rst_n,
 input wire frame_start, frame_end, hs_valid, raw_valid,
 input wire [1:0] lane_error,
 output wire [15:0] width, height, lane_errors, format_errors,
 output reg [15:0] fps, gap_seconds,
 output reg [31:0] uptime,
 output wire [31:0] frames
);
reg hs_d, active, frame_toggle, raw_overflow;
reg [15:0] tail;
reg [15:0] pixels, lines, first_width, last_width, last_height;
reg [15:0] lane_count, format_count;
reg [1:0] lane_d;
reg [31:0] frame_count;
reg line_bad;
wire packet_end=tail[15];
always @(posedge rx_clk or negedge rst_n) begin
 if(!rst_n) begin
  hs_d<=0; tail<=0; active<=0; frame_toggle<=0;
  pixels<=0; lines<=0; first_width<=0; last_width<=0; last_height<=0;
  lane_count<=0; format_count<=0; lane_d<=0; frame_count<=0;
  line_bad<=0; raw_overflow<=0;
 end else begin
  hs_d<=hs_valid; tail<={tail[14:0],hs_d && !hs_valid}; lane_d<=lane_error;
  if((|(lane_error & ~lane_d)) && lane_count!=16'hffff) lane_count<=lane_count+1'b1;
  if(frame_start) begin
   active<=1; pixels<=0; lines<=0; first_width<=0; line_bad<=0; raw_overflow<=0;
   frame_toggle<=~frame_toggle;
   if(frame_count!=32'hffffffff) frame_count<=frame_count+1'b1;
   if(active && format_count!=16'hffff) format_count<=format_count+1'b1;
  end else if(active) begin
   if(raw_valid) begin
    if(pixels<=16'hfffb) pixels<=pixels+16'd4;
    else raw_overflow<=1;
   end
   if(packet_end && pixels!=0) begin
    pixels<=0;
    if(lines!=16'hffff) lines<=lines+1'b1;
    else line_bad<=1;
    if(lines==0) first_width<=pixels;
    else if(first_width!=pixels) line_bad<=1;
    if(raw_valid) line_bad<=1; // Insufficient drain gap: mark invalid, never silently accept.
   end
   if(frame_end) begin
    active<=0; last_width<=first_width; last_height<=lines;
    if((line_bad || raw_overflow || pixels!=0 || first_width!=1024 || lines!=600)
       && format_count!=16'hffff) format_count<=format_count+1'b1;
   end
  end
 end
end
wire [95:0] rx_status;
status_cdc #(.WIDTH(96)) rx_mailbox(
 .S_clk(rx_clk),.D_clk(ref_clk),.rst_n(rst_n),
 .S_data({last_width,last_height,lane_count,format_count,frame_count}),.D_data(rx_status));
assign {width,height,lane_errors,format_errors,frames}=rx_status;
reg [2:0] frame_sync;
reg [$clog2(REF_HZ)-1:0] second_count;
reg [15:0] window_frames;
wire frame_event=frame_sync[2]^frame_sync[1];
always @(posedge ref_clk or negedge rst_n) begin
 if(!rst_n) begin frame_sync<=0; second_count<=0; window_frames<=0; fps<=0; gap_seconds<=0; uptime<=0; end
 else begin
  frame_sync<={frame_sync[1:0],frame_toggle};
  if(second_count==REF_HZ-1) begin
   second_count<=0; window_frames<=0;
   fps<=window_frames + ((frame_event && window_frames!=16'hffff) ? 16'd1 : 16'd0);
   if(window_frames==0 && !frame_event && gap_seconds!=16'hffff) gap_seconds<=gap_seconds+1'b1;
   if(uptime!=32'hffffffff) uptime<=uptime+1'b1;
  end else begin
   second_count<=second_count+1'b1;
   if(frame_event && window_frames!=16'hffff) window_frames<=window_frames+1'b1;
  end
 end
end
endmodule
