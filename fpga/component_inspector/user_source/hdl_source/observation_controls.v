// RAW_EDGE_ONLY: SW2 selects RAW / black-and-white edges; SW1 is ignored.
// Legacy: SW1=bit0 gray, SW2=bit1 edge. Held levels, not button events.
// 50 MHz domain; the complete pair must remain stable for 20 ms.
module observation_controls #(parameter RAW_EDGE_ONLY=0,STABLE_CYCLES=1000000)(
 input wire clk,rst_n,input wire [1:0] switches,
 output reg [17:0] request
);
reg [1:0] sync0,sync1,candidate;
reg [19:0] stable;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin sync0<=0;sync1<=0;candidate<=0;stable<=0;request<=0;end
 else begin
  sync0<=RAW_EDGE_ONLY ? {switches[1],1'b0} : switches;sync1<=sync0;
  if(sync1!=candidate) begin candidate<=sync1;stable<=0;end
  else if(stable<STABLE_CYCLES-1) stable<=stable+1'b1;
  else if(request[1:0]!=candidate) request<={request[17:2]+16'd1,candidate};
 end
end
endmodule
