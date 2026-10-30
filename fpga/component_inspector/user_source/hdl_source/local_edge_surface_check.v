// R22 local Sobel proof. One existing five-bit gray cache serves BOTH body
// surface means and aperture edges. No display-mode input or frame prediction.
// Four 3x3 kernels are read serially at actual bbox side midpoints. Sobel signs
// must face a bright measured object and its darker surroundings.
module local_edge_surface_check #(
 parameter WIDTH=1280,HEIGHT=720,FOREGROUND=100,STANDING_REVIEW=0,
 parameter MIN_GRADIENT=8,MIN_SIDES=3,TRACE=0
)(
 input wire clk,rst_n,cancel,write_enable,measure,measure_empty,
 input wire [10:0] write_x,input wire [9:0] write_y,input wire [31:0] write_data,
 input wire [9:0] xmin,xmax,ymin,ymax,
 output reg ready,normal,empty_ok,output reg [31:0] edge_strengths,
 input wire trace_enable,output wire [100:0] trace_metrics
);
localparam X0=((WIDTH*5/16-16)/8)*8,X1=((WIDTH*11/16+23)/8)*8;
localparam Y0=((HEIGHT/3-16)/2)*2,Y1=((HEIGHT*5/6+17)/2)*2;
localparam COLS=(X1-X0)/8,WORDS=COLS*(Y1-Y0)/2,AB=$clog2(WORDS);
wire capture=write_enable && write_x>=X0 && write_x<X1 && write_y>=Y0 && write_y<Y1;
wire [AB-1:0] write_address=((write_y-Y0)>>1)*COLS+((write_x-X0)>>3);
wire [19:0] packed_gray={write_data[31:27],write_data[23:19],write_data[15:11],write_data[7:3]};
reg [19:0] memory[0:WORDS-1];reg [19:0] q;reg [AB-1:0] read_address;
always @(posedge clk)begin
 if(capture && !cancel)memory[write_address]<=packed_gray;
 q<=memory[read_address];
