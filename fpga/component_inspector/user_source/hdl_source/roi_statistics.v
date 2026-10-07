// Half-open ROI. Four pixels retain the AWB high-to-low display order.
// Approximate luminance is floor((R+2G+B)/4); no pixel-rate multiplication/divide.
module roi_statistics #(
 parameter WIDTH=1024,HEIGHT=600,X_BITS=$clog2(WIDTH+1),Y_BITS=$clog2(HEIGHT+1),
 parameter X0=256,X1=768,Y0=172,Y1=428
)(
 input wire clk,rst_n,pixel_accept,pixel_sof,
 input wire [X_BITS-1:0] pixel_x,input wire [Y_BITS-1:0] pixel_y,input wire [95:0] rgb,
 input wire frame_commit,invalidate,
 output reg sample_valid,output reg [7:0] mean,minimum,maximum,
 output reg [19:0] sample_pixels,output reg [27:0] sample_sum,
 output reg sample_new,
 input wire frame_start
);
localparam [20:0] AREA=(X1-X0)*(Y1-Y0);
reg [27:0] sum;
reg [19:0] count;
reg [7:0] lo,hi;
reg [7:0] lane_gray [0:3];
reg [3:0] selected;
reg accept_d,sof_d,commit_d,invalidate_d;
reg accept_dd,sof_dd,commit_dd,invalidate_dd;
reg frame_start_d,frame_start_dd;
reg [10:0] beat_sum;
reg [2:0] beat_count;
reg [7:0] beat_lo,beat_hi;
wire [9:0] channel_sum [0:3];
wire [7:0] selected_gray [0:3];
wire [7:0] selected_lo [0:3];
genvar g;
generate for(g=0;g<4;g=g+1) begin : grayscale
 assign channel_sum[g]={2'd0,rgb[95-g*24-:8]}+{1'd0,rgb[87-g*24-:8],1'b0}+{2'd0,rgb[79-g*24-:8]};
 assign selected_gray[g]=selected[g] ? lane_gray[g] : 0;
 assign selected_lo[g]=selected[g] ? lane_gray[g] : 255;
end endgenerate
wire [7:0] lo01=selected_lo[0]<selected_lo[1] ? selected_lo[0] : selected_lo[1];
wire [7:0] lo23=selected_lo[2]<selected_lo[3] ? selected_lo[2] : selected_lo[3];
wire [7:0] hi01=selected_gray[0]>selected_gray[1] ? selected_gray[0] : selected_gray[1];
wire [7:0] hi23=selected_gray[2]>selected_gray[3] ? selected_gray[2] : selected_gray[3];
integer lane;
// Separate grayscale, balanced beat reduction and frame accumulation at 112.5 MHz.
// Bubble, SOF, commit and invalidation controls follow the same two registers.
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  for(lane=0;lane<4;lane=lane+1) lane_gray[lane]<=0;
  selected<=0; beat_sum<=0; beat_count<=0; beat_lo<=255; beat_hi<=0;
  frame_start_d<=0; frame_start_dd<=0;
  accept_d<=0; sof_d<=0; commit_d<=0; invalidate_d<=0;
  accept_dd<=0; sof_dd<=0; commit_dd<=0; invalidate_dd<=0;
 end else begin
  for(lane=0;lane<4;lane=lane+1) begin
   lane_gray[lane]<=channel_sum[lane][9:2];
   selected[lane]<=pixel_x+lane>=X0 && pixel_x+lane<X1 && pixel_y>=Y0 && pixel_y<Y1;
  end
  beat_sum<=({3'd0,selected_gray[0]}+{3'd0,selected_gray[1]})+({3'd0,selected_gray[2]}+{3'd0,selected_gray[3]});
  beat_count<=({2'd0,selected[0]}+{2'd0,selected[1]})+({2'd0,selected[2]}+{2'd0,selected[3]});
  beat_lo<=lo01<lo23 ? lo01 : lo23; beat_hi<=hi01>hi23 ? hi01 : hi23;
  frame_start_d<=frame_start; frame_start_dd<=frame_start_d;
  accept_d<=pixel_accept; sof_d<=pixel_sof; commit_d<=frame_commit; invalidate_d<=invalidate;
  accept_dd<=accept_d; sof_dd<=sof_d; commit_dd<=commit_d; invalidate_dd<=invalidate_d;
 end
end
// One small division after a completed frame; output fields update atomically.
reg dividing;
reg [4:0] bits_left;
reg [27:0] shift,quotient,pending_sum;
reg [20:0] remainder;
reg [19:0] pending_count;
reg [7:0] pending_lo,pending_hi;
wire [20:0] trial={remainder[19:0],shift[27]};
wire take=trial>=AREA;
wire [27:0] quotient_next={quotient[26:0],take};
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  sum<=0; count<=0; lo<=255; hi<=0; sample_valid<=0; sample_new<=0;
  mean<=0; minimum<=0; maximum<=0; sample_pixels<=0; sample_sum<=0;
  dividing<=0; bits_left<=0; shift<=0; quotient<=0; remainder<=0;
  pending_sum<=0; pending_count<=0; pending_lo<=0; pending_hi<=0;
 end else begin
  sample_new<=0;
  if(sof_dd) begin
   sum<=accept_dd ? beat_sum : 0; count<=accept_dd ? beat_count : 0;
   lo<=accept_dd && beat_count!=0 ? beat_lo : 255;
   hi<=accept_dd && beat_count!=0 ? beat_hi : 0;
  end else if(accept_dd && beat_count!=0) begin
   sum<=sum+beat_sum; count<=count+beat_count;
   if(beat_lo<lo) lo<=beat_lo;
   if(beat_hi>hi) hi<=beat_hi;
  end
  if(invalidate || invalidate_d || invalidate_dd) begin sample_valid<=0; dividing<=0; end
  // Retain the last completed statistics for tuning, but never finish an old
  // division/commit after a new acquisition starts. Classification clears separately.
  else if(frame_start || frame_start_d || frame_start_dd) dividing<=0;
  else if(commit_dd) begin
   if(count==AREA && AREA!=0) begin
    dividing<=1; bits_left<=28; shift<=sum; quotient<=0; remainder<=0;
    pending_sum<=sum; pending_count<=count; pending_lo<=lo; pending_hi<=hi;
   end else begin sample_valid<=0; dividing<=0; end
  end else if(dividing) begin
   shift<={shift[26:0],1'b0}; quotient<=quotient_next;
   remainder<=take ? trial-AREA : trial; bits_left<=bits_left-1'b1;
   if(bits_left==1) begin
    dividing<=0; sample_valid<=1; sample_new<=1; mean<=quotient_next[7:0];
    minimum<=pending_lo; maximum<=pending_hi; sample_pixels<=pending_count; sample_sum<=pending_sum;
   end
  end
 end
end
endmodule
