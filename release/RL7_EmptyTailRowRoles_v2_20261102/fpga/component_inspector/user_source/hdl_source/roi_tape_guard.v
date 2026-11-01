// Plausibility check for black tape in two reference strips beside the core.
// This rejects obvious off-tape backgrounds, not every misplaced/locator hole.
// PPC4 AWB order; grayscale/reduction/accumulation follow two control registers.
module roi_tape_guard #(
 parameter DYNAMIC_ROI=0,X0=472,X1=552,Y0=260,Y1=340,STRIP=16,
 parameter [7:0] DARK_LIMIT=8'd100
)(
 input wire clk,rst_n,pixel_accept,pixel_sof,frame_start,invalidate,
 input wire [10:0] pixel_x,input wire [9:0] pixel_y,input wire [95:0] rgb,
 input wire [10:0] dynamic_x0,dynamic_x1,input wire [9:0] dynamic_y0,dynamic_y1,
 output wire scene_ok
);
wire [10:0] x0=DYNAMIC_ROI ? dynamic_x0 : X0,x1=DYNAMIC_ROI ? dynamic_x1 : X1;
wire [9:0] y0=DYNAMIC_ROI ? dynamic_y0 : Y0,y1=DYNAMIC_ROI ? dynamic_y1 : Y1;
localparam [12:0] AREA=STRIP*(Y1-Y0);
localparam [12:0] DARK_REQUIRED=(STRIP*(Y1-Y0)*3)/4;
reg [3:0] left_selected,right_selected,dark;
reg accept_d,accept_dd,sof_d,sof_dd,invalid_d,invalid_dd,fs_d,fs_dd;
reg [2:0] left_beat,right_beat,left_dark_beat,right_dark_beat;
reg [12:0] left_count,right_count,left_dark,right_dark;
wire [9:0] gray_sum [0:3];
genvar g;
generate for(g=0;g<4;g=g+1) begin : gray
 assign gray_sum[g]={2'd0,rgb[95-g*24-:8]}+{1'd0,rgb[87-g*24-:8],1'b0}+{2'd0,rgb[79-g*24-:8]};
end endgenerate
integer lane;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  left_selected<=0;right_selected<=0;dark<=0;
  left_beat<=0;right_beat<=0;left_dark_beat<=0;right_dark_beat<=0;
  accept_d<=0;accept_dd<=0;sof_d<=0;sof_dd<=0;
  invalid_d<=0;invalid_dd<=0;fs_d<=0;fs_dd<=0;
 end else begin
  for(lane=0;lane<4;lane=lane+1) begin
   left_selected[lane]<=pixel_x+lane>=x0-STRIP && pixel_x+lane<x0 && pixel_y>=y0 && pixel_y<y1;
   right_selected[lane]<=pixel_x+lane>=x1 && pixel_x+lane<x1+STRIP && pixel_y>=y0 && pixel_y<y1;
   dark[lane]<=gray_sum[lane][9:2]<=DARK_LIMIT;
  end
  left_beat<=({2'd0,left_selected[0]}+{2'd0,left_selected[1]})+({2'd0,left_selected[2]}+{2'd0,left_selected[3]});
  right_beat<=({2'd0,right_selected[0]}+{2'd0,right_selected[1]})+({2'd0,right_selected[2]}+{2'd0,right_selected[3]});
  left_dark_beat<=({2'd0,(left_selected[0] && dark[0])}+{2'd0,(left_selected[1] && dark[1])})+({2'd0,(left_selected[2] && dark[2])}+{2'd0,(left_selected[3] && dark[3])});
  right_dark_beat<=({2'd0,(right_selected[0] && dark[0])}+{2'd0,(right_selected[1] && dark[1])})+({2'd0,(right_selected[2] && dark[2])}+{2'd0,(right_selected[3] && dark[3])});
  accept_d<=pixel_accept;accept_dd<=accept_d;sof_d<=pixel_sof;sof_dd<=sof_d;
  invalid_d<=invalidate;invalid_dd<=invalid_d;fs_d<=frame_start;fs_dd<=fs_d;
 end
end
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin left_count<=0;right_count<=0;left_dark<=0;right_dark<=0;end
 else if(invalidate || invalid_d || invalid_dd || frame_start || fs_d || fs_dd) begin
  left_count<=0;right_count<=0;left_dark<=0;right_dark<=0;
 end else if(sof_dd) begin
  left_count<=accept_dd ? left_beat : 0;right_count<=accept_dd ? right_beat : 0;
  left_dark<=accept_dd ? left_dark_beat : 0;right_dark<=accept_dd ? right_dark_beat : 0;
 end else if(accept_dd) begin
  left_count<=left_count+left_beat;right_count<=right_count+right_beat;
  left_dark<=left_dark+left_dark_beat;right_dark<=right_dark+right_dark_beat;
 end
end
assign scene_ok=left_count==AREA && right_count==AREA &&
               left_dark>=DARK_REQUIRED && right_dark>=DARK_REQUIRED;
endmodule
