// One registered stream stage. Geometry and per-line markers come from
// uial2axis; native completeness remains checked independently by the guard.
// Never crop to the former1024x600 window or infer lines from valid bubbles.
module image_correction #(parameter DATA_WIDTH=40)(
 input wire I_clk,I_rst_n,
 input wire [DATA_WIDTH-1:0] I_raw_data,
 input wire I_raw_valid,I_raw_frame_start,I_raw_frame_end,
 output reg [DATA_WIDTH-1:0] O_raw_tdata,
 output reg O_raw_tlast,O_raw_tvalid,O_raw_tuser,
 input wire O_raw_tready
);
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin O_raw_tdata<=0;O_raw_tlast<=0;O_raw_tvalid<=0;O_raw_tuser<=0;end
  else begin
   O_raw_tdata<=I_raw_valid ? I_raw_data : {DATA_WIDTH{1'b0}};
   O_raw_tvalid<=I_raw_valid;
   O_raw_tlast<=I_raw_valid && I_raw_frame_end;
   O_raw_tuser<=I_raw_valid && I_raw_frame_start;
  end
 end
endmodule
