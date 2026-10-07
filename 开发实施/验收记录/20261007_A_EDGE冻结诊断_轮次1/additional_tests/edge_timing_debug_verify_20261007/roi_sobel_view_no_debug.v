// RAW/GRAY preserve the AWB schedule. EDGE replays whole rows only when the
// downstream FIFO reserves a row. Unrecoverable cache overrun aborts the frame.
module roi_sobel_view_no_debug #(
 parameter WIDTH=1024,HEIGHT=600,
 parameter X0=256,X1=768,Y0=172,Y1=428,
 parameter CORE_X0=472,CORE_X1=552,CORE_Y0=260,CORE_Y1=340,
 parameter EDGE_THRESHOLD=80
)(
 input wire clk,rst_n,input wire pixel_valid,pixel_sof,pixel_last,early_sof,
 input wire [95:0] rgb,input wire [1:0] mode,input wire invalidate,
 input wire view_ready,output reg frame_bad,
 output reg out_valid,out_last,out_early_sof,output reg [95:0] out_rgb,
 output reg [10:0] out_x,output reg [9:0] out_y,
 output reg [12:0] core_pixels,edge_count,output reg [23:0] edge_sum
);
localparam BEATS=WIDTH/4;
reg [7:0] write_group,read_group;
reg [9:0] write_y,read_y,ready_rows;
reg reading,input_armed;
reg v1,v2,v3,v4,previous;
reg [1:0] frame_mode;
wire [7:0] write_address=pixel_sof ? 8'd0 : write_group;
wire [9:0] write_row=pixel_sof ? 10'd0 : write_y;
// Ignore residual AWB beats between the early reset and the true pixel SOF.
wire input_valid=pixel_valid && (input_armed || pixel_sof) && !early_sof;
wire cache_overrun=input_valid && !pixel_sof && frame_mode[1] &&
                   write_row>=read_y+10'd3 && read_y<HEIGHT;
wire read_issue=frame_mode[1] && !frame_bad && !cache_overrun &&
 !early_sof && !pixel_sof && read_y<HEIGHT &&
 (reading || (ready_rows>read_y && view_ready));
wire [7:0] read_address=reading ? read_group : 8'd0;
wire [95:0] row_q [0:3];
genvar bank;
generate for(bank=0;bank<4;bank=bank+1) begin : line_bank
 // Synchronous simple dual-port inference. Never reset/clear the memory.
 reg [95:0] memory [0:BEATS-1];
 reg [95:0] q;
 always @(posedge clk) begin
  if(rst_n && input_valid && !frame_bad && (pixel_sof ? mode[1] : frame_mode[1]) && write_row[1:0]==bank)
   memory[write_address]<=rgb;
  q<=memory[read_address];
 end
 assign row_q[bank]=q;
end endgenerate
reg [10:0] x1,x2,x3,x4;
reg [9:0] y1,y2,y3,y4;
reg [1:0] mode1,mode2,mode3,mode4;
reg [31:0] top2,mid2,bot2;
reg [95:0] rgb2,rgb3,rgb4;
wire [1:0] top_bank=y1[1:0]-2'd1;
wire [1:0] bottom_bank=y1[1:0]+2'd1;
wire [95:0] top_rgb=row_q[top_bank];
wire [95:0] middle_rgb=row_q[y1[1:0]];
wire [95:0] bottom_rgb=row_q[bottom_bank];
function [7:0] gray;
 input [23:0] color;reg [9:0] s;
 begin s={2'd0,color[23:16]}+{1'd0,color[15:8],1'b0}+{2'd0,color[7:0]};gray=s[9:2];end
endfunction
integer lane;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  write_group<=0;write_y<=0;read_group<=0;read_y<=0;ready_rows<=0;reading<=0;input_armed<=0;frame_mode<=0;
  v1<=0;v2<=0;x1<=0;x2<=0;y1<=0;y2<=0;mode1<=0;mode2<=0;
  top2<=0;mid2<=0;bot2<=0;rgb2<=0;
 end else begin
  v1<=read_issue;v2<=v1;
  x1<={1'b0,read_address,2'b00};y1<=read_y;mode1<=frame_mode;
  x2<=x1;y2<=y1;mode2<=mode1;rgb2<=middle_rgb;
  for(lane=0;lane<4;lane=lane+1) begin
   top2[31-lane*8-:8]<=gray(top_rgb[95-lane*24-:24]);
   mid2[31-lane*8-:8]<=gray(middle_rgb[95-lane*24-:24]);
   bot2[31-lane*8-:8]<=gray(bottom_rgb[95-lane*24-:24]);
  end
  if(input_valid) begin
   if(pixel_sof) begin
    input_armed<=1;
    write_group<=1;write_y<=0;read_group<=0;read_y<=0;ready_rows<=0;reading<=0;frame_mode<=mode;
    v1<=0;v2<=0;
   end else if(pixel_last) begin
    write_group<=0;write_y<=write_y+1'b1;
    // Row y makes center row y-1 available; final row also makes its
    // own border available. No synthetic zeros are fed into real edges.
    if(write_y==HEIGHT-1) ready_rows<=HEIGHT;
    else ready_rows<=write_y;
   end else write_group<=write_group+1'b1;
  end
  if(read_issue) begin
   if(read_address==BEATS-1) begin reading<=0;read_group<=0;read_y<=read_y+1'b1;end
   else begin reading<=1;read_group<=read_address+1'b1;end
  end
  if(early_sof || cache_overrun || frame_bad) begin
   reading<=0;v1<=0;v2<=0;
   if(early_sof) begin input_armed<=0;ready_rows<=0;read_y<=0;end
  end
 end
