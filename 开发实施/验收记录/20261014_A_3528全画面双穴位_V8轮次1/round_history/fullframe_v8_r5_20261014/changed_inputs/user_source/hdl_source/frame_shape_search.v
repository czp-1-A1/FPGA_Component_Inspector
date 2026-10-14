// Full-frame PPC4 RGB detector. Native frame guard proves input completeness.
// Two independently classified 3528 bodies/pockets; no fixed search window.
// A shared flood-fill engine runs during vertical blanking, without video backpressure.
module frame_shape_search #(
 parameter [7:0] FOREGROUND=100
)(
 input wire clk,rst_n,frame_start,pixel_sof,pixel_accept,invalidate,
 input wire [10:0] pixel_x,input wire [9:0] pixel_y,input wire [95:0] rgb,
 output reg ready,sample_new,located,output reg [1:0] state,
 output reg [12:0] foreground_count,output reg [6:0] box_width,box_height,
 output reg [10:0] box_x0,box_x1,output reg [9:0] box_y0,box_y1,
 output reg review_required,
 // Two 76-bit records, left object in [75:0]. Valid,class,reason,FG,W,H,x0,x1,y0,y1.
 // reason[3:0]: side reference, fill, aspect, size; these are model diagnostics.
 output reg [151:0] objects
);
// Average each 2x2 source block; every source pixel contributes. Detection
// covers the complete 1024x600 image, at 512x300 internal resolution.
localparam W=512,H=300,WORDS=W*H/4;
reg [7:0] mask [0:38399];reg [17:0] queue [0:1023];
reg [17:0] pair_line [0:255];reg [17:0] pair_q,pair_d;
reg [10:0] x_d;reg [9:0] y_d;reg accept_d;
wire [9:0] gray_sum [0:3];
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : gray
 assign gray_sum[lane]={2'b0,rgb[95-lane*24-:8]}+{1'b0,rgb[87-lane*24-:8],1'b0}+{2'b0,rgb[79-lane*24-:8]};