end
reg [AB:0] captured;
wire [10:0] width_now={1'b0,xmax}-xmin+1'b1,height_now={1'b0,ymax}-ymin+1'b1;
wire [10:0] requested_x={1'b0,xmin}+(width_now>>1),requested_y={1'b0,ymin}+(height_now>>1);
wire in_cache=xmin>=X0/2+1 && xmax+1<X1/2 && ymin>=Y0/2+1 && ymax+1<Y1/2;
wire body_measurable=width_now>=16 && height_now>=16 &&
 requested_x>=X0/2+8 && requested_x+8<=X1/2 && requested_y>=Y0/2+8 && requested_y+8<=Y1/2;
wire empty_measurable=width_now>=3 && width_now<=9 && height_now>=3 && height_now<=9;
wire measurable=captured==WORDS && in_cache && (measure_empty ? empty_measurable : body_measurable);
reg [10:0] center_x,center_y,cell_x,cell_y;
reg [9:0] box_x0,box_x1,box_y0,box_y1;
reg [3:0] phase;reg [2:0] feature;reg [5:0] sample;reg [1:0] byte_index;
reg [10:0] sum;reg [4:0] center_mean,min_edge;
reg [10:0] center_total;reg [9:0] max_edge_total;
reg is_empty,legacy_ok;reg [1:0] edge_no;reg [3:0] tap;reg [2:0] good_sides;
reg signed [8:0] gx,gy;
reg [10:0] edge_x,edge_y;
always @*begin
 cell_x=center_x-4+sample[2:0];cell_y=center_y-4+sample[5:3];
 case(feature)
  1:begin cell_x=center_x-8+sample[1:0];cell_y=center_y-4+sample[4:2];end
  2:begin cell_x=center_x+4+sample[1:0];cell_y=center_y-4+sample[4:2];end
  3:begin cell_x=center_x-4+sample[2:0];cell_y=center_y-8+sample[4:3];end
  4:begin cell_x=center_x-4+sample[2:0];cell_y=center_y+4+sample[4:3];end
 endcase
 edge_x=center_x;edge_y=center_y;
 case(edge_no)
  0:edge_x={1'b0,box_x0};
  1:edge_x={1'b0,box_x1};
  2:edge_y={1'b0,box_y0};
  3:edge_y={1'b0,box_y1};
 endcase
 if(phase>=5)begin
  case(tap)
   0,3,6:cell_x=edge_x-1'b1;
   1,4,7:cell_x=edge_x;
   default:cell_x=edge_x+1'b1;
  endcase
  if(tap<3)cell_y=edge_y-1'b1;
  else if(tap<6)cell_y=edge_y;
  else cell_y=edge_y+1'b1;
 end
end
wire [4:0] pixel=q[byte_index*5+:5];
wire [10:0] next_sum=sum+{6'd0,pixel};
wire [4:0] mean=feature==0 ? next_sum[10:6] : next_sum[9:5];
wire [4:0] next_min=mean<min_edge ? mean : min_edge;
wire [9:0] next_max=next_sum[9:0]>max_edge_total ? next_sum[9:0] : max_edge_total;
wire [10:0] center_limit=center_total+11'd16;
// min(a,b)*5 >= center*4 iff both a,b >= ceil(center*4/5).
// For integral center, ceil(center*4/5) = center-floor(center/5).
// Distribute the extrema comparisons to avoid RAM -> sum -> mux -> compare.
wire [4:0] edge_floor=center_mean-center_mean/5'd5;
wire contrast_ok=min_edge>=edge_floor && mean>=edge_floor;
wire standing_ok=max_edge_total<=center_limit[10:1] && next_sum[9:0]<=center_limit[10:1];
wire gray_ok_now=center_mean>=((FOREGROUND+7)/8) && contrast_ok && (!STANDING_REVIEW || standing_ok);
wire signed [8:0] gray_signed=$signed({4'b0,pixel});
reg signed [8:0] term_x,term_y;
always @*begin
 term_x=0;term_y=0;
 case(tap)
  0:begin term_x=-gray_signed;term_y=-gray_signed;end
  1:term_y=-(gray_signed<<<1);
  2:begin term_x=gray_signed;term_y=-gray_signed;end
  3:term_x=-(gray_signed<<<1);
  5:term_x=gray_signed<<<1;
  6:begin term_x=-gray_signed;term_y=gray_signed;end
  7:term_y=gray_signed<<<1;
  8:begin term_x=gray_signed;term_y=gray_signed;end
 endcase
end
wire signed [8:0] gx_next=gx+term_x,gy_next=gy+term_y;
wire signed [8:0] outward=edge_no==0 ? gx_next : edge_no==1 ? -gx_next : edge_no==2 ? gy_next : -gy_next;
wire side_good=outward>=MIN_GRADIENT;
wire [2:0] next_good=good_sides+{2'd0,side_good};
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  ready<=0;normal<=0;empty_ok<=0;edge_strengths<=0;captured<=0;read_address<=0;
  center_x<=0;center_y<=0;box_x0<=0;box_x1<=0;box_y0<=0;box_y1<=0;
  phase<=0;feature<=0;sample<=0;byte_index<=0;sum<=0;center_mean<=0;min_edge<=31;
  center_total<=0;max_edge_total<=0;is_empty<=0;legacy_ok<=0;edge_no<=0;tap<=0;good_sides<=0;gx<=0;gy<=0;
 end else if(cancel)begin ready<=0;normal<=0;empty_ok<=0;captured<=0;phase<=0;edge_strengths<=0;end
 else begin
  if(capture)captured<=captured+1'b1;
  if(measure)begin
   ready<=!measurable;normal<=0;empty_ok<=0;edge_strengths<=0;
   center_x<=requested_x;center_y<=requested_y;
   box_x0<=xmin;box_x1<=xmax;box_y0<=ymin;box_y1<=ymax;
   phase<=measurable ? (measure_empty ? 5 : 2) : 0;
   feature<=0;sample<=0;sum<=0;center_mean<=0;min_edge<=31;center_total<=0;max_edge_total<=0;
   is_empty<=measure_empty;legacy_ok<=0;edge_no<=0;tap<=0;good_sides<=0;gx<=0;gy<=0;
  end else case(phase)
   2,5:begin read_address<=(cell_y-Y0/2)*COLS+((cell_x-X0/2)>>2);byte_index<=(cell_x-X0/2)&3;phase<=phase+1'b1;end
   3,6:phase<=phase+1'b1;
   4:begin
    if(sample==(feature==0 ? 63 : 31))begin
     if(feature==0)begin center_mean<=mean;center_total<=next_sum;end
     else begin min_edge<=next_min;max_edge_total<=next_max;end
     sample<=0;sum<=0;
     if(feature==4)begin
      legacy_ok<=gray_ok_now;
      phase<=5;
     end else begin feature<=feature+1'b1;phase<=2;end
    end else begin sum<=next_sum;sample<=sample+1'b1;phase<=2;end
   end
   7:begin
    gx<=gx_next;gy<=gy_next;
    if(tap==8)begin
     edge_strengths[edge_no*8+:8]<=outward<0 ? 8'd0 : outward[7:0];
     good_sides<=next_good;tap<=0;gx<=0;gy<=0;
     if(edge_no==3)begin
      empty_ok<=is_empty && next_good>=MIN_SIDES;
      normal<=!is_empty && legacy_ok && next_good>=MIN_SIDES;
      ready<=1;phase<=0;
     end else begin edge_no<=edge_no+1'b1;phase<=5;end
    end else begin tap<=tap+1'b1;phase<=5;end
   end
  endcase
 end
end

// Passive observer of this SAME RAM/read/FSM. No read, decision or ready path
// depends on this block. Only the selected published P request is retained;
// measurements of subsequent objects cannot overwrite its diagnostic fields.
generate if(TRACE)begin : passive_trace
 reg active,eligible,gray_ok,final_ok;
 reg [10:0] center;
 reg [39:0] sides;
 reg [35:0] gradients;
 reg [2:0] good;
 reg [7:0] failures;
 assign trace_metrics={center,sides,gradients,good,gray_ok,final_ok,eligible,failures};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin active<=0;eligible<=0;gray_ok<=0;final_ok<=0;center<=0;sides<=0;gradients<=0;good<=0;failures<=0;end
  else if(cancel)begin active<=0;eligible<=0;gray_ok<=0;final_ok<=0;center<=0;sides<=0;gradients<=0;good<=0;failures<=0;end
  else if(measure)begin
   active<=trace_enable && !measure_empty;
   if(trace_enable && !measure_empty)begin
    eligible<=measurable;gray_ok<=0;final_ok<=0;center<=0;sides<=0;gradients<=0;good<=0;
    failures<={1'b0,!body_measurable,captured!=WORDS,!in_cache,4'd0};
   end
  end else if(active)begin
   if(phase==4 && sample==(feature==0 ? 63 : 31))begin
    case(feature)
     0:center<=next_sum;
     1:sides[39:30]<=next_sum[9:0];
     2:sides[29:20]<=next_sum[9:0];
     3:sides[19:10]<=next_sum[9:0];
     4:sides[9:0]<=next_sum[9:0];
    endcase
    if(feature==4)begin
     failures[0]<=center_mean<((FOREGROUND+7)/8);
     failures[1]<=!contrast_ok;
     failures[2]<=STANDING_REVIEW && !standing_ok;
     gray_ok<=gray_ok_now;
    end
   end
   if(phase==7 && tap==8)begin
    case(edge_no)
     0:gradients[35:27]<=outward;
     1:gradients[26:18]<=outward;
     2:gradients[17:9]<=outward;
     3:gradients[8:0]<=outward;
    endcase
    if(edge_no==3)begin good<=next_good;failures[3]<=next_good<MIN_SIDES;
     final_ok<=legacy_ok && next_good>=MIN_SIDES;active<=0;
    end
   end
  end
 end
end else begin : no_passive_trace
 assign trace_metrics=0;
end endgenerate
endmodule
