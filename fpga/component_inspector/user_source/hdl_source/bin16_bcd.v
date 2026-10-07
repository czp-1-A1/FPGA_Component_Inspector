// Sixteen shift/add-3 cycles. Decimal conversion stays outside pixel mux.
module bin16_bcd(input wire clk,rst_n,start,input wire [15:0] value,output reg [19:0] digits);
reg [15:0] binary;
reg [19:0] bcd;
reg [19:0] adjusted;
reg [4:0] count;
integer i;
always @* begin
 adjusted=bcd;
 for(i=0;i<5;i=i+1) if(bcd[i*4+:4]>=5) adjusted[i*4+:4]=bcd[i*4+:4]+4'd3;
end
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin binary<=0; bcd<=0; count<=0; digits<=0; end
 else if(start) begin binary<=value; bcd<=0; count<=16; end
 else if(count!=0) begin
  binary<={binary[14:0],1'b0}; bcd<={adjusted[18:0],binary[15]}; count<=count-1'b1;
  if(count==1) digits<={adjusted[18:0],binary[15]};
 end
end
endmodule
