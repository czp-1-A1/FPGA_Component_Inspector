// Atomic extension of the existing mean/min/max completion record.
// Bits: [114:83] WB epoch/red/blue, [82:59] G sum, [58:46] thresholded edge count, [45:28] epoch/mode,
// [27:0] legacy completion token, state, validity and mean/min/max.
module roi_observation_snapshot #(parameter CORE_AREA=6400,SHAPE_MODEL=0)(
 input wire clk,rst_n,invalidate,input wire [17:0] tag,input wire [31:0] wb_tag,
 input wire [27:0] legacy_record,input wire [12:0] core_pixels,edge_count,
 input wire model_valid,input wire [36:0] model_features,
 input wire [23:0] edge_sum,output reg [114:0] record
);
reg token;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin token<=0;record<=0;end
 else if(invalidate || !legacy_record[24]) begin
  token<=legacy_record[27];record[27]<=legacy_record[27];record[26:24]<={2'd1,1'b0};
 end else if(legacy_record[27]!=token) begin
  token<=legacy_record[27];
  // Shape mode reuses the atomic 37-bit feature field; no new CDC path.
  record<={wb_tag,(SHAPE_MODEL ? model_features : {edge_sum,edge_count}),tag,legacy_record[27:25],
   ((!SHAPE_MODEL || model_valid) && (!tag[1] || core_pixels==CORE_AREA)),legacy_record[23:0]};
 end
end
endmodule
