// Half-open ROI. Four pixels retain the AWB high-to-low display order.
// Approximate luminance is floor((R+2G+B)/4); no pixel-rate multiplication/divide.
module roi_statistics #(
 parameter DYNAMIC_ROI=0,X0=256,X1=768,Y0=172,Y1=428
)(
 input wire clk,rst_n,pixel_accept,pixel_sof,
 input wire [10:0] pixel_x,input wire [9:0] pixel_y,input wire [95:0] rgb,
 input wire frame_commit,invalidate,
 output reg sample_valid,output reg [7:0] mean,minimum,maximum,
 output reg [19:0] sample_pixels,output reg [27:0] sample_sum,
 output reg sample_new,
 input wire frame_start,
 input wire [10:0] dynamic_x0,dynamic_x1,input wire [9:0] dynamic_y0,dynamic_y1
);
wire [10:0] x0=DYNAMIC_ROI ? dynamic_x0 : X0,x1=DYNAMIC_ROI ? dynamic_x1 : X1;
wire [9:0] y0=DYNAMIC_ROI ? dynamic_y0 : Y0,y1=DYNAMIC_ROI ? dynamic_y1 : Y1;
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
   selected[lane]<=pixel_x+lane>=x0 && pixel_x+lane<x1 && pixel_y>=y0 && pixel_y<y1;
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

// Two fixed calibration probes, before display processing. The outer 64x64
// window measures the SAME 2x2 averaged threshold mask as frame_shape_search.
// The inner16x16 measures native 720p luminance, including saturation count.
// One record per probe: valid,clip,mode,mean,min,max,sat9,area13,width7,height7.
// Width/height/area are 720p pixels (2*mask width/height,4*mask area), not padded.
module calibration_probes #(parameter WIDTH=1280,HEIGHT=720)(
 input wire clk,rst_n,frame_start,invalidate,accept,commit,
 input wire [10:0] x,input wire [9:0] y,input wire [95:0] rgb,
 input wire [1:0] mode,output reg [127:0] record
);
localparam X0=WIDTH/2-32,Y0=HEIGHT*4/9-32,Y1=HEIGHT*43/60-32;
wire [7:0] threshold=mode==0 ? 100 : mode==1 ? 80 : mode==2 ? 120 : 140;
wire xin=x>=X0 && x<X0+64;
wire [1:0] yin={y>=Y1 && y<Y1+64,y>=Y0 && y<Y0+64};
wire [9:0] gsum[0:3];wire [7:0] gray[0:3];
genvar g;
generate for(g=0;g<4;g=g+1)begin : luma
 assign gsum[g]={2'b0,rgb[95-g*24-:8]}+{1'b0,rgb[87-g*24-:8],1'b0}+{2'b0,rgb[79-g*24-:8]};
 assign gray[g]=gsum[g][9:2];
end endgenerate
wire [8:0] p0={1'b0,gray[0]}+gray[1],p1={1'b0,gray[2]}+gray[3];
reg [17:0] line_pair[0:15];reg [17:0] above,pair_d;
wire [3:0] address=(x-X0)>>2;
always @(posedge clk)begin
 if(accept && xin && |yin && !y[0])line_pair[address]<={p1,p0};
 above<=line_pair[address];
end
reg ad;reg [1:0] yd;reg odd_d,inner_d;reg [4:0] mx_d;
reg [4:0] my0_d,my1_d;
reg [9:0] sum_d;reg [7:0] lo_d,hi_d;reg [2:0] sat_d;
wire [9:0] block0={1'b0,pair_d[8:0]}+above[8:0],block1={1'b0,pair_d[17:9]}+above[17:9];
wire f0=block0[9:2]>=threshold,f1=block1[9:2]>=threshold;
wire [7:0] lo01=gray[0]<gray[1] ? gray[0] : gray[1],lo23=gray[2]<gray[3] ? gray[2] : gray[3];
wire [7:0] hi01=gray[0]>gray[1] ? gray[0] : gray[1],hi23=gray[2]>gray[3] ? gray[2] : gray[3];
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin ad<=0;yd<=0;odd_d<=0;inner_d<=0;mx_d<=0;my0_d<=0;my1_d<=0;pair_d<=0;sum_d<=0;lo_d<=0;hi_d<=0;sat_d<=0;end
 else begin
  ad<=accept && xin;yd<=yin;odd_d<=y[0];pair_d<={p1,p0};
  mx_d<=(x-X0)>>1;my0_d<=(y-Y0)>>1;my1_d<=(y-Y1)>>1;
  inner_d<=x>=X0+24 && x<X0+40;
  sum_d<=({2'b0,gray[0]}+gray[1])+({2'b0,gray[2]}+gray[3]);
  lo_d<=lo01<lo23 ? lo01 : lo23;hi_d<=hi01>hi23 ? hi01 : hi23;
  sat_d<={2'b0,gray[0]==255}+{2'b0,gray[1]==255}+{2'b0,gray[2]==255}+{2'b0,gray[3]==255};
  if(frame_start || invalidate)ad<=0;
 end
