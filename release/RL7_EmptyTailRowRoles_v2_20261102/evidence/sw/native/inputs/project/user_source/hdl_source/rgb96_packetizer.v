// RGB888, four ordered pixels per beat. Gaps retain the packing phase.
// A complete line has a multiple of sixteen pixels, so no padding is needed.
module rgb96_packetizer(input wire clk,rst_n,early_sof,valid,
 input wire [95:0] rgb,output reg frame_start,out_valid,
 output reg [127:0] data);
 reg [1:0] phase;
 reg [95:0] previous;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin phase<=0;previous<=0;frame_start<=0;out_valid<=0;data<=0;end
  else begin
   frame_start<=early_sof;out_valid<=0;
   if(early_sof)begin phase<=0;previous<=0;end
   else if(valid)begin
    previous<=rgb;phase<=phase+1'b1;
    case(phase)
     1:begin out_valid<=1;data<={previous,rgb[95:64]};end
     2:begin out_valid<=1;data<={previous[63:0],rgb[95:32]};end
     3:begin out_valid<=1;data<={previous[31:0],rgb};end
     default:out_valid<=0;
    endcase
   end
  end
endmodule
