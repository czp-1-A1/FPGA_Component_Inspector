// Half-open ROI. Four pixels retain the AWB high-to-low display order.
// Approximate luminance is floor((R+2G+B)/4); no pixel-rate multiplication/divide.
module roi_statistics #(
 parameter X0=384,X1=640,Y0=236,Y1=364
)(
 input wire clk,rst_n,pixel_accept,pixel_sof,
 input wire [10:0] pixel_x,input wire [9:0] pixel_y,input wire [95:0] rgb,
 input wire frame_commit,invalidate,
 output reg sample_valid,output reg [7:0] mean,minimum,maximum,
 output reg [19:0] sample_pixels,output reg [27:0] sample_sum
);
localparam [20:0] AREA=(X1-X0)*(Y1-Y0);
reg [27:0] sum;
reg [19:0] count;
reg [7:0] lo,hi;
reg [10:0] beat_sum;
reg [2:0] beat_count;
reg [7:0] beat_lo,beat_hi;
reg [9:0] channel_sum;
reg [7:0] gray;
integer lane;
always @* begin
 beat_sum=0; beat_count=0; beat_lo=255; beat_hi=0; channel_sum=0; gray=0;
 for(lane=0;lane<4;lane=lane+1) begin
  channel_sum={2'd0,rgb[95-lane*24-:8]}+{1'd0,rgb[87-lane*24-:8],1'b0}+{2'd0,rgb[79-lane*24-:8]};
  gray=channel_sum[9:2];
  if(pixel_x+lane>=X0 && pixel_x+lane<X1 && pixel_y>=Y0 && pixel_y<Y1) begin
   beat_sum=beat_sum+gray; beat_count=beat_count+1'b1;
   if(gray<beat_lo) beat_lo=gray;
   if(gray>beat_hi) beat_hi=gray;
  end
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
  sum<=0; count<=0; lo<=255; hi<=0; sample_valid<=0;
  mean<=0; minimum<=0; maximum<=0; sample_pixels<=0; sample_sum<=0;
  dividing<=0; bits_left<=0; shift<=0; quotient<=0; remainder<=0;
  pending_sum<=0; pending_count<=0; pending_lo<=0; pending_hi<=0;
 end else begin
  if(pixel_sof) begin
   sum<=pixel_accept ? beat_sum : 0; count<=pixel_accept ? beat_count : 0;
   lo<=pixel_accept && beat_count!=0 ? beat_lo : 255;
   hi<=pixel_accept && beat_count!=0 ? beat_hi : 0;
  end else if(pixel_accept && beat_count!=0) begin
   sum<=sum+beat_sum; count<=count+beat_count;
   if(beat_lo<lo) lo<=beat_lo;
   if(beat_hi>hi) hi<=beat_hi;
  end
  if(invalidate) begin sample_valid<=0; dividing<=0; end
  else if(frame_commit) begin
   if(count==AREA && AREA!=0) begin
    dividing<=1; bits_left<=28; shift<=sum; quotient<=0; remainder<=0;
    pending_sum<=sum; pending_count<=count; pending_lo<=lo; pending_hi<=hi;
   end else begin sample_valid<=0; dividing<=0; end
  end else if(dividing) begin
   shift<={shift[26:0],1'b0}; quotient<=quotient_next;
   remainder<=take ? trial-AREA : trial; bits_left<=bits_left-1'b1;
   if(bits_left==1) begin
    dividing<=0; sample_valid<=1; mean<=quotient_next[7:0];
    minimum<=pending_lo; maximum<=pending_hi; sample_pixels<=pending_count; sample_sum<=pending_sum;
   end
  end
 end
end
endmodule