end endgenerate
wire [8:0] pair0={1'b0,gray_sum[0][9:2]}+gray_sum[1][9:2];
wire [8:0] pair1={1'b0,gray_sum[2][9:2]}+gray_sum[3][9:2];
wire [9:0] block0={1'b0,pair_d[8:0]}+pair_q[8:0];
wire [9:0] block1={1'b0,pair_d[17:9]}+pair_q[17:9];
wire [1:0] half_fg={block1[9:2]>=FOREGROUND,block0[9:2]>=FOREGROUND};
wire [1:0] half_dark={block1[9:2]<=FOREGROUND,block0[9:2]<=FOREGROUND};
reg [1:0] first_fg,first_dark;
reg [15:0] cap_addr;reg [7:0] cap_data;reg cap_write,cap_last,seen;
reg [15:0] cap_count;reg [17:0] capture_foreground;
wire [2:0] cap_fg={2'b0,cap_data[0]}+{2'b0,cap_data[1]}+{2'b0,cap_data[2]}+{2'b0,cap_data[3]};
function [15:0] address;
 input [8:0] ax,ay;
 begin address={ay,7'b0}+(ax>>2);end
endfunction
always @(posedge clk)begin
 if(pixel_accept && !pixel_y[0])pair_line[pixel_x[9:2]]<={pair1,pair0};
 pair_q<=pair_line[pixel_x[9:2]];
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin accept_d<=0;x_d<=0;y_d<=0;pair_d<=0;first_fg<=0;first_dark<=0;cap_write<=0;cap_last<=0;cap_addr<=0;cap_data<=0;end
 else begin
  accept_d<=pixel_accept && !invalidate && !frame_start;x_d<=pixel_x;y_d<=pixel_y;pair_d<={pair1,pair0};
  cap_write<=accept_d && y_d[0] && x_d[2] && !invalidate && !frame_start;
  cap_last<=x_d==1020 && y_d==599;cap_addr<=address(x_d[10:1],y_d[9:1]);
  if(accept_d && y_d[0] && !x_d[2])begin first_fg<=half_fg;first_dark<=half_dark;end
  cap_data<={half_dark,first_dark,half_fg,first_fg};
  if(frame_start || invalidate)begin accept_d<=0;cap_write<=0;end
 end
end
reg [15:0] mem_addr,mem_write_addr;reg [7:0] mem_data,mem_q;reg mem_write;
reg [9:0] q_read,q_write_addr;reg [17:0] q_data,q_q;reg q_write;
// Independent synchronous capture/read-modify-write port; processing starts
// after capture completes. Infer RAM, never reset the arrays.
always @(posedge clk)begin
 if(!invalidate && !frame_start)begin
  if(cap_write) mask[cap_addr]<=cap_data;
  else if(mem_write) mask[mem_write_addr]<=mem_data;
 end
 // Explicit forwarding makes a read of the just-cleared packed word independent
 // of the device RAM's read-during-write mode. Read and mark use separate ports.
 mem_q<=mem_write && mem_addr==mem_write_addr ? mem_data : mask[mem_addr];
 if(q_write) queue[q_write_addr]<=q_data;
 q_q<=queue[q_read];
end
localparam IDLE=0,SCAN_REQ=1,SCAN_WAIT=2,SCAN_CHECK=3,SEED_MARK=4,
 POP_REQ=5,POP_WAIT=6,POP_VALUE=7,NEIGH_REQ=8,NEIGH_WAIT=9,NEIGH_CHECK=10,
 NEIGH_NEXT=12,AREA_CALC=13,COMPARE=14,
 REF_REQ=15,REF_WAIT=16,REF_CHECK=17,FINISHED=18,SCALE=19,PUBLISH=20;
reg [4:0] phase;
reg [8:0] sx,sy,cx,cy,nx,ny,xmin,xmax,ymin,ymax;
reg [1:0] direction;
reg [9:0] q_head,q_tail;reg [10:0] q_count;
reg [17:0] component_count;reg border;
reg [17:0] component_area;
wire [9:0] center_x=({1'b0,xmin}+xmax)>>1,center_y=({1'b0,ymin}+ymax)>>1;
wire [9:0] dx=center_x>256 ? center_x-256 : 256-center_x;
wire [9:0] dy=center_y>150 ? center_y-150 : 150-center_y;
wire [10:0] distance={1'b0,dx}+dy;
wire [9:0] width_now={1'b0,xmax}-xmin+1'b1,height_now={1'b0,ymax}-ymin+1'b1;
reg [9:0] long_side,short_side;
// Register constant-scaled terms separately from bbox subtraction/sorting.
// This closes the CSI timing path without changing any shape limit.
reg [21:0] fg20,area17,fg5,area3,fg10,area9,fg4;
reg [13:0] long20,short21,short31,long5,short7,short9;
// Keep the original strict model. The wider envelope only asserts presence
// with CHECK; it is not an alignment or installation-quality measurement.
wire present_match=long_side>=26 && long_side<=39 && short_side>=20 && short_side<=36 &&
 long20>=short21 && long20<=short31 && fg20>=area17;
wire present_review_match=long_side>=26 && long_side<=43 && short_side>=20 && short_side<=38 &&
 long20>=short21 && long5<=short9 && fg4>=area3;
wire circular=long5<=short7 && fg5>=area3 && fg10<=area9;
wire empty_match=circular && long_side>=5 && long_side<=13 && short_side>=4 && short_side<=12;
wire sprocket_match=circular && long_side>=14 && long_side<=23 && short_side>=10 && short_side<=21;
reg found;reg [10:0] best_distance;
reg [17:0] best_count;reg [8:0] best_xmin,best_xmax,best_ymin,best_ymax;
reg [1:0] best_state;
reg found_second;reg [10:0] second_distance;reg [17:0] second_count;
reg [8:0] second_xmin,second_xmax,second_ymin,second_ymax;
reg [1:0] second_state;reg [3:0] best_reason,second_reason;
wire [1:0] candidate_state=sprocket_match ? 0 : (present_match || present_review_match) ? 2 : empty_match ? 3 : 1;
wire [3:0] candidate_reason={1'b0,fg20<area17,long20<short21 || long20>short31,
 long_side<26 || long_side>39 || short_side<20 || short_side>36};
// Prefer recognized bodies/empty pockets over feed holes and unclassified blobs.
wire candidate_preferred=candidate_state>=2;
wire best_preferred=best_state>=2,second_preferred=second_state>=2;
wire before_best=!found || (candidate_preferred && !best_preferred) ||
 ((candidate_preferred==best_preferred) && (distance<best_distance || (distance==best_distance && component_count>best_count)));
wire before_second=!found_second || (candidate_preferred && !second_preferred) ||
 (candidate_preferred==second_preferred && (distance<second_distance || (distance==second_distance && component_count>second_count)));
reg [8:0] left_dark,right_dark;
wire [9:0] best_cx=({1'b0,best_xmin}+best_xmax)>>1,best_cy=({1'b0,best_ymin}+best_ymax)>>1;
reg ref_second,ref_side,ref_valid,pair_selected;reg [2:0] ref_word;reg [6:0] ref_row;
wire [9:0] ref_cx=ref_second ? ({1'b0,second_xmin}+second_xmax)>>1 : best_cx;
wire [9:0] ref_cy=ref_second ? ({1'b0,second_ymin}+second_ymax)>>1 : best_cy;
wire signed [10:0] strip_start=$signed({1'b0,ref_cx})+(ref_side ? 11'sd20 : -11'sd28);
wire signed [10:0] word_x=(strip_start & -11'sd4)+$signed({6'b0,ref_word,2'b0});
wire [9:0] word_y=ref_cy-20+ref_row;
reg [2:0] dark_word;integer dark_lane;
always @*begin
 dark_word=0;
 for(dark_lane=0;dark_lane<4;dark_lane=dark_lane+1)
  if(ref_valid && word_x+dark_lane>=strip_start && word_x+dark_lane<strip_start+8)
   dark_word=dark_word+mem_q[4+dark_lane];
end
wire pair_ok=found_second && best_state!=0 && second_state!=0;
wire [6:0] best_w=(best_xmax-best_xmin+1)*2>127 ? 127 : (best_xmax-best_xmin+1)*2;
wire [6:0] best_h=(best_ymax-best_ymin+1)*2>127 ? 127 : (best_ymax-best_ymin+1)*2;
wire [6:0] second_w=(second_xmax-second_xmin+1)*2>127 ? 127 : (second_xmax-second_xmin+1)*2;
wire [6:0] second_h=(second_ymax-second_ymin+1)*2>127 ? 127 : (second_ymax-second_ymin+1)*2;
wire [10:0] best_bx0=(best_xmin*2>1 ? best_xmin*2-2 : 0),best_bx1=(best_xmax*2+4<1024 ? best_xmax*2+4 : 1024),second_bx0=(second_xmin*2>1 ? second_xmin*2-2 : 0),second_bx1=(second_xmax*2+4<1024 ? second_xmax*2+4 : 1024);
wire [9:0] best_by0=(best_ymin*2>1 ? best_ymin*2-2 : 0),best_by1=(best_ymax*2+4<600 ? best_ymax*2+4 : 600),second_by0=(second_ymin*2>1 ? second_ymin*2-2 : 0),second_by1=(second_ymax*2+4<600 ? second_ymax*2+4 : 600);
wire [75:0] record_best={found,best_state,best_reason,(best_count>2047 ? 13'd8191 : {best_count[10:0],2'b0}),best_w,best_h,best_bx0,best_bx1,best_by0,best_by1};
wire [75:0] record_second={pair_selected,second_state,second_reason,(second_count>2047 ? 13'd8191 : {second_count[10:0],2'b0}),second_w,second_h,second_bx0,second_bx1,second_by0,second_by1};
reg [9:0] trial_x,trial_y;reg neighbor_ok;
always @*begin
 trial_x={1'b0,cx};trial_y={1'b0,cy};neighbor_ok=1;
 case(direction)
  0:begin trial_x={1'b0,cx}-1'b1;neighbor_ok=cx!=0;end
  1:begin trial_x={1'b0,cx}+1'b1;neighbor_ok=cx<W-1;end
  2:begin trial_y={1'b0,cy}-1'b1;neighbor_ok=cy!=0;end
  3:begin trial_y={1'b0,cy}+1'b1;neighbor_ok=cy<H-1;end
 endcase
end
// Scan every packed word in the full-frame mask, including the image edges.
task advance_scan;
 begin
  if(sx>=508)begin
   sx<=0;
   if(sy==299)begin
    if(found)begin pair_selected<=pair_ok;ref_second<=0;ref_side<=0;ref_word<=0;ref_row<=0;left_dark<=0;right_dark<=0;phase<=REF_REQ;end
    else begin ready<=1;sample_new<=1;located<=0;state<=0;phase<=FINISHED;end
   end else begin sy<=sy+1'b1;phase<=SCAN_REQ;end
  end else begin sx<=(sx & 9'h1fc)+4;phase<=SCAN_REQ;end
 end
endtask
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  ready<=0;sample_new<=0;located<=0;state<=1;review_required<=0;objects<=0;foreground_count<=0;box_width<=0;box_height<=0;
  box_x0<=0;box_x1<=0;box_y0<=0;box_y1<=0;seen<=0;cap_count<=0;capture_foreground<=0;phase<=IDLE;
  mem_addr<=0;mem_write_addr<=0;mem_data<=0;mem_write<=0;q_read<=0;q_write_addr<=0;q_data<=0;q_write<=0;
  sx<=0;sy<=0;cx<=0;cy<=0;nx<=0;ny<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;direction<=0;
  q_head<=0;q_tail<=0;q_count<=0;component_count<=0;border<=0;component_area<=0;long_side<=0;short_side<=0;fg20<=0;area17<=0;fg5<=0;area3<=0;fg10<=0;area9<=0;fg4<=0;long20<=0;short21<=0;short31<=0;long5<=0;short7<=0;short9<=0;
  found<=0;best_distance<=2047;best_count<=0;best_xmin<=0;best_xmax<=0;best_ymin<=0;best_ymax<=0;best_state<=1;
  found_second<=0;second_distance<=2047;second_count<=0;second_xmin<=0;second_xmax<=0;second_ymin<=0;second_ymax<=0;second_state<=1;best_reason<=0;second_reason<=0;
  ref_second<=0;ref_side<=0;ref_word<=0;ref_row<=0;ref_valid<=0;pair_selected<=0;
  left_dark<=0;right_dark<=0;
 end else begin
  sample_new<=0;mem_write<=0;q_write<=0;
  if(frame_start || invalidate)begin ready<=0;located<=0;state<=1;review_required<=0;objects<=0;phase<=IDLE;seen<=0;cap_count<=0;capture_foreground<=0;end
  else if(pixel_sof)begin
   seen<=1;cap_count<=0;capture_foreground<=0;ready<=0;located<=0;state<=1;review_required<=0;objects<=0;phase<=IDLE;
   found<=0;best_distance<=2047;best_count<=0;foreground_count<=0;box_width<=0;box_height<=0;
   found_second<=0;second_distance<=2047;second_count<=0;best_reason<=0;second_reason<=0;
  end else if(cap_write && seen)begin
   cap_count<=cap_count+1'b1;capture_foreground<=capture_foreground+cap_fg;
   if(cap_last)begin
    if(cap_count==WORDS-1)begin
     if(capture_foreground+cap_fg==0 || capture_foreground+cap_fg==W*H)begin
      ready<=1;sample_new<=1;located<=0;state<=0;phase<=FINISHED;
     end else begin sx<=0;sy<=0;phase<=SCAN_REQ;end
    end
    else begin ready<=1;sample_new<=1;state<=1;located<=0;phase<=FINISHED;end
   end
  end else case(phase)
   SCAN_REQ:begin mem_addr<=address(sx,sy);phase<=SCAN_WAIT;end
   SCAN_WAIT:phase<=SCAN_CHECK;
   SCAN_CHECK:begin
    if(|mem_q[3:0])begin
     // Lowest remaining lane; return to this same word after the component.
     nx<=(sx & 9'h1fc)+(mem_q[0] ? 0 : mem_q[1] ? 1 : mem_q[2] ? 2 : 3);phase<=SEED_MARK;
    end else advance_scan;
   end
   SEED_MARK:begin
    mem_write_addr<=mem_addr;mem_data<=mem_q & ~(8'b1<<nx[1:0]);mem_write<=1;
    xmin<=nx;xmax<=nx;ymin<=sy;ymax<=sy;component_count<=1;border<=nx==0 || nx==W-1 || sy==0 || sy==H-1;
    q_write_addr<=0;q_data<={sy,nx};q_write<=1;q_head<=0;q_tail<=1;q_count<=1;phase<=POP_REQ;
   end
   POP_REQ:begin q_read<=q_head;phase<=POP_WAIT;end
   POP_WAIT:phase<=POP_VALUE;
   POP_VALUE:begin cx<=q_q[8:0];cy<=q_q[17:9];q_head<=q_head+1'b1;q_count<=q_count-1'b1;direction<=0;phase<=NEIGH_REQ;end
   NEIGH_REQ:begin
    if(neighbor_ok)begin nx<=trial_x[8:0];ny<=trial_y[8:0];mem_addr<=address(trial_x[8:0],trial_y[8:0]);phase<=NEIGH_WAIT;end
    else phase<=NEIGH_NEXT;
   end
   NEIGH_WAIT:phase<=NEIGH_CHECK;
   NEIGH_CHECK:begin
    if(mem_q[nx[1:0]])begin
     if(q_count==1024 || component_count==W*H)begin ready<=1;sample_new<=1;state<=1;located<=0;phase<=FINISHED;end
     else begin
      mem_write_addr<=mem_addr;mem_data<=mem_q & ~(8'b1<<nx[1:0]);mem_write<=1;
      q_write_addr<=q_tail;q_data<={ny,nx};q_write<=1;q_tail<=q_tail+1'b1;q_count<=q_count+1'b1;
      component_count<=component_count+1'b1;
      if(nx<xmin)xmin<=nx;if(nx>xmax)xmax<=nx;if(ny<ymin)ymin<=ny;if(ny>ymax)ymax<=ny;
      if(nx==0 || nx==W-1 || ny==0 || ny==H-1)border<=1;
     end
    end
    if(!(mem_q[nx[1:0]] && (q_count==1024 || component_count==W*H)))begin
     if(direction==3)begin
      if(q_count==0 && !mem_q[nx[1:0]])phase<=AREA_CALC;else phase<=POP_REQ;
     end else begin
      direction<=direction+1'b1;
      // Issue the next read now; the preceding mark has its own write address.
      case(direction)
       0:begin nx<=cx+1'b1;ny<=cy;mem_addr<=address(cx+1'b1,cy);phase<=cx<W-1 ? NEIGH_WAIT : NEIGH_NEXT;end
       1:begin nx<=cx;ny<=cy-1'b1;mem_addr<=address(cx,cy-1'b1);phase<=cy!=0 ? NEIGH_WAIT : NEIGH_NEXT;end
       2:begin nx<=cx;ny<=cy+1'b1;mem_addr<=address(cx,cy+1'b1);phase<=cy<H-1 ? NEIGH_WAIT : NEIGH_NEXT;end
      endcase
     end
    end
   end
   NEIGH_NEXT:begin
    if(direction==3)begin if(q_count==0)phase<=AREA_CALC;else phase<=POP_REQ;end
    else begin direction<=direction+1'b1;phase<=NEIGH_REQ;end
   end
   AREA_CALC:begin component_area<=width_now*height_now;
    long_side<=width_now>height_now ? width_now : height_now;short_side<=width_now<height_now ? width_now : height_now;phase<=SCALE;end
   SCALE:begin
    fg20<={4'b0,component_count}*22'd20;area17<={4'b0,component_area}*22'd17;
    fg5<={4'b0,component_count}*22'd5;area3<={4'b0,component_area}*22'd3;
    fg10<={4'b0,component_count}*22'd10;area9<={4'b0,component_area}*22'd9;
    fg4<={2'b0,component_count,2'b0};
    long20<={4'b0,long_side}*14'd20;short21<={4'b0,short_side}*14'd21;short31<={4'b0,short_side}*14'd31;
    long5<={4'b0,long_side}*14'd5;short7<={4'b0,short_side}*14'd7;short9<={4'b0,short_side}*14'd9;phase<=COMPARE;
   end
   COMPARE:begin
    if(!border && component_count>=8 && width_now>=3 && height_now>=3)begin
     if(before_best)begin
      if(found)begin
       found_second<=1;second_distance<=best_distance;second_count<=best_count;
       second_xmin<=best_xmin;second_xmax<=best_xmax;second_ymin<=best_ymin;second_ymax<=best_ymax;second_state<=best_state;second_reason<=best_reason;
      end
      found<=1;best_distance<=distance;best_count<=component_count;
      best_xmin<=xmin;best_xmax<=xmax;best_ymin<=ymin;best_ymax<=ymax;
      best_state<=candidate_state;best_reason<=candidate_reason;
     end else if(before_second)begin
      found_second<=1;second_distance<=distance;second_count<=component_count;
      second_xmin<=xmin;second_xmax<=xmax;second_ymin<=ymin;second_ymax<=ymax;second_state<=candidate_state;second_reason<=candidate_reason;
     end
    end
    phase<=SCAN_REQ;
   end
   REF_REQ:begin
    mem_addr<=address(word_x[8:0],word_y[8:0]);ref_valid<=word_x>=0 && word_x<W && word_y<H;phase<=REF_WAIT;
   end
   REF_WAIT:phase<=REF_CHECK;
   REF_CHECK:begin
    if(ref_side)right_dark<=right_dark+dark_word;else left_dark<=left_dark+dark_word;
    if(ref_side && ref_word==2 && ref_row==39)begin
     // Neighboring parts or a tape end may contaminate the side strips.
     // Preserve a recognized 3528 body, but do not assert quality is normal.
     if(ref_second)begin
      if(second_state==2)second_reason[3]<=left_dark<240 || right_dark+dark_word<240;
      else begin second_reason<=0;if(left_dark<240 || right_dark+dark_word<240)second_state<=0;end
      phase<=PUBLISH;
     end else begin
      if(best_state==2)best_reason[3]<=left_dark<240 || right_dark+dark_word<240;
      else begin best_reason<=0;if(left_dark<240 || right_dark+dark_word<240)best_state<=0;end
      if(pair_selected)begin ref_second<=1;ref_side<=0;ref_word<=0;ref_row<=0;left_dark<=0;right_dark<=0;phase<=REF_REQ;end
      else phase<=PUBLISH;
     end
    end else begin
     if(ref_word==2)begin ref_word<=0;if(ref_row==39)begin ref_row<=0;ref_side<=1;end else ref_row<=ref_row+1'b1;end
     else ref_word<=ref_word+1'b1;
     phase<=REF_REQ;
    end
   end
   PUBLISH:begin
     ready<=1;sample_new<=1;located<=1;state<=best_state;review_required<=best_state==2 && |best_reason;
     objects<=pair_selected ? (best_xmin<second_xmin ? {record_second,record_best} : {record_best,record_second}) : {76'd0,record_best};
     foreground_count<=best_count>2047 ? 13'd8191 : {best_count[10:0],2'b0};
     // Diagnostic sizes/counts saturate for rejected large blobs; matched shapes fit exactly.
     box_width<=best_w;box_height<=best_h;
     box_x0<=(best_xmin*2>1 ? best_xmin*2-2 : 0);box_x1<=(best_xmax*2+4<1024 ? best_xmax*2+4 : 1024);
     box_y0<=(best_ymin*2>1 ? best_ymin*2-2 : 0);box_y1<=(best_ymax*2+4<600 ? best_ymax*2+4 : 600);phase<=FINISHED;
   end
   default:begin end
  endcase
 end
end
endmodule
