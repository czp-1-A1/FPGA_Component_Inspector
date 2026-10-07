// Destination gate for a coherent recent sample. Counters are historical only.
module roi_display_state(
 input wire clk,rst_n,cfg_done,input wire [15:0] exposure,gain,fps,
 input wire calibration_ok,input wire [27:0] record,input wire [17:0] observation_request,
 output wire sample_valid,output wire [1:0] state
);
reg [15:0] exposure_d,gain_d;
reg [17:0] observation_d;
reg token,armed,class_ready;
reg [5:0] settle;
wire live=cfg_done && fps!=0;
wire changed=exposure!=exposure_d || gain!=gain_d || observation_request!=observation_d;
// 32 pixel clocks drain pre-change camera/ROI mailbox transfers (<0.6us).
// A new complete camera sample is separated by milliseconds, not mailbox polls.
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin exposure_d<=0;gain_d<=0;observation_d<=0;token<=0;armed<=0;class_ready<=0;settle<=0;end
 else begin
  exposure_d<=exposure;gain_d<=gain;observation_d<=observation_request;
  if(!live || changed) begin settle<=0;armed<=0;class_ready<=0;token<=record[27];end
  else if(!settle[5]) begin settle<=settle+1'b1;armed<=0;class_ready<=0;token<=record[27];end
  else if(!record[24]) begin armed<=0;class_ready<=0;token<=record[27];end
  else if(record[27]!=token) begin
   armed<=1;token<=record[27];class_ready<=calibration_ok && record[26:25]>=2;
  end
  if(!calibration_ok) class_ready<=0;
 end
end
assign sample_valid=live && !changed && settle[5] && armed && record[24];
assign state=!sample_valid ? 2'd1 :
             !calibration_ok || !class_ready || record[26:25]==0 ? 2'd0 : record[26:25];
endmodule
