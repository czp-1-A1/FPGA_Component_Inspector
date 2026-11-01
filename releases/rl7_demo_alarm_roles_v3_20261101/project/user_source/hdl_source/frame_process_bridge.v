// Ordered AWB pixels and native proof events cross into a continuous clock.
// The recovered CSI clock may stop in vertical blanking. Never wait for it
// to replay Sobel rows, analyse the frame, or send its completed metadata.
module frame_process_bridge(
 input wire source_clk,process_clk,rst_n,
 input wire [127:0] source_data,input wire source_valid,
 output reg [127:0] process_data,output reg process_valid,
 output wire process_overflow
);
reg [127:0] read_data;
reg read_valid;
reg [127:0] memory [0:511]; // Synchronous dual-clock ERAM; never reset RAM.
reg [9:0] write_bin,write_gray,read_bin,read_gray;
reg [9:0] read_gray_sync1,read_gray_sync2,write_gray_sync1,write_gray_sync2;
reg [1:0] source_reset,process_reset;
reg overflow;reg [1:0] overflow_sync;
wire full=write_gray=={~read_gray_sync2[9:8],read_gray_sync2[7:0]};
wire empty=read_gray==write_gray_sync2;
wire enqueue=source_valid && !full && !source_reset[1];
wire dequeue=!empty && !process_reset[1];
wire [9:0] next_write=write_bin+10'd1,next_read=read_bin+10'd1;
always @(posedge source_clk or negedge rst_n)begin
 if(!rst_n)source_reset<=2'b11;else source_reset<={source_reset[0],1'b0};
end
always @(posedge process_clk or negedge rst_n)begin
 if(!rst_n)process_reset<=2'b11;else process_reset<={process_reset[0],1'b0};
end
always @(posedge source_clk or negedge rst_n)begin
 if(!rst_n)begin write_bin<=0;write_gray<=0;read_gray_sync1<=0;read_gray_sync2<=0;end
 else if(source_reset[1])begin write_bin<=0;write_gray<=0;read_gray_sync1<=0;read_gray_sync2<=0;end
 else begin
  read_gray_sync1<=read_gray;read_gray_sync2<=read_gray_sync1;
  if(enqueue)begin write_bin<=next_write;write_gray<=next_write ^ (next_write>>1);end
 end
end
always @(posedge process_clk or negedge rst_n)begin
 if(!rst_n)begin read_bin<=0;read_gray<=0;write_gray_sync1<=0;write_gray_sync2<=0;process_valid<=0;read_valid<=0;end
 else if(process_reset[1])begin read_bin<=0;read_gray<=0;write_gray_sync1<=0;write_gray_sync2<=0;process_valid<=0;read_valid<=0;end
 else begin
  write_gray_sync1<=write_gray;write_gray_sync2<=write_gray_sync1;
  read_valid<=dequeue;process_valid<=read_valid;
  if(dequeue)begin read_bin<=next_read;read_gray<=next_read ^ (next_read>>1);end
 end
end
always @(posedge source_clk)if(enqueue)memory[write_bin[8:0]]<=source_data;
always @(posedge process_clk)if(dequeue)read_data<=memory[read_bin[8:0]];
// One complete128-bit output stage separates ERAM clk2q from downstream
// proof/config/counter control. Flags and pixels retain exactly the same order.
// Data need no reset: both corresponding valid stages reset to zero.
always @(posedge process_clk)process_data<=read_data;
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
endmodule
