// One candidate frame. No buffering/backpressure of the video stream.
// Native packet boundaries prove capture completeness; output count alone cannot.
module roi_frame_guard #(parameter WIDTH=1024, HEIGHT=600)(
 input wire clk,rst_n,raw_start,raw_end,hs_valid,raw_valid,
 input wire [1:0] lane_error,input wire config_ok,
 input wire pixel_valid,pixel_sof,pixel_last,
 output wire [10:0] pixel_x,output wire [9:0] pixel_y,
 output wire pixel_accept,output reg frame_commit,invalidate
);
reg hs_d,native_active,raw_done,bad,got_sof,tracking,processed_done,reported;
reg [15:0] tail;
reg [16:0] line_pixels;
reg [10:0] lines,x;
reg [9:0] y;
reg [19:0] raw_total,processed_total;
wire packet_end=tail[15];
wire close_line=packet_end && line_pixels!=0;
wire [17:0] pixels_after={1'b0,line_pixels}+(raw_valid ? 18'd4 : 18'd0);
wire [11:0] lines_after={1'b0,lines}+(close_line ? 12'd1 : 12'd0);
wire [20:0] raw_after={1'b0,raw_total}+(raw_valid && native_active ? 21'd4 : 21'd0);
wire [20:0] processed_after=pixel_sof ? 21'd4 : {1'b0,processed_total}+21'd4;
assign pixel_x=pixel_sof ? 11'd0 : x;
assign pixel_y=pixel_sof ? 10'd0 : y;
assign pixel_accept=pixel_valid && (tracking || pixel_sof) &&
 (native_active || raw_done) && !processed_done && !bad && config_ok && !raw_start;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  hs_d<=0; tail<=0; native_active<=0; raw_done<=0; bad<=0;
  got_sof<=0; tracking<=0; processed_done<=0; reported<=0;
  line_pixels<=0; lines<=0; x<=0; y<=0; raw_total<=0; processed_total<=0;
  frame_commit<=0; invalidate<=0;
 end else begin
  hs_d<=hs_valid; tail<={tail[14:0],hs_d && !hs_valid};
  frame_commit<=0; invalidate<=0;
  if(raw_start) begin
   native_active<=1; raw_done<=0; got_sof<=0; tracking<=0;
   processed_done<=0; reported<=0; line_pixels<=0; lines<=0;
   raw_total<=0; processed_total<=0; x<=0; y<=0;
   bad<=!config_ok || |lane_error || raw_valid || raw_end || pixel_sof;
   if(!config_ok || |lane_error || raw_valid || raw_end || pixel_sof ||
      ((native_active || raw_done) && !reported)) invalidate<=1;
  end else begin
   if(!config_ok || |lane_error) begin bad<=1; invalidate<=1; end
   if(native_active) begin
    if(raw_valid) begin
     if(raw_after>WIDTH*HEIGHT || pixels_after>WIDTH) begin bad<=1; invalidate<=1; end
     else begin raw_total<=raw_after[19:0]; line_pixels<=pixels_after[16:0]; end
    end
    if(close_line) begin
     line_pixels<=0;
     if(line_pixels!=WIDTH || raw_valid || lines_after>HEIGHT) begin bad<=1; invalidate<=1; end
     else lines<=lines_after[10:0];
    end
    if(raw_end) begin
     native_active<=0; raw_done<=1;
     if(lines_after!=HEIGHT || raw_after!=WIDTH*HEIGHT ||
        (!close_line && pixels_after!=0) || (close_line && (line_pixels!=WIDTH || raw_valid))) begin
      bad<=1; invalidate<=1;
     end
    end
   end else if(raw_valid || raw_end) begin bad<=1; invalidate<=1; end

   if(pixel_sof) begin
    got_sof<=1; tracking<=pixel_valid; x<=4; y<=0; processed_total<=4;
    if(!pixel_valid || pixel_last || got_sof || processed_done ||
       !(native_active || raw_done) || raw_after<4) begin bad<=1; invalidate<=1; end
   end else if(pixel_valid && tracking && !processed_done) begin
    processed_total<=processed_after[19:0];
    if(processed_after>raw_after || processed_after>WIDTH*HEIGHT || y>=HEIGHT ||
       (pixel_last != (x==WIDTH-4))) begin bad<=1; invalidate<=1; end
    if(pixel_last) begin
     x<=0;
     if(y==HEIGHT-1) begin processed_done<=1; tracking<=0; end
     else y<=y+1'b1;
    end else if(x<WIDTH-4) x<=x+11'd4;
   end else if(pixel_valid && processed_done) begin bad<=1; invalidate<=1; end

   // Both completion flags were registered on prior edges. ROI's last beat
   // has therefore been accumulated before this pulse reaches its snapshot.
   if(raw_done && processed_done && !reported) begin
    reported<=1;
    if(!bad && config_ok && !(|lane_error) && !pixel_valid && !raw_valid && !raw_end)
     frame_commit<=1;
    else invalidate<=1;
   end
  end
 end
end
endmodule
