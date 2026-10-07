// A slot is published only after every packed word has reached the MC port.
module video_in #(parameter WIDTH=1024,HEIGHT=600)(
 input wire I_rst_n,I_camera_clk,I_camera_frame_start,I_camera_valid,
 input wire [127:0] I_camera_data,input wire I_mipi_rx_error,
 input wire I_frame_good,I_frame_bad,
 output wire O_camera_ready,
 input wire I_ddr_clk,I_display_pause,I_video_out_rd_busy,
 input wire I_active_valid,input wire [1:0] I_active_rp,
 output wire O_video_in_wr_busy,output wire [1:0] O_video_out_rp,
 output reg O_completed_valid,output reg [1:0] O_completed_rp,
 output reg O_capture_ok,output reg [15:0] O_lost_frames,
 output reg [15:0] O_overflow_frames,
 output reg O_ddr_user_wr_en,output reg [24:0] O_ddr_user_addr,
 output wire [127:0] O_ddr_user_wr_data,input wire I_ddr_user_ready
);
localparam WORDS=WIDTH*HEIGHT*3/16;
localparam WORD_BITS=$clog2(WORDS+1);
localparam LINE_WORDS=WIDTH*3/16;
localparam ROW_CREDIT_LIMIT=512-LINE_WORDS-32; // Write-side reservation only.
reg [3:0] extend_count;
reg S_camera_frame_start_extend;
reg [2:0] frame_sync;
wire S_frame_start=frame_sync[1] && !frame_sync[2];
wire S_fifo_rst=!I_rst_n || frame_sync[2];
wire [8:0] S_fifo_rd_num,camera_used;
wire camera_full,fifo_empty;
reg [WORD_BITS-1:0] camera_count;
reg camera_bad,camera_done;
reg [1:0] bad_sync,done_sync,good_sync;
assign O_camera_ready=!S_camera_frame_start_extend && !S_fifo_rst && !camera_bad && !camera_full && camera_used<=ROW_CREDIT_LIMIT;
always @(posedge I_camera_clk or negedge I_rst_n) begin
 if(!I_rst_n) begin
  extend_count<=0;S_camera_frame_start_extend<=0;
  camera_count<=0;camera_bad<=0;camera_done<=0;O_overflow_frames<=0;
 end else if(I_camera_frame_start) begin
  extend_count<=0;S_camera_frame_start_extend<=1;
  camera_count<=0;camera_bad<=0;camera_done<=0;
 end else begin
  if(S_camera_frame_start_extend) begin
   extend_count<=extend_count+1'b1;
   if(extend_count==7) S_camera_frame_start_extend<=0;
  end
  if(I_frame_bad || I_mipi_rx_error) camera_bad<=1;
  if(I_camera_valid && !S_camera_frame_start_extend && !S_fifo_rst && !camera_bad) begin
   if(camera_full || camera_count==WORDS) begin
    camera_bad<=1;
    if(camera_full) O_overflow_frames<=O_overflow_frames+1'b1;
   end else begin
    camera_count<=camera_count+1'b1;
    if(camera_count==WORDS-1) camera_done<=1;
   end
  end
 end
end
reg [1:0] S_video_in_wp;
reg frame_open,published;
reg [WORD_BITS-1:0] written;
reg S_ddr_wr_valid;
reg [8:0] burst_left;
wire S_fifo_rd_en=S_ddr_wr_valid && I_ddr_user_ready && !fifo_empty &&
                     !S_frame_start && !S_fifo_rst && !bad_sync[1];
assign O_video_in_wr_busy=S_ddr_wr_valid || O_ddr_user_wr_en;
assign O_video_out_rp=O_completed_rp;
function [24:0] base;
 input [1:0] slot;
 begin case(slot)
  0:base=0;1:base=7000000;2:base=14000000;3:base=21000000;
 endcase end
endfunction
reg [1:0] next_slot;
integer slot;
always @* begin
 next_slot=S_video_in_wp;
 for(slot=0;slot<4;slot=slot+1)
  if((!I_active_valid || slot!=I_active_rp) &&
     (!O_completed_valid || slot!=O_completed_rp)) next_slot=slot;
end
w128_d512_fifo U_w128_d512_fifo(
 .rst(S_fifo_rst),.clkw(I_camera_clk),
 .we(I_camera_valid && !S_camera_frame_start_extend && !S_fifo_rst && !camera_bad && camera_count<WORDS),.di(I_camera_data),
 .afull(),.full_flag(camera_full),.wrusedw(camera_used),
 .clkr(I_ddr_clk),.re(S_fifo_rd_en),.dout(O_ddr_user_wr_data),
 .rdusedw(S_fifo_rd_num),.valid(),.empty_flag(fifo_empty),.aempty());
always @(posedge I_ddr_clk or negedge I_rst_n) begin
 if(!I_rst_n) begin
  frame_sync<=0;bad_sync<=0;done_sync<=0;good_sync<=0;
  S_video_in_wp<=0;frame_open<=0;published<=0;written<=0;
  S_ddr_wr_valid<=0;burst_left<=0;O_ddr_user_wr_en<=0;O_ddr_user_addr<=0;
  O_completed_valid<=0;O_completed_rp<=0;O_capture_ok<=0;O_lost_frames<=0;
 end else begin
  frame_sync<={frame_sync[1:0],S_camera_frame_start_extend};
  bad_sync<={bad_sync[0],camera_bad};done_sync<={done_sync[0],camera_done};
  good_sync<={good_sync[0],I_frame_good};
  // MC ready is an almost-full signal with eight command slots of headroom.
  // Preserve registered FIFO read/write latency, including the last word
  // scheduled when ready falls. Count the final command, not rd_en.
  O_ddr_user_wr_en<=S_fifo_rd_en;
  if(O_ddr_user_wr_en) begin
   written<=written+1'b1;O_ddr_user_addr<=O_ddr_user_addr+25'd8;
  end
  if(bad_sync[1]) begin O_capture_ok<=0;S_ddr_wr_valid<=0;end
  if(S_fifo_rd_en) begin
   burst_left<=burst_left-1'b1;
   if(burst_left==1) S_ddr_wr_valid<=0;
  end
  if(!S_ddr_wr_valid && !O_ddr_user_wr_en && !I_video_out_rd_busy &&
     frame_open && !published && !S_fifo_rst && !bad_sync[1] && !I_display_pause) begin
   if(S_fifo_rd_num>=240) begin S_ddr_wr_valid<=1;burst_left<=240;end
   else if(done_sync[1] && S_fifo_rd_num!=0) begin
    S_ddr_wr_valid<=1;burst_left<=S_fifo_rd_num;
   end
  end
  if(frame_open && !published && written==WORDS && done_sync[1] &&
     good_sync[1] && !bad_sync[1] && !S_fifo_rst && !S_frame_start) begin
   O_completed_valid<=1;O_completed_rp<=S_video_in_wp;
   O_capture_ok<=1;published<=1;
  end
  if(S_frame_start) begin
   if(frame_open && !published) begin O_lost_frames<=O_lost_frames+1'b1;O_capture_ok<=0;end
   S_video_in_wp<=next_slot;O_ddr_user_addr<=base(next_slot);
   written<=0;published<=0;frame_open<=1;
   S_ddr_wr_valid<=0;burst_left<=0;O_ddr_user_wr_en<=0;
  end
 end
end
endmodule
