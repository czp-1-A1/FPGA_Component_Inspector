// Bundled-data mailbox: source payload is held until destination acknowledges.
// Both domains must share reset assertion. Two-flop token synchronizers.
module status_cdc #(parameter WIDTH=32)(
 input wire S_clk, D_clk, rst_n,
 input wire [WIDTH-1:0] S_data,
 output reg [WIDTH-1:0] D_data
);
reg [WIDTH-1:0] payload;
reg req, ack;
reg [1:0] ack_sync, req_sync;
always @(posedge S_clk or negedge rst_n) begin
 if(!rst_n) begin payload<=0; req<=0; ack_sync<=0; end
 else begin
  ack_sync<={ack_sync[0],ack};
  if(ack_sync[1]==req) begin payload<=S_data; req<=~req; end
 end
end
always @(posedge D_clk or negedge rst_n) begin
 if(!rst_n) begin req_sync<=0; ack<=0; D_data<=0; end
 else begin
  req_sync<={req_sync[0],req};
  if(req_sync[1]!=ack) begin D_data<=payload; ack<=req_sync[1]; end
 end
end
endmodule
