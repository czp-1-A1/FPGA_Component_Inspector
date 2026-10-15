// Fixed-ROI 3528 experiment. Uses pre-overlay RGB, not MEAN or Sobel totals.
// Manual pocket alignment is still required. A missing shape is not EMPTY.
// States: 0 non-target, 1 uncertain/wait, 2 component, 3 small empty opening.
module roi_shape_model #(
 parameter X0=472,X1=552,Y0=260,Y1=340,
 parameter [7:0] FOREGROUND=8'd100,
 parameter P_LONG_MIN=52,P_LONG_MAX=78,P_SHORT_MIN=40,P_SHORT_MAX=72,
 parameter E_LONG_MIN=10,E_LONG_MAX=26,E_SHORT_MIN=8,E_SHORT_MAX=24,
 parameter S_LONG_MIN=28,S_LONG_MAX=46,S_SHORT_MIN=20,S_SHORT_MAX=42
)(
 input wire clk,rst_n,frame_start,pixel_accept,pixel_sof,
 input wire [10:0] pixel_x,input wire [9:0] pixel_y,input wire [95:0] rgb,
 input wire frame_commit,invalidate,
 output reg valid,output reg [1:0] state,
 output reg [12:0] foreground_count,output reg [6:0] box_width,box_height
);
localparam AREA=(X1-X0)*(Y1-Y0);
// ROI is <=80 x 80: pixel/foreground counts need 13 bits; offsets need 7.
reg [12:0] pixels,foreground_pixels;
reg [6:0] xmin,xmax,ymin,ymax;
reg seen,overflow;
wire [9:0] luminance_sum [0:3];
reg [3:0] selected,foreground_d;
reg [6:0] lane_x [0:3];reg [6:0] local_y;
reg accept_d,sof_d,commit_d,invalidate_d,start_d;
reg accept_dd,sof_dd,commit_dd,invalidate_dd,start_dd;
reg [2:0] beat_pixels,beat_foreground;
reg [6:0] beat_xmin,beat_xmax,beat_ymin,beat_ymax;
genvar g;
generate for(g=0;g<4;g=g+1) begin : gray
 assign luminance_sum[g]={2'd0,rgb[95-g*24-:8]}+
  {1'd0,rgb[87-g*24-:8],1'b0}+{2'd0,rgb[79-g*24-:8]};
end endgenerate
wire [6:0] min0=foreground_d[0] ? lane_x[0] : 7'd127;
wire [6:0] min1=foreground_d[1] ? lane_x[1] : 7'd127;
wire [6:0] min2=foreground_d[2] ? lane_x[2] : 7'd127;
wire [6:0] min3=foreground_d[3] ? lane_x[3] : 7'd127;
wire [6:0] max0=foreground_d[0] ? lane_x[0] : 7'd0;
wire [6:0] max1=foreground_d[1] ? lane_x[1] : 7'd0;
wire [6:0] max2=foreground_d[2] ? lane_x[2] : 7'd0;
wire [6:0] max3=foreground_d[3] ? lane_x[3] : 7'd0;
wire [6:0] min01=min0<min1 ? min0 : min1,min23=min2<min3 ? min2 : min3;
wire [6:0] max01=max0>max1 ? max0 : max1,max23=max2>max3 ? max2 : max3;
integer lane;
// Two-register PPC4 reduction, preserving bubbles/SOF/commit/cancel alignment.
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  selected<=0;foreground_d<=0;local_y<=0;
  for(lane=0;lane<4;lane=lane+1) lane_x[lane]<=0;
  accept_d<=0;sof_d<=0;commit_d<=0;invalidate_d<=0;start_d<=0;
  accept_dd<=0;sof_dd<=0;commit_dd<=0;invalidate_dd<=0;start_dd<=0;
  beat_pixels<=0;beat_foreground<=0;beat_xmin<=127;beat_xmax<=0;beat_ymin<=127;beat_ymax<=0;
 end else begin
  for(lane=0;lane<4;lane=lane+1) begin
   selected[lane]<=pixel_x+lane>=X0 && pixel_x+lane<X1 && pixel_y>=Y0 && pixel_y<Y1;
   foreground_d[lane]<=pixel_x+lane>=X0 && pixel_x+lane<X1 && pixel_y>=Y0 && pixel_y<Y1 &&
    luminance_sum[lane][9:2]>=FOREGROUND;
   // Offsets outside the selected ROI are ignored; truncation is intentional.
   lane_x[lane]<=pixel_x+lane-X0;
  end
  local_y<=pixel_y-Y0;
  beat_pixels<=({2'd0,selected[0]}+{2'd0,selected[1]})+({2'd0,selected[2]}+{2'd0,selected[3]});
  beat_foreground<=({2'd0,foreground_d[0]}+{2'd0,foreground_d[1]})+({2'd0,foreground_d[2]}+{2'd0,foreground_d[3]});
  beat_xmin<=min01<min23 ? min01 : min23;beat_xmax<=max01>max23 ? max01 : max23;
  beat_ymin<=|foreground_d ? local_y : 7'd127;beat_ymax<=|foreground_d ? local_y : 7'd0;
  accept_d<=pixel_accept;sof_d<=pixel_sof;commit_d<=frame_commit;invalidate_d<=invalidate;start_d<=frame_start;
  accept_dd<=accept_d;sof_dd<=sof_d;commit_dd<=commit_d;invalidate_dd<=invalidate_d;start_dd<=start_d;
 end
end
reg [1:0] calculating;
reg [12:0] pending_foreground;
reg [6:0] pending_width,pending_height;
reg pending_border;
reg [13:0] box_area;
wire [13:0] next_pixels={1'b0,pixels}+beat_pixels;
wire [13:0] next_foreground={1'b0,foreground_pixels}+beat_foreground;
wire [6:0] long_side=pending_width>pending_height ? pending_width : pending_height;
wire [6:0] short_side=pending_width<pending_height ? pending_width : pending_height;
// Constant-scaled comparisons avoid division; widest term is 6400*20=128000.
wire [17:0] foreground20={5'd0,pending_foreground}*18'd20;
wire [17:0] area17={4'd0,box_area}*18'd17;
wire [17:0] foreground5={5'd0,pending_foreground}*18'd5;
wire [17:0] area3={4'd0,box_area}*18'd3;
wire [17:0] foreground10={5'd0,pending_foreground}*18'd10;
wire [17:0] area9={4'd0,box_area}*18'd9;
wire [11:0] long20={5'd0,long_side}*12'd20,short21={5'd0,short_side}*12'd21,short31={5'd0,short_side}*12'd31;
wire [11:0] long5={5'd0,long_side}*12'd5,short7={5'd0,short_side}*12'd7;
wire present_match=long_side>=P_LONG_MIN && long_side<=P_LONG_MAX &&
 short_side>=P_SHORT_MIN && short_side<=P_SHORT_MAX &&
 long20>=short21 && long20<=short31 && foreground20>=area17;
wire circular=long5<=short7 && foreground5>=area3 && foreground10<=area9;
wire empty_match=circular && long_side>=E_LONG_MIN && long_side<=E_LONG_MAX &&
 short_side>=E_SHORT_MIN && short_side<=E_SHORT_MAX;
wire sprocket_match=circular && long_side>=S_LONG_MIN && long_side<=S_LONG_MAX &&
 short_side>=S_SHORT_MIN && short_side<=S_SHORT_MAX;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  pixels<=0;foreground_pixels<=0;xmin<=127;xmax<=0;ymin<=127;ymax<=0;seen<=0;overflow<=0;
  valid<=0;state<=1;foreground_count<=0;box_width<=0;box_height<=0;calculating<=0;
  pending_foreground<=0;pending_width<=0;pending_height<=0;pending_border<=0;box_area<=0;
 end else begin
  if(sof_dd) begin
   seen<=1;overflow<=0;pixels<=accept_dd ? beat_pixels : 0;
   foreground_pixels<=accept_dd ? beat_foreground : 0;
   xmin<=accept_dd ? beat_xmin : 127;xmax<=accept_dd ? beat_xmax : 0;
   ymin<=accept_dd ? beat_ymin : 127;ymax<=accept_dd ? beat_ymax : 0;
  end else if(accept_dd && seen) begin
   // Saturating counts prevent excess/duplicate ROI pixels wrapping to AREA.
   if(next_pixels>AREA || next_foreground>AREA) overflow<=1;
   pixels<=next_pixels>AREA ? AREA+1 : next_pixels[12:0];
   foreground_pixels<=next_foreground>AREA ? AREA+1 : next_foreground[12:0];
   if(beat_foreground!=0) begin
    if(beat_xmin<xmin) xmin<=beat_xmin;if(beat_xmax>xmax) xmax<=beat_xmax;
    if(beat_ymin<ymin) ymin<=beat_ymin;if(beat_ymax>ymax) ymax<=beat_ymax;
   end
  end
  if(frame_start || start_d || start_dd || invalidate || invalidate_d || invalidate_dd) begin
   valid<=0;state<=1;calculating<=0;
   if(frame_start || invalidate || invalidate_d || invalidate_dd) seen<=0;
  end else if(commit_dd) begin
   valid<=0;state<=1;calculating<=0;
   if(seen && !overflow && pixels==AREA) begin
    pending_foreground<=foreground_pixels;
    pending_width<=foreground_pixels!=0 ? xmax-xmin+1'b1 : 0;
    pending_height<=foreground_pixels!=0 ? ymax-ymin+1'b1 : 0;
    pending_border<=foreground_pixels!=0 && (xmin==0 || ymin==0 || xmax==X1-X0-1 || ymax==Y1-Y0-1);
    calculating<=1;
   end
  end else if(calculating==1) begin
   // One 7x7 product after ROI completion; no image RAM or pixel-rate multiply.
   box_area<=pending_width*pending_height;calculating<=2;
  end else if(calculating==2) begin
   foreground_count<=pending_foreground;box_width<=pending_width;box_height<=pending_height;
   valid<=1;calculating<=0;
   state<=pending_border || sprocket_match ? 2'd0 :
    present_match ? 2'd2 : empty_match ? 2'd3 : 2'd1;
  end
 end
end
endmodule
