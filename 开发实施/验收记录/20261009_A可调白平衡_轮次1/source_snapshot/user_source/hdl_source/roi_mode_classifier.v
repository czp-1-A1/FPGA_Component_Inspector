// Frame-complete features only. Thresholds are provisional black-tape trials.
// RAW/GRAY use the existing brightness recipe; EDGE does not consult MEAN.
module roi_mode_classifier #(
 parameter CORE_AREA=6400,
 parameter [12:0] EDGE_LOW=13'd48,EDGE_HIGH=13'd96,
 parameter [23:0] SUM_LOW=24'd16384,SUM_HIGH=24'd32768
)(
 input wire [1:0] mode,gray_state,input wire scene_ok,
 input wire [12:0] core_pixels,edge_count,input wire [23:0] edge_sum,
 output reg [1:0] state
);
localparam [1:0] WAIT_SAMPLE=2'd1,PRESENT=2'd2,EMPTY=2'd3;
wire edge_present=edge_count>=EDGE_HIGH && edge_sum>=SUM_HIGH;
wire edge_empty=edge_count<=EDGE_LOW && edge_sum<=SUM_LOW;
wire [1:0] edge_state=edge_present ? PRESENT : edge_empty ? EMPTY : WAIT_SAMPLE;
always @* begin
 state=gray_state;
 if(gray_state>=PRESENT) begin
  if(!scene_ok) state=WAIT_SAMPLE;
  else if(mode[1]) begin
   if(core_pixels!=CORE_AREA) state=WAIT_SAMPLE;
   else if(mode[0] && gray_state!=edge_state) state=WAIT_SAMPLE;
   else state=edge_state;
  end
 end
end
endmodule
