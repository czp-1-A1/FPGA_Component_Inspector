// Diagnostic RGB TMDS encoder. DVI-compatible video/control only; no HDMI
// audio, guard bands or AVI packets. Implements the TMDS disparity rules.
module dvi_encoder(input wire clk,rst,de,input wire [7:0] data,
 input wire [1:0] control,output reg [9:0] symbol);
 reg signed [5:0] disparity;
 reg [8:0] transition;
 reg [9:0] encoded;
 reg signed [5:0] delta;
 integer i,ones,input_ones;
 reg xnor_mode;
 always @* begin
  input_ones=0;
  for(i=0;i<8;i=i+1)input_ones=input_ones+data[i];
  xnor_mode=(input_ones>4 || (input_ones==4 && !data[0]));
  transition[0]=data[0];
  for(i=1;i<8;i=i+1)transition[i]=transition[i-1]^data[i]^xnor_mode;
  transition[8]=!xnor_mode;
  ones=0;
  for(i=0;i<8;i=i+1)ones=ones+transition[i];
  delta=2*ones-8;
  if(disparity==0 || delta==0) begin
   encoded={~transition[8],transition[8],transition[8]?transition[7:0]:~transition[7:0]};
   delta=transition[8]?delta:-delta;
  end else if((disparity>0 && delta>0)||(disparity<0 && delta<0)) begin
   encoded={1'b1,transition[8],~transition[7:0]};
   delta=(transition[8]?6'sd2:6'sd0)-delta;
  end else begin
   encoded={1'b0,transition[8],transition[7:0]};
   delta=delta-(transition[8]?6'sd0:6'sd2);
  end
 end
 always @(posedge clk or posedge rst) begin
  if(rst)begin symbol<=10'b1101010100;disparity<=0;end
  else if(de)begin symbol<=encoded;disparity<=disparity+delta;end
  else begin
   disparity<=0;
   case(control)
    2'b00:symbol<=10'b1101010100;
    2'b01:symbol<=10'b0010101011;
    2'b10:symbol<=10'b0101010100;
    2'b11:symbol<=10'b1010101011;
   endcase
  end
 end
endmodule
