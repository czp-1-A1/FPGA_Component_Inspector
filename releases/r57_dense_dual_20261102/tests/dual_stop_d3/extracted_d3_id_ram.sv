module reference_id_ram #(parameter MAX_TOTAL=300)(input wire clk,wr,input wire [8:0] empty_address,empty_total,total,output reg [8:0] empty_id);
 reg [8:0] empty_ids[0:MAX_TOTAL-1];


 always @(posedge clk)begin
  empty_id<=empty_address<empty_total ? empty_ids[empty_address] : 9'd0;
 end
 always @(posedge clk)if(wr)empty_ids[empty_total]<=total+1'b1;
endmodule

module candidate_id_ram #(parameter MAX_TOTAL=300)(input wire clk,wr,input wire [8:0] empty_address,empty_total,total,output wire [8:0] empty_id);
 reg [8:0] empty_ids[0:MAX_TOTAL-1];
 reg [8:0] empty_id_raw;reg empty_id_valid;
 assign empty_id=empty_id_valid ? empty_id_raw : 9'd0;

 always @(posedge clk)begin
  empty_id_raw<=empty_ids[empty_address];
  empty_id_valid<=empty_address<empty_total;
 end
 always @(posedge clk)if(wr)empty_ids[empty_total]<=total+1'b1;
endmodule