end

// One group of horizontal lookahead; all four centers keep their neighbors.
reg [31:0] top_p,mid_p,bot_p;
reg [7:0] left_t,left_m,left_b;
reg [95:0] rgb_p;
reg [10:0] x_p;
reg [9:0] y_p;
reg [1:0] mode_p;
wire last_p=x_p==WIDTH-4;
wire process=previous && (v2 || last_p);
wire next_group=v2 && !last_p && y2==y_p && x2==x_p+11'd4;
wire [7:0] t [0:5];wire [7:0] m [0:5];wire [7:0] b [0:5];
assign t[0]=left_t;assign m[0]=left_m;assign b[0]=left_b;
assign t[5]=next_group ? top2[31:24] : 0;
assign m[5]=next_group ? mid2[31:24] : 0;
assign b[5]=next_group ? bot2[31:24] : 0;
genvar g;
generate for(g=0;g<4;g=g+1) begin : neighbors
 assign t[g+1]=top_p[31-g*8-:8];
 assign m[g+1]=mid_p[31-g*8-:8];
 assign b[g+1]=bot_p[31-g*8-:8];
end endgenerate
reg [9:0] xp [0:3],xn [0:3],yp [0:3],yn [0:3];
reg [10:0] magnitude [0:3];
reg [3:0] neighborhood3,core3,inside3,neighborhood4,core4,inside4;
wire [9:0] dx [0:3];wire [9:0] dy [0:3];
generate for(g=0;g<4;g=g+1) begin : gradients
 assign dx[g]=xp[g]>=xn[g] ? xp[g]-xn[g] : xn[g]-xp[g];
 assign dy[g]=yp[g]>=yn[g] ? yp[g]-yn[g] : yn[g]-yp[g];
end endgenerate
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  previous<=0;top_p<=0;mid_p<=0;bot_p<=0;left_t<=0;left_m<=0;left_b<=0;
  rgb_p<=0;x_p<=0;y_p<=0;mode_p<=0;
  v3<=0;v4<=0;x3<=0;x4<=0;y3<=0;y4<=0;mode3<=0;mode4<=0;rgb3<=0;rgb4<=0;
  neighborhood3<=0;core3<=0;inside3<=0;neighborhood4<=0;core4<=0;inside4<=0;
  for(lane=0;lane<4;lane=lane+1) begin xp[lane]<=0;xn[lane]<=0;yp[lane]<=0;yn[lane]<=0;magnitude[lane]<=0;end
 end else begin
  v3<=process;v4<=v3;
  x3<=x_p;y3<=y_p;mode3<=mode_p;rgb3<=rgb_p;
  x4<=x3;y4<=y3;mode4<=mode3;rgb4<=rgb3;
  neighborhood4<=neighborhood3;core4<=core3;inside4<=inside3;
  if(process) previous<=0;
  if(v2) begin
   previous<=1;top_p<=top2;mid_p<=mid2;bot_p<=bot2;rgb_p<=rgb2;x_p<=x2;y_p<=y2;mode_p<=mode2;
   left_t<=x2==0 ? 0 : top_p[7:0];
   left_m<=x2==0 ? 0 : mid_p[7:0];
   left_b<=x2==0 ? 0 : bot_p[7:0];
  end
  for(lane=0;lane<4;lane=lane+1) begin
   // 10-bit weighted side sums, maximum 4*255=1020.
   xp[lane]<={2'd0,t[lane+2]}+{1'd0,m[lane+2],1'b0}+{2'd0,b[lane+2]};
   xn[lane]<={2'd0,t[lane]}+{1'd0,m[lane],1'b0}+{2'd0,b[lane]};
   yp[lane]<={2'd0,b[lane]}+{1'd0,b[lane+1],1'b0}+{2'd0,b[lane+2]};
   yn[lane]<={2'd0,t[lane]}+{1'd0,t[lane+1],1'b0}+{2'd0,t[lane+2]};
   magnitude[lane]<={1'b0,dx[lane]}+{1'b0,dy[lane]};
   neighborhood3[lane]<=x_p+lane>X0 && x_p+lane<X1-1 && y_p>Y0 && y_p<Y1-1 && y_p>0 && y_p<HEIGHT-1;
   core3[lane]<=x_p+lane>=CORE_X0 && x_p+lane<CORE_X1 && y_p>=CORE_Y0 && y_p<CORE_Y1;
   inside3[lane]<=x_p+lane>=X0 && x_p+lane<X1 && y_p>=Y0 && y_p<Y1;
  end
  if(pixel_sof || early_sof || cache_overrun || frame_bad) begin previous<=0;v3<=0;v4<=0;end
 end
