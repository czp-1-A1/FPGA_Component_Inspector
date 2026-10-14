// Bounded local search in pre-overlay PPC4 RGB. Native frame guard proves capture.
// Capture two mask bits per pixel; flood-fill 4-connected blobs after the search
// rows, while the camera still clocks lower rows. No backpressure on video.
module roi_shape_search #(
 parameter X0=416,X1=608,Y0=228,Y1=372,
 parameter [7:0] FOREGROUND=100
)(
 input wire clk,rst_n,frame_start,pixel_sof,pixel_accept,invalidate,
 input wire [10:0] pixel_x,input wire [9:0] pixel_y,input wire [95:0] rgb,
 output reg ready,sample_new,located,output reg [1:0] state,
 output reg [12:0] foreground_count,output reg [6:0] box_width,box_height,
 output reg [10:0] box_x0,box_x1,output reg [9:0] box_y0,box_y1
);
localparam W=X1-X0,H=Y1-Y0,WORDS=W*H/4;
// This implementation uses the fixed 192x144 search and 512-entry queue.
// Queue overflow aborts with UNCERTAIN; memory contents need no reset.
reg [7:0] mask [0:6911];reg [15:0] queue [0:511];
reg [12:0] cap_addr;reg [7:0] cap_data;reg cap_write,cap_last,seen;
reg [12:0] cap_count;reg [14:0] capture_foreground;
wire [2:0] cap_fg={2'b0,cap_data[0]}+{2'b0,cap_data[1]}+{2'b0,cap_data[2]}+{2'b0,cap_data[3]};
wire in_search=pixel_x>=X0 && pixel_x<X1 && pixel_y>=Y0 && pixel_y<Y1;
wire [7:0] input_y=pixel_y-Y0;
wire [7:0] input_x=pixel_x-X0;
wire [9:0] gray_sum [0:3];
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : gray
 assign gray_sum[lane]={2'b0,rgb[95-lane*24-:8]}+{1'b0,rgb[87-lane*24-:8],1'b0}+{2'b0,rgb[79-lane*24-:8]};
end endgenerate
function [12:0] address;
 input [7:0] ax,ay;
 begin address=({5'b0,ay}<<5)+({5'b0,ay}<<4)+(ax>>2);end
endfunction
integer k;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n)begin cap_write<=0;cap_last<=0;cap_addr<=0;cap_data<=0;end
 else begin
  cap_write<=pixel_accept && in_search && !invalidate && !frame_start;
  cap_last<=pixel_x==X1-4 && pixel_y==Y1-1;
  cap_addr<=address(input_x,input_y);
  for(k=0;k<4;k=k+1)begin cap_data[k]<=gray_sum[k][9:2]>=FOREGROUND;cap_data[k+4]<=gray_sum[k][9:2]<=FOREGROUND;end
 end
end
reg [12:0] mem_addr;reg [7:0] mem_data,mem_q;reg mem_write;
reg [8:0] q_read,q_write_addr;reg [15:0] q_data,q_q;reg q_write;
// Independent synchronous capture/read-modify-write port; processing starts
// after capture completes. Infer RAM, never reset the arrays.
always @(posedge clk)begin
 if(cap_write && !invalidate && !frame_start) mask[cap_addr]<=cap_data;
 if(mem_write && !invalidate && !frame_start) mask[mem_addr]<=mem_data;
 mem_q<=mask[mem_addr];
 if(q_write) queue[q_write_addr]<=q_data;
 q_q<=queue[q_read];
end
localparam IDLE=0,SCAN_REQ=1,SCAN_WAIT=2,SCAN_CHECK=3,SEED_MARK=4,
 POP_REQ=5,POP_WAIT=6,POP_VALUE=7,NEIGH_REQ=8,NEIGH_WAIT=9,NEIGH_CHECK=10,
 NEIGH_MARK=11,NEIGH_NEXT=12,AREA_CALC=13,COMPARE=14,
 REF_REQ=15,REF_WAIT=16,REF_CHECK=17,FINISHED=18,SCALE=19;
