// CSI clock domain. State describes the recent acquisition, not the DDR display.
// A new frame or invalidation clears freshness; rearming needs a new sample.
module roi_classifier(
 input wire clk,rst_n,calibration_ok,frame_start,invalidate,sample_valid,sample_new,
 input wire [7:0] mean,threshold,input wire present_high,
 output wire [1:0] state
);
localparam [1:0] UNCAL=2'd0,WAIT_SAMPLE=2'd1,PRESENT=2'd2,EMPTY=2'd3;
reg fresh;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) fresh<=0;
 else if(!calibration_ok || frame_start || invalidate || !sample_valid) fresh<=0;
 else if(sample_new) fresh<=1;
end
wire present=present_high ? mean>=threshold : mean<=threshold;
assign state=!calibration_ok ? UNCAL :
 (!fresh || !sample_valid || frame_start || invalidate) ? WAIT_SAMPLE :
 present ? PRESENT : EMPTY;
endmodule
