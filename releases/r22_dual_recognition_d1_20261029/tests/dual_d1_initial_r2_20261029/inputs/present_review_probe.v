// Read-only measurements from this source frame's two 128x96 pixel windows.
// Four 2x2 grayscale means per word; independent RAM never stalls the detector.
// Each ROI reports its first X-sorted displayed PRESENT, including weak T80.
module present_review_probe #(parameter WIDTH=1280,HEIGHT=720)(
 input wire clk,rst_n,cancel,write_enable,
 input wire [10:0] write_x,input wire [9:0] write_y,
 input wire [31:0] write_data,input wire measure,
 input wire [303:0] objects,input wire [35:0] references,
 output reg ready,output reg [127:0] record
);
localparam X0=WIDTH/2-64,Y0=HEIGHT*4/9-48,Y1=HEIGHT*43/60-48;
wire capture=write_enable && write_x>=X0 && write_x<X0+128 &&
 ((write_y>=Y0 && write_y<Y0+96) || (write_y>=Y1 && write_y<Y1+96));
wire capture_bank=write_y>=Y1;
wire [5:0] capture_row=(write_y-(capture_bank ? Y1 : Y0))>>1;
wire [3:0] capture_column=(write_x-X0)>>3;
wire [10:0] capture_address=(capture_bank ? 11'd768 : 11'd0)+{capture_row,capture_column};
reg [31:0] memory[0:1535];reg [31:0] q;
reg [10:0] read_address;
always @(posedge clk)begin
 if(capture && !cancel)memory[capture_address]<=write_data;
 q<=memory[read_address];
end
reg [10:0] captured0,captured1;
reg [303:0] snapshot;reg [35:0] ref_snapshot;
reg bank;reg [2:0] phase,feature;reg [5:0] sample;
reg [13:0] sum;
wire [75:0] object=bank ? (snapshot[227] ? snapshot[227:152] : snapshot[303:228]) :
 (snapshot[75] ? snapshot[75:0] : snapshot[151:76]);
wire [17:0] reference=bank ? ref_snapshot[35:18] : ref_snapshot[17:0];
wire present=object[75] && object[74:73]==2;
wire [10:0] body_x=object[41:31]+11'd2;
wire [9:0] body_y=object[19:10]+10'd2;
wire [6:0] body_width=object[55:49],body_height=object[48:42];
wire [9:0] center_x=(body_x>>1)+(body_width>>2);
wire [8:0] center_y=(body_y>>1)+(body_height>>2);
wire [9:0] window_y=bank ? Y1 : Y0;
wire measurable=present && reference[16] && (bank ? captured1 : captured0)==768 &&
 body_width>=32 && body_height>=32 && body_x>=X0 && body_x+body_width<=X0+128 &&
 body_y>=window_y && body_y+body_height<=window_y+96;
reg [9:0] cell_x;reg [8:0] cell_y;
always @*begin
 cell_x=center_x-4+sample[2:0];cell_y=center_y-4+sample[5:3];
 case(feature)
  1:begin cell_x=center_x-8+sample[1:0];cell_y=center_y-4+sample[4:2];end
  2:begin cell_x=center_x+4+sample[1:0];cell_y=center_y-4+sample[4:2];end
  3:begin cell_x=center_x-4+sample[2:0];cell_y=center_y-8+sample[4:3];end
  4:begin cell_x=center_x-4+sample[2:0];cell_y=center_y+4+sample[4:3];end
 endcase
end
wire [5:0] local_y=cell_y-(window_y>>1);
wire [5:0] local_x=cell_x-(X0>>1);
wire [10:0] next_address=(bank ? 11'd768 : 11'd0)+{local_y,local_x[5:2]};
reg [1:0] byte_index;
wire [7:0] value=q[byte_index*8+:8];
wire [13:0] next_sum=sum+{6'd0,value};
wire last_sample=sample==(feature==0 ? 63 : 31);
wire [7:0] mean=feature==0 ? next_sum[13:6] : next_sum[12:5];
// 63 object valid;62 windows valid;61 weak T80;60:57 original reason;
// 56:49/48:41 left/right dark counts saturated255;40 reserved;
// 39:32/31:24/23:16/15:8/7:0 C/L/R/T/B means (native 2x2 averages).
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  ready<=0;record<=0;captured0<=0;captured1<=0;read_address<=0;
  snapshot<=0;ref_snapshot<=0;bank<=0;phase<=0;feature<=0;sample<=0;sum<=0;byte_index<=0;
 end else if(cancel)begin
  ready<=0;record<=0;captured0<=0;captured1<=0;phase<=0;
 end else begin
  if(capture)begin
   if(capture_bank)captured1<=captured1+1'b1;
   else captured0<=captured0+1'b1;
  end
  if(measure)begin
   ready<=0;record<=0;snapshot<=objects;ref_snapshot<=references;bank<=0;phase<=1;
  end else case(phase)
   1:begin
    record[bank*64+:64]<={present,measurable,reference[17],object[72:69],reference[15:0],1'b0,40'd0};
    feature<=0;sample<=0;sum<=0;
    if(measurable)phase<=2;
    else if(!bank)bank<=1;
    else begin ready<=1;phase<=0;end
   end
   2:begin read_address<=next_address;byte_index<=local_x[1:0];phase<=3;end
   3:phase<=4;
   4:begin
    if(last_sample)begin
     record[bank*64+32-feature*8+:8]<=mean;
     sample<=0;sum<=0;
     if(feature==4)begin
      if(!bank)begin bank<=1;phase<=1;end
      else begin ready<=1;phase<=0;end
     end else begin feature<=feature+1'b1;phase<=2;end
    end else begin sum<=next_sum;sample<=sample+1'b1;phase<=2;end
   end
  endcase
 end
end
endmodule