end
reg [12:0] pixels[0:1];reg [10:0] count[0:1];
reg [4:0] xmin[0:1],xmax[0:1],ymin[0:1],ymax[0:1];
reg clip[0:1];reg [8:0] inner_count[0:1],sat[0:1];
reg [15:0] total[0:1];reg [7:0] low[0:1],high[0:1];
wire [4:0] row[0:1];assign row[0]=my0_d;assign row[1]=my1_d;
wire [6:0] width0=count[0]!=0 ? ({2'b0,xmax[0]}-xmin[0]+1'b1)<<1 : 0;
wire [6:0] height0=count[0]!=0 ? ({2'b0,ymax[0]}-ymin[0]+1'b1)<<1 : 0;
wire [6:0] width1=count[1]!=0 ? ({2'b0,xmax[1]}-xmin[1]+1'b1)<<1 : 0;
wire [6:0] height1=count[1]!=0 ? ({2'b0,ymax[1]}-ymin[1]+1'b1)<<1 : 0;
integer z;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  record<=0;
  for(z=0;z<2;z=z+1)begin pixels[z]<=0;count[z]<=0;xmin[z]<=31;xmax[z]<=0;ymin[z]<=31;ymax[z]<=0;clip[z]<=0;inner_count[z]<=0;sat[z]<=0;total[z]<=0;low[z]<=255;high[z]<=0;end
 end else if(frame_start || invalidate)begin
  record<=0;
  for(z=0;z<2;z=z+1)begin pixels[z]<=0;count[z]<=0;xmin[z]<=31;xmax[z]<=0;ymin[z]<=31;ymax[z]<=0;clip[z]<=0;inner_count[z]<=0;sat[z]<=0;total[z]<=0;low[z]<=255;high[z]<=0;end
 end else begin
  for(z=0;z<2;z=z+1)if(ad && yd[z])begin
   pixels[z]<=pixels[z]+13'd4;
   if(inner_d && row[z]>=12 && row[z]<20)begin
    inner_count[z]<=inner_count[z]+9'd4;total[z]<=total[z]+sum_d;sat[z]<=sat[z]+sat_d;
    if(lo_d<low[z])low[z]<=lo_d;if(hi_d>high[z])high[z]<=hi_d;
   end
   if(odd_d)begin
    count[z]<=count[z]+{10'd0,f0}+{10'd0,f1};
    if(f0 || f1)begin
     if((f0 ? mx_d : mx_d+1'b1)<xmin[z])xmin[z]<=f0 ? mx_d : mx_d+1'b1;
     if((f1 ? mx_d+1'b1 : mx_d)>xmax[z])xmax[z]<=f1 ? mx_d+1'b1 : mx_d;
     if(row[z]<ymin[z])ymin[z]<=row[z];if(row[z]>ymax[z])ymax[z]<=row[z];
     if(row[z]==0 || row[z]==31 || (f0 && mx_d==0) || (f1 && mx_d==30))clip[z]<=1;
    end
   end
  end
  if(commit)begin
   record[63:0]<={pixels[0]==4096 && inner_count[0]==256,clip[0],mode,total[0][15:8],low[0],high[0],sat[0],count[0],2'b00,width0,height0};
   record[127:64]<={pixels[1]==4096 && inner_count[1]==256,clip[1],mode,total[1][15:8],low[1],high[1],sat[1],count[1],2'b00,width1,height1};
  end
 end
end
endmodule