end

reg [2:0] beat_pixels,beat_edges;
reg [12:0] beat_strength; // four 11-bit gradients: maximum 8160.
reg count_valid,count_enabled;
wire [3:0] selected=core4 & neighborhood4;
wire [3:0] edges={magnitude[3]>=EDGE_THRESHOLD,magnitude[2]>=EDGE_THRESHOLD,magnitude[1]>=EDGE_THRESHOLD,magnitude[0]>=EDGE_THRESHOLD};
wire [10:0] strengths [0:3];
generate for(g=0;g<4;g=g+1) begin : selection
 assign strengths[g]=selected[g] ? magnitude[g] : 0;
end endgenerate
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  out_valid<=0;out_last<=0;out_rgb<=0;out_x<=0;out_y<=0;
  beat_pixels<=0;beat_edges<=0;beat_strength<=0;count_valid<=0;count_enabled<=0;
  core_pixels<=0;edge_count<=0;edge_sum<=0;
 end else begin
  out_valid<=v4;out_last<=v4 && x4==WIDTH-4;out_x<=x4;out_y<=y4;
  if(!(pixel_sof ? mode[1] : frame_mode[1])) begin
   out_valid<=input_valid;out_last<=input_valid && pixel_last;
   out_x<={1'b0,write_address,2'b00};out_y<=write_row;
  end
  if(early_sof || frame_bad || cache_overrun) begin out_valid<=0;out_last<=0;end
  for(lane=0;lane<4;lane=lane+1) begin
   if(!(pixel_sof ? mode[1] : frame_mode[1]))
    out_rgb[95-lane*24-:24]<=(pixel_sof ? mode[0] : frame_mode[0]) &&
     write_address*4+lane>=X0 && write_address*4+lane<X1 && write_row>=Y0 && write_row<Y1 ?
      {3{gray(rgb[95-lane*24-:24])}} : rgb[95-lane*24-:24];
   else out_rgb[95-lane*24-:24]<=inside4[lane] && mode4[1] && neighborhood4[lane] && edges[lane] ? 24'hffae64 :
    inside4[lane] && mode4[0] ? {3{gray(rgb4[95-lane*24-:24])}} : rgb4[95-lane*24-:24];
  end
  count_valid<=v4;
  beat_pixels<=({2'd0,selected[0]}+{2'd0,selected[1]})+({2'd0,selected[2]}+{2'd0,selected[3]});
  beat_edges<=({2'd0,(selected[0] && edges[0])}+{2'd0,(selected[1] && edges[1])})+
              ({2'd0,(selected[2] && edges[2])}+{2'd0,(selected[3] && edges[3])});
  beat_strength<=({2'd0,strengths[0]}+{2'd0,strengths[1]})+({2'd0,strengths[2]}+{2'd0,strengths[3]});
  if(invalidate || early_sof || frame_bad || cache_overrun) begin count_enabled<=0;core_pixels<=0;edge_count<=0;edge_sum<=0;end
  else if(pixel_sof) begin count_enabled<=mode[1];core_pixels<=0;edge_count<=0;edge_sum<=0;count_valid<=0;end
  else if(count_valid && count_enabled) begin
   core_pixels<=core_pixels+beat_pixels;edge_count<=edge_count+beat_edges;edge_sum<=edge_sum+beat_strength;
  end
 end
end

// A new early FS cancels old tail data before resetting the camera FIFO.
// The writer's exact word count prevents the unfinished slot being published.
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin out_early_sof<=0;frame_bad<=0;end
 else begin
  out_early_sof<=early_sof;
  if(early_sof) frame_bad<=0;
  else if(cache_overrun) frame_bad<=1;
 end
end
endmodule
