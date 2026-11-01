// Display-only 1920x1080 -> 1280x720 bilinear resampling. Native ROI remains
// before this module. Each three source samples produce two display samples:
// (3*a+b)/4 and (b+3*c)/4, horizontally and then vertically.
// One inferred synchronous line RAM; no memory reset or input backpressure.
module rgb_resize_2_3 #(parameter WIDTH=1920,HEIGHT=1080)(
 input wire clk,rst_n,early_sof,valid,last,input wire [95:0] rgb,
 output reg out_early_sof,out_valid,out_last,output reg [95:0] out_rgb,
 output reg frame_bad);
 localparam IN_BEATS=WIDTH/4,OUT_BEATS=WIDTH/6;
 localparam X_BITS=$clog2(IN_BEATS+1),A_BITS=$clog2(OUT_BEATS);
 localparam Y_BITS=$clog2(HEIGHT+1);
 reg [1:0] input_phase,row_phase;
 reg [X_BITS-1:0] input_group;
 reg [Y_BITS-1:0] input_row;
 reg [119:0] first,second;reg [95:0] pending_rgb,h_rgb;
 reg pending,h_valid,h_last;
 reg [1:0] pending_phase,h_phase;
 reg [A_BITS-1:0] output_group,h_group,pending_group;
 reg pending_last;
 // Only the middle source pixel in each triple is a light-weight sample.
 // Endpoints are stored as exact 3*value in ten bits (maximum765).
 // All three capture phases share these twelve combinational triplers.
 wire [119:0] first_data,second_data,third_data;
 genvar wl,wc;
 generate for(wl=0;wl<4;wl=wl+1)begin : weighted_input
  for(wc=0;wc<3;wc=wc+1)begin : channel
   wire [7:0] v=rgb[95-wl*24-wc*8-:8];
   wire [9:0] triple={2'd0,v}+{1'd0,v,1'b0};
   assign first_data[119-wl*30-wc*10-:10]=wl==1 ? {2'd0,v} : triple;
   assign second_data[119-wl*30-wc*10-:10]=(wl==0 || wl==3) ? {2'd0,v} : triple;
   assign third_data[119-wl*30-wc*10-:10]=wl==2 ? {2'd0,v} : triple;
  end
 end endgenerate
 wire [359:0] block_rgb={first,second,third_data};
 function [7:0] blend(input [7:0] a,b,input heavy_a);
  reg [9:0] sum;
  begin
   // 3*a+b or a+3*b = (a+b)+2*(heavy_a ? a : b).
   // Full 10-bit sum (maximum 1020); unchanged truncation to bits[9:2].
   sum=({2'b0,a}+{2'b0,b})+{1'b0,(heavy_a ? a : b),1'b0};
   blend=sum[9:2];
  end
 endfunction
 function [23:0] horizontal(input [359:0] pixels,input integer index);
  integer heavy,light,c;reg [9:0] sum;
  begin
   heavy=(index/2)*3+(index%2==0 ? 0 : 2);light=(index/2)*3+1;
   for(c=0;c<3;c=c+1)begin
    sum=pixels[359-heavy*30-c*10-:10]+pixels[359-light*30-c*10-:10];
    horizontal[23-c*8-:8]=sum[9:2];
   end
  end
 endfunction
 integer lane;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin
   input_phase<=0;row_phase<=0;input_group<=0;input_row<=0;
   first<=0;second<=0;pending_rgb<=0;pending<=0;pending_phase<=0;
   output_group<=0;h_group<=0;pending_group<=0;pending_last<=0;
   h_rgb<=0;h_valid<=0;h_last<=0;h_phase<=0;frame_bad<=0;
  end else if(early_sof)begin
   input_phase<=0;row_phase<=0;input_group<=0;input_row<=0;
   pending<=0;output_group<=0;h_valid<=0;h_last<=0;frame_bad<=0;
  end else begin
   h_valid<=0;h_last<=0;pending<=0;
   if(pending && !frame_bad)begin
    h_valid<=1;h_rgb<=pending_rgb;h_phase<=pending_phase;
    h_group<=pending_group;h_last<=pending_last;
   end
   if(valid && !frame_bad)begin
    if(input_row>=HEIGHT || last!=(input_group==IN_BEATS-1))frame_bad<=1;
    case(input_phase)
     0:begin first<=first_data;input_phase<=1;end
     1:begin second<=second_data;input_phase<=2;end
     2:begin
      input_phase<=0;h_valid<=1;h_phase<=row_phase;h_group<=output_group;
      pending<=1;pending_phase<=row_phase;pending_group<=output_group+1'b1;
      pending_last<=last;output_group<=last?0:output_group+2'd2;
      for(lane=0;lane<4;lane=lane+1)begin
       h_rgb[95-lane*24-:24]<=horizontal(block_rgb,lane);
       pending_rgb[95-lane*24-:24]<=horizontal(block_rgb,lane+4);
      end
     end
    endcase
    if(last)begin
     input_group<=0;input_row<=input_row+1'b1;
     row_phase<=row_phase==2?0:row_phase+1'b1;
    end else input_group<=input_group+1'b1;
   end
  end
 reg [95:0] memory[0:OUT_BEATS-1];
 reg [95:0] previous_row,current_row;
 reg v_valid,v_last;reg [1:0] v_phase;
 always @(posedge clk)begin
  if(h_valid && !frame_bad && !early_sof)memory[h_group]<=h_rgb;
  previous_row<=memory[h_group];
 end
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin
   current_row<=0;v_valid<=0;v_last<=0;v_phase<=0;
   out_valid<=0;out_last<=0;out_rgb<=0;out_early_sof<=0;
  end else begin
   out_early_sof<=early_sof;
   current_row<=h_rgb;v_phase<=h_phase;v_last<=h_last;
   v_valid<=h_valid && !frame_bad && !early_sof;
   out_valid<=v_valid && v_phase!=0 && !frame_bad && !early_sof;
   out_last<=v_valid && v_phase!=0 && v_last && !frame_bad && !early_sof;
   if(early_sof)begin v_valid<=0;out_valid<=0;out_last<=0;end
   for(lane=0;lane<12;lane=lane+1)
    out_rgb[95-lane*8-:8]<=blend(previous_row[95-lane*8-:8],
                               current_row[95-lane*8-:8],v_phase==1);
  end
endmodule
