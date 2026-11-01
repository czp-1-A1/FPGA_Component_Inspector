// Same-frame internal body proof. Four five-bit 2x2 means share each20-bit RAM word.
// Cache the complete default ROI bands plus16 processing pixels of inner-window context.
module present_surface_check #(parameter WIDTH=1280,HEIGHT=720,FOREGROUND=100,STANDING_REVIEW=0)(
 input wire clk,rst_n,cancel,write_enable,measure,
 input wire [10:0] write_x,input wire [9:0] write_y,input wire [31:0] write_data,
 input wire [9:0] xmin,xmax,ymin,ymax,
 output reg ready,normal
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
wire measurable=captured==WORDS && width_now>=16 && height_now>=16 &&
 requested_x>=X0/2+8 && requested_x+8<=X1/2 && requested_y>=Y0/2+8 && requested_y+8<=Y1/2;
reg [10:0] center_x,center_y,cell_x,cell_y;
reg [2:0] phase,feature;reg [5:0] sample;reg [1:0] byte_index;
reg [10:0] sum;reg [4:0] center_mean,min_edge;
reg [10:0] center_total;reg [9:0] max_edge_total;
always @*begin
 cell_x=center_x-4+sample[2:0];cell_y=center_y-4+sample[5:3];
 case(feature)
  1:begin cell_x=center_x-8+sample[1:0];cell_y=center_y-4+sample[4:2];end
  2:begin cell_x=center_x+4+sample[1:0];cell_y=center_y-4+sample[4:2];end
  3:begin cell_x=center_x-4+sample[2:0];cell_y=center_y-8+sample[4:3];end
  4:begin cell_x=center_x-4+sample[2:0];cell_y=center_y+4+sample[4:3];end
 endcase
end
wire [10:0] next_sum=sum+{6'd0,q[byte_index*5+:5]};
wire [4:0] mean=feature==0 ? next_sum[10:6] : next_sum[9:5];
wire [4:0] next_min=mean<min_edge ? mean : min_edge;
wire [7:0] edge5={3'd0,next_min}+{1'b0,next_min,2'b0};
wire [6:0] center4={center_mean,2'b0};
wire [9:0] next_max=next_sum[9:0]>max_edge_total ? next_sum[9:0] : max_edge_total;
// Compare unrounded regional sums: center64 versus twice each edge32.
//16 center-sum units allow2 equivalent gray levels, without losing a full5-bit bin.
wire [10:0] center_limit=center_total+11'd16;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  ready<=0;normal<=0;captured<=0;read_address<=0;center_x<=0;center_y<=0;
  phase<=0;feature<=0;sample<=0;byte_index<=0;sum<=0;center_mean<=0;min_edge<=31;center_total<=0;max_edge_total<=0;
 end else if(cancel)begin
  ready<=0;normal<=0;captured<=0;phase<=0;
 end else begin
  if(capture)captured<=captured+1'b1;
  if(measure)begin
   ready<=!measurable;normal<=0;center_x<=requested_x;center_y<=requested_y;
   phase<=measurable ? 2 : 0;feature<=0;sample<=0;sum<=0;center_mean<=0;min_edge<=31;center_total<=0;max_edge_total<=0;
  end else case(phase)
   2:begin
    read_address<=(cell_y-Y0/2)*COLS+((cell_x-X0/2)>>2);
    byte_index<=(cell_x-X0/2)&3;phase<=3;
   end
   3:phase<=4;
   4:begin
    if(sample==(feature==0 ? 63 : 31))begin
     if(feature==0)begin center_mean<=mean;center_total<=next_sum;end
     else begin min_edge<=next_min;max_edge_total<=next_max;end
     sample<=0;sum<=0;
     if(feature==4)begin
      normal<=center_mean>=((FOREGROUND+7)/8) && edge5>={1'b0,center4} && (!STANDING_REVIEW || {next_max,1'b0}<=center_limit);
      ready<=1;phase<=0;
     end else begin feature<=feature+1'b1;phase<=2;end
    end else begin sum<=next_sum;sample<=sample+1'b1;phase<=2;end
   end
  endcase
 end
end
endmodule
