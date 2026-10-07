// Display history is separate from the classifier's current-frame freshness.
// One extra edge lets the classifier settle after the atomic statistics update.
module roi_result_snapshot(
 input wire clk,rst_n,frame_start,invalidate,calibration_ok,
 input wire sample_valid,sample_new,input wire [1:0] class_state,
 input wire [7:0] mean,minimum,maximum,
 output reg [27:0] record
);
reg pending;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin pending<=0;record<=0;end
 else begin
  pending<=sample_new;
  if(invalidate || !sample_valid) begin
   pending<=0;record[26:24]<={2'd1,1'b0};
  end else begin
   if(frame_start) pending<=0;
   // Losing the recipe removes a classification without hiding useful statistics.
   if(!calibration_ok) record[26:25]<=2'd0;
   if(pending && !frame_start) begin
    record<={~record[27],(calibration_ok ? class_state : 2'd0),1'b1,mean,minimum,maximum};
   end
  end
 end
end
endmodule
