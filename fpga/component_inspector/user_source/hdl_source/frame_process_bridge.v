// Ordered AWB pixels and native proof events cross into a continuous clock.
// The recovered CSI clock may stop in vertical blanking. Never wait for it
// to replay Sobel rows, analyse the frame, or send its completed metadata.
module frame_process_bridge(
 input wire source_clk,process_clk,rst_n,
 input wire [127:0] source_data,input wire source_valid,
 output wire [127:0] process_data,output wire process_valid,
 output wire process_overflow
);
wire full,empty;
reg overflow;
reg [1:0] overflow_sync;
always @(posedge source_clk or negedge rst_n)begin
 if(!rst_n)overflow<=0;
 else if(source_valid && full)overflow<=1;
end
always @(posedge process_clk or negedge rst_n)begin
 if(!rst_n)overflow_sync<=0;
 else overflow_sync<={overflow_sync[0],overflow};
end
assign process_overflow=overflow_sync[1];
// Overflow invalidates output until reset; dropped proof/pixels cannot be
// repaired by pretending that a later source marker completed the frame.
w128_d512_fifo queue(
 .rst(!rst_n),.clkw(source_clk),.we(source_valid && !full),.di(source_data),
 .afull(),.full_flag(full),.wrusedw(),.clkr(process_clk),.re(!empty),
 .dout(process_data),.rdusedw(),.valid(process_valid),.empty_flag(empty),.aempty());
endmodule
