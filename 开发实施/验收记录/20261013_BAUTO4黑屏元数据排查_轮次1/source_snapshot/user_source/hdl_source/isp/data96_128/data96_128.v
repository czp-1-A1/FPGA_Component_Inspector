// Keep the 3:4 packing phase through valid gaps; only FS discards a partial group.
module data_96bit_to_128bit(
 input wire I_clk,I_rst_n,I_96b_frame_start,I_96b_valid,
 input wire [95:0] I_96b_data,
 output reg O_128b_frame_start,O_128b_valid,output reg [127:0] O_128b_data
);
reg [95:0] S_96b_data_1d;
reg [1:0] S_cnt;
always @(posedge I_clk or negedge I_rst_n) begin
 if(!I_rst_n) begin
  S_cnt<=0;S_96b_data_1d<=0;O_128b_frame_start<=0;O_128b_valid<=0;O_128b_data<=0;
 end else begin
  O_128b_frame_start<=I_96b_frame_start;O_128b_valid<=0;
  if(I_96b_frame_start) S_cnt<=0;
  else if(I_96b_valid) begin
   S_cnt<=S_cnt+1'b1;S_96b_data_1d<=I_96b_data;
   case(S_cnt)
    1:begin O_128b_valid<=1;O_128b_data<={S_96b_data_1d,I_96b_data[95:64]};end
    2:begin O_128b_valid<=1;O_128b_data<={S_96b_data_1d[63:0],I_96b_data[95:32]};end
    3:begin O_128b_valid<=1;O_128b_data<={S_96b_data_1d[31:0],I_96b_data};end
   endcase
  end
 end
end
endmodule