reg [4:0] phase;
reg [7:0] sx,sy,cx,cy,nx,ny,xmin,xmax,ymin,ymax;
reg [1:0] direction;
reg [8:0] q_head,q_tail;reg [9:0] q_count;
reg [14:0] component_count;reg border,any_foreground;
reg [15:0] component_area;
wire [8:0] center_x=({1'b0,xmin}+xmax)>>1,center_y=({1'b0,ymin}+ymax)>>1;
wire [8:0] dx=center_x>96 ? center_x-96 : 96-center_x;
wire [8:0] dy=center_y>72 ? center_y-72 : 72-center_y;
wire [9:0] distance={1'b0,dx}+dy;
wire [8:0] width_now={1'b0,xmax}-xmin+1'b1,height_now={1'b0,ymax}-ymin+1'b1;
reg [8:0] long_side,short_side;
// Register constant-scaled terms separately from bbox subtraction/sorting.
// This closes the CSI timing path without changing any shape limit.
reg [19:0] fg20,area17,fg5,area3,fg10,area9;
reg [13:0] long20,short21,short31,long5,short7;
// Same size/aspect/fill limits as V5; only separate blobs and tolerate position.
wire present_match=long_side>=52 && long_side<=78 && short_side>=40 && short_side<=72 &&
 long20>=short21 && long20<=short31 && fg20>=area17;
wire circular=long5<=short7 && fg5>=area3 && fg10<=area9;
wire empty_match=circular && long_side>=10 && long_side<=26 && short_side>=8 && short_side<=24;
wire sprocket_match=circular && long_side>=28 && long_side<=46 && short_side>=20 && short_side<=42;
reg found;reg [9:0] best_distance;
reg [14:0] best_count;reg [7:0] best_xmin,best_xmax,best_ymin,best_ymax;
reg [1:0] best_state;
reg [11:0] ref_index;reg [10:0] left_dark,right_dark;
wire [8:0] best_cx=({1'b0,best_xmin}+best_xmax)>>1,best_cy=({1'b0,best_ymin}+best_ymax)>>1;
wire ref_right=ref_index>=1280;
wire [7:0] ref_x=ref_right ? best_cx+40+ref_index[3:0] : best_cx-56+ref_index[3:0];
wire [7:0] ref_y=best_cy-40+(ref_right ? ((ref_index-1280)>>4) : (ref_index>>4));
reg [1:0] ref_lane;
reg [8:0] trial_x,trial_y;reg neighbor_ok;
always @*begin
 trial_x={1'b0,cx};trial_y={1'b0,cy};neighbor_ok=1;
 case(direction)
  0:begin trial_x={1'b0,cx}-1'b1;neighbor_ok=cx!=0;end
  1:begin trial_x={1'b0,cx}+1'b1;neighbor_ok=cx<W-1;end
  2:begin trial_y={1'b0,cy}-1'b1;neighbor_ok=cy!=0;end
  3:begin trial_y={1'b0,cy}+1'b1;neighbor_ok=cy<H-1;end
 endcase
end
// Seed only the central 80x64 anchor. Flood-fill still measures the complete
// blob across the full 192x144 mask. This avoids spending the lower-row time
// budget scanning border background and neighboring, out-of-anchor objects.
task advance_scan;
 begin
  if(sx==135)begin
   sx<=56;
   if(sy==103)begin
    if(found)begin ref_index<=0;left_dark<=0;right_dark<=0;phase<=REF_REQ;end
    else begin ready<=1;sample_new<=1;located<=0;state<=any_foreground ? 0 : 1;phase<=FINISHED;end
   end else begin sy<=sy+1'b1;phase<=SCAN_REQ;end
  end else begin sx<=sx+1'b1;phase<=SCAN_REQ;end
 end
endtask
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  ready<=0;sample_new<=0;located<=0;state<=1;foreground_count<=0;box_width<=0;box_height<=0;
  box_x0<=0;box_x1<=0;box_y0<=0;box_y1<=0;seen<=0;cap_count<=0;capture_foreground<=0;phase<=IDLE;
  mem_addr<=0;mem_data<=0;mem_write<=0;q_read<=0;q_write_addr<=0;q_data<=0;q_write<=0;
  sx<=0;sy<=0;cx<=0;cy<=0;nx<=0;ny<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;direction<=0;
  q_head<=0;q_tail<=0;q_count<=0;component_count<=0;border<=0;any_foreground<=0;component_area<=0;long_side<=0;short_side<=0;fg20<=0;area17<=0;fg5<=0;area3<=0;fg10<=0;area9<=0;long20<=0;short21<=0;short31<=0;long5<=0;short7<=0;
  found<=0;best_distance<=1023;best_count<=0;best_xmin<=0;best_xmax<=0;best_ymin<=0;best_ymax<=0;best_state<=1;
  ref_index<=0;left_dark<=0;right_dark<=0;ref_lane<=0;
 end else begin
  sample_new<=0;mem_write<=0;q_write<=0;
  if(frame_start || invalidate)begin ready<=0;located<=0;state<=1;phase<=IDLE;seen<=0;cap_count<=0;capture_foreground<=0;end
  else if(pixel_sof)begin
   seen<=1;cap_count<=0;capture_foreground<=0;ready<=0;located<=0;state<=1;phase<=IDLE;any_foreground<=0;
   found<=0;best_distance<=1023;best_count<=0;foreground_count<=0;box_width<=0;box_height<=0;
  end else if(cap_write && seen)begin
   if(|cap_data[3:0])any_foreground<=1;
   cap_count<=cap_count+1'b1;capture_foreground<=capture_foreground+cap_fg;
   if(cap_last)begin
    if(cap_count==WORDS-1)begin
     if(capture_foreground+cap_fg==0 || capture_foreground+cap_fg==W*H)begin
      ready<=1;sample_new<=1;located<=0;state<=capture_foreground+cap_fg==0 ? 1 : 0;phase<=FINISHED;
     end else begin sx<=56;sy<=40;phase<=SCAN_REQ;end
    end
    else begin ready<=1;sample_new<=1;state<=1;located<=0;phase<=FINISHED;end
   end
  end else case(phase)
   SCAN_REQ:begin mem_addr<=address(sx,sy);phase<=SCAN_WAIT;end
   SCAN_WAIT:phase<=SCAN_CHECK;
   SCAN_CHECK:begin
    if(mem_q[sx[1:0]])begin
     mem_data<=mem_q & ~(8'b1<<sx[1:0]);mem_write<=1;
     xmin<=sx;xmax<=sx;ymin<=sy;ymax<=sy;component_count<=1;
     border<=sx==0 || sx==W-1 || sy==0 || sy==H-1;
     q_write_addr<=0;q_data<={sy,sx};q_write<=1;q_head<=0;q_tail<=1;q_count<=1;phase<=SEED_MARK;
    end else advance_scan;
   end
   SEED_MARK:phase<=POP_REQ;
   POP_REQ:begin q_read<=q_head;phase<=POP_WAIT;end
   POP_WAIT:phase<=POP_VALUE;
   POP_VALUE:begin cx<=q_q[7:0];cy<=q_q[15:8];q_head<=q_head+1'b1;q_count<=q_count-1'b1;direction<=0;phase<=NEIGH_REQ;end
   NEIGH_REQ:begin
    if(neighbor_ok)begin nx<=trial_x[7:0];ny<=trial_y[7:0];mem_addr<=address(trial_x[7:0],trial_y[7:0]);phase<=NEIGH_WAIT;end
    else phase<=NEIGH_NEXT;
   end
   NEIGH_WAIT:phase<=NEIGH_CHECK;
   NEIGH_CHECK:begin
    if(mem_q[nx[1:0]])begin
     if(q_count==512 || component_count==W*H)begin ready<=1;sample_new<=1;state<=1;located<=0;phase<=FINISHED;end
     else begin
      mem_data<=mem_q & ~(8'b1<<nx[1:0]);mem_write<=1;
      q_write_addr<=q_tail;q_data<={ny,nx};q_write<=1;q_tail<=q_tail+1'b1;q_count<=q_count+1'b1;
      component_count<=component_count+1'b1;
      if(nx<xmin)xmin<=nx;if(nx>xmax)xmax<=nx;if(ny<ymin)ymin<=ny;if(ny>ymax)ymax<=ny;
      if(nx==0 || nx==W-1 || ny==0 || ny==H-1)border<=1;
      phase<=NEIGH_MARK;
     end
    end else phase<=NEIGH_NEXT;
   end
   NEIGH_MARK:phase<=NEIGH_NEXT;
   NEIGH_NEXT:begin
    if(direction==3)begin
     if(q_count==0)phase<=AREA_CALC;else phase<=POP_REQ;
    end else begin direction<=direction+1'b1;phase<=NEIGH_REQ;end
   end
   AREA_CALC:begin component_area<=width_now*height_now;
    long_side<=width_now>height_now ? width_now : height_now;short_side<=width_now<height_now ? width_now : height_now;phase<=SCALE;end
   SCALE:begin
    fg20<={5'b0,component_count}*20'd20;area17<={4'b0,component_area}*20'd17;
    fg5<={5'b0,component_count}*20'd5;area3<={4'b0,component_area}*20'd3;
    fg10<={5'b0,component_count}*20'd10;area9<={4'b0,component_area}*20'd9;
    long20<={5'b0,long_side}*14'd20;short21<={5'b0,short_side}*14'd21;short31<={5'b0,short_side}*14'd31;
    long5<={5'b0,long_side}*14'd5;short7<={5'b0,short_side}*14'd7;phase<=COMPARE;
   end
   COMPARE:begin
    if(!border && component_count>=8 && width_now>=6 && height_now>=6 && dx<=32 && dy<=24 &&
     (!found || distance<best_distance || (distance==best_distance && component_count>best_count)))begin
     found<=1;best_distance<=distance;best_count<=component_count;
     best_xmin<=xmin;best_xmax<=xmax;best_ymin<=ymin;best_ymax<=ymax;
     best_state<=sprocket_match ? 0 : present_match ? 2 : empty_match ? 3 : 1;
    end
    advance_scan;
   end
   REF_REQ:begin mem_addr<=address(ref_x,ref_y);ref_lane<=ref_x[1:0];phase<=REF_WAIT;end
   REF_WAIT:phase<=REF_CHECK;
   REF_CHECK:begin
    if(mem_q[4+ref_lane])begin if(ref_right)right_dark<=right_dark+1'b1;else left_dark<=left_dark+1'b1;end
    if(ref_index==2559)begin
     ready<=1;sample_new<=1;located<=1;
     state<=left_dark>=960 && (right_dark+mem_q[4+ref_lane])>=960 ? best_state : 0;
     foreground_count<=best_count>8191 ? 13'd8191 : best_count[12:0];
     // Diagnostic sizes/counts saturate for rejected large blobs; matched shapes fit exactly.
     box_width<=best_xmax-best_xmin+1>127 ? 127 : best_xmax-best_xmin+1'b1;
     box_height<=best_ymax-best_ymin+1>127 ? 127 : best_ymax-best_ymin+1'b1;
     box_x0<=X0+best_xmin-2;box_x1<=X0+best_xmax+3;
     box_y0<=Y0+best_ymin-2;box_y1<=Y0+best_ymax+3;phase<=FINISHED;
    end else begin ref_index<=ref_index+1'b1;phase<=REF_REQ;end
   end
   default:begin end
  endcase
 end
end
endmodule
