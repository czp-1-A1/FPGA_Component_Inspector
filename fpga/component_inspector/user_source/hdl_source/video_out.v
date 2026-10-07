// Drain old DDR responses before resetting or selecting another complete slot.
module video_out #(parameter WIDTH=1024,HEIGHT=600,CHECK_DISPLAY_LOCK=0)(
 input wire I_rst_n,I_ddr_clk,
 input wire I_display_lock,I_pixel_rst_n,
 output wire O_video_out_rd_busy,input wire I_video_in_wr_busy,
 input wire [1:0] I_video_out_rp,
 input wire I_completed_valid,input wire [1:0] I_completed_rp,
 output reg O_active_valid,output reg [1:0] O_active_rp,
 output wire O_ddr_user_rd_en,output reg [24:0] O_ddr_user_addr,
 input wire I_ddr_user_ready,I_ddr_user_rd_valid,input wire [127:0] I_ddr_user_rd_data,
 input wire I_dsi_clk,I_video_vsync,I_video_rd_en,
 output reg [23:0] O_vdieo_data,
 output reg O_display_ok,output reg [15:0] O_underflow_frames
);
localparam WORDS=WIDTH*HEIGHT*3/16;
localparam WORD_BITS=$clog2(WORDS+1);
localparam PREFILL=WIDTH*3/16;
localparam DRAIN=0,CLEAR=1,RUN=2,WAIT_FRAME=3;
reg [1:0] state;
reg [3:0] reset_count;
reg [2:0] vs_sync;
reg [1:0] lock_sync;
reg need_boundary;
wire display_locked=!CHECK_DISPLAY_LOCK || lock_sync[1];
wire pixel_rst_n=I_rst_n && (!CHECK_DISPLAY_LOCK || I_pixel_rst_n);
wire S_video_frame_start=vs_sync[1] && !vs_sync[2];
wire S_fifo_rst=!I_rst_n || state==CLEAR;
wire [8:0] S_fifo_wr_num,S_fifo_rd_num;
wire S_fifo_emtpy,fifo_full;
wire [127:0] S_fifo_rd_data;
reg [8:0] outstanding,burst_left;
reg [WORD_BITS-1:0] issued;
reg S_ddr_rd_valid,return_bad;
wire [9:0] reserved={1'b0,S_fifo_wr_num}+{1'b0,outstanding};
// Read burst capacity is independent of the writer's 120-word line credit.
wire S_ddr_rd_trig=state==RUN && display_locked && O_active_valid && !return_bad &&
 !S_video_frame_start && !I_video_in_wr_busy && !S_ddr_rd_valid &&
 outstanding==0 && issued<WORDS && reserved<=271;
assign O_ddr_user_rd_en=S_ddr_rd_valid && I_ddr_user_ready &&
 state==RUN && display_locked && !S_video_frame_start;
assign O_video_out_rd_busy=S_ddr_rd_trig || S_ddr_rd_valid;
function [24:0] base;
 input [1:0] slot;
 begin case(slot)
  0:base=0;1:base=7000000;2:base=14000000;3:base=21000000;
 endcase end
endfunction
always @(posedge I_ddr_clk or negedge I_rst_n) begin
 if(!I_rst_n) begin
  state<=DRAIN;reset_count<=0;vs_sync<=0;lock_sync<=0;
  need_boundary<=CHECK_DISPLAY_LOCK;outstanding<=0;issued<=0;
  burst_left<=0;S_ddr_rd_valid<=0;O_ddr_user_addr<=0;
  O_active_valid<=0;O_active_rp<=0;return_bad<=0;
 end else begin
  vs_sync<={vs_sync[1:0],I_video_vsync};
  lock_sync<={lock_sync[0],I_display_lock};
  case({O_ddr_user_rd_en,I_ddr_user_rd_valid && outstanding!=0})
   2'b10:outstanding<=outstanding+1'b1;
   2'b01:outstanding<=outstanding-1'b1;
   default:outstanding<=outstanding;
  endcase
  if(state==RUN && I_ddr_user_rd_valid && fifo_full) return_bad<=1;
  if(O_ddr_user_rd_en) begin
   issued<=issued+1'b1;O_ddr_user_addr<=O_ddr_user_addr+25'd8;
   burst_left<=burst_left-1'b1;
   if(burst_left==1) S_ddr_rd_valid<=0;
  end
  if(S_ddr_rd_trig) begin
   S_ddr_rd_valid<=1;
   burst_left<=WORDS-issued<240 ? WORDS-issued : 240;
  end
  if(state==DRAIN && outstanding==0) begin
   state<=CLEAR;reset_count<=0;issued<=0;return_bad<=0;
   O_active_valid<=I_completed_valid && display_locked && !need_boundary;O_active_rp<=I_completed_rp;
   O_ddr_user_addr<=base(I_completed_rp);
  end else if(state==CLEAR) begin
   if(display_locked) begin
    reset_count<=reset_count+1'b1;
    if(reset_count==10) state<=need_boundary ? WAIT_FRAME : RUN;
   end else reset_count<=0;
  end
  if(S_video_frame_start && display_locked) begin
   state<=DRAIN;S_ddr_rd_valid<=0;need_boundary<=0;
  end
  // DDR clock continues even when the pixel clock has stopped. Do not clear
  // outstanding or reset the FIFO until every accepted old read has returned.
  if(!display_locked) begin
   need_boundary<=1;S_ddr_rd_valid<=0;O_active_valid<=0;
   if(state!=DRAIN && state!=CLEAR) state<=DRAIN;
  end
 end
end
reg [1:0] armed_sync,bad_sync;
reg vs_previous,display_bad,first_pixel;
reg [3:0] S_fifo_rd_cnt,S_fifo_rd_cnt_1d;
reg S_video_rd_en_1d;
reg [127:0] S_fifo_rd_data_1d;
wire need_word=I_video_rd_en &&
 (S_fifo_rd_cnt==0 || S_fifo_rd_cnt==5 || S_fifo_rd_cnt==10);
wire unavailable=!pixel_rst_n || !armed_sync[1] || bad_sync[1] ||
 (first_pixel && S_fifo_rd_num<PREFILL) || (need_word && S_fifo_emtpy);
wire S_fifo_rd_en=need_word && !display_bad && !unavailable;
w128_d512_fifo U_w128_d512_fifo(
 .rst(S_fifo_rst),.clkw(I_ddr_clk),
 .we(I_ddr_user_rd_valid && outstanding!=0 && state==RUN && display_locked && !S_video_frame_start),
 .di(I_ddr_user_rd_data),.wrusedw(S_fifo_wr_num),.afull(),.full_flag(fifo_full),
 .clkr(I_dsi_clk),.re(S_fifo_rd_en),.dout(S_fifo_rd_data),
 .rdusedw(S_fifo_rd_num),.valid(),.empty_flag(S_fifo_emtpy),.aempty());
always @(posedge I_dsi_clk or negedge pixel_rst_n) begin
 if(!pixel_rst_n) begin
  armed_sync<=0;bad_sync<=0;vs_previous<=0;display_bad<=1;first_pixel<=1;
  S_fifo_rd_cnt<=0;S_fifo_rd_cnt_1d<=0;S_video_rd_en_1d<=0;
  S_fifo_rd_data_1d<=0;O_vdieo_data<=0;O_display_ok<=0;
 end else begin
  armed_sync<={armed_sync[0],(state==RUN && O_active_valid && display_locked)};
  bad_sync<={bad_sync[0],return_bad};vs_previous<=I_video_vsync;
  if(I_video_vsync && !vs_previous) begin
   display_bad<=0;first_pixel<=1;S_fifo_rd_cnt<=0;S_video_rd_en_1d<=0;
  end else begin
   if(I_video_rd_en) begin
    S_fifo_rd_cnt<=S_fifo_rd_cnt+1'b1;first_pixel<=0;
    if(unavailable && !display_bad) begin
     display_bad<=1;O_display_ok<=0;
    end else if(first_pixel && !display_bad) O_display_ok<=1;
   end else S_fifo_rd_cnt<=0;
   S_video_rd_en_1d<=I_video_rd_en && !display_bad && !unavailable;
  end
  S_fifo_rd_cnt_1d<=S_fifo_rd_cnt;S_fifo_rd_data_1d<=S_fifo_rd_data;
  if(S_video_rd_en_1d && !display_bad && !bad_sync[1]) begin
   case(S_fifo_rd_cnt_1d)
    0:O_vdieo_data<=S_fifo_rd_data[127:104];
    1:O_vdieo_data<=S_fifo_rd_data[103:80];
    2:O_vdieo_data<=S_fifo_rd_data[79:56];
    3:O_vdieo_data<=S_fifo_rd_data[55:32];
    4:O_vdieo_data<=S_fifo_rd_data[31:8];
    5:O_vdieo_data<={S_fifo_rd_data_1d[7:0],S_fifo_rd_data[127:112]};
    6:O_vdieo_data<=S_fifo_rd_data[111:88];
    7:O_vdieo_data<=S_fifo_rd_data[87:64];
    8:O_vdieo_data<=S_fifo_rd_data[63:40];
    9:O_vdieo_data<=S_fifo_rd_data[39:16];
    10:O_vdieo_data<={S_fifo_rd_data_1d[15:0],S_fifo_rd_data[127:120]};
    11:O_vdieo_data<=S_fifo_rd_data[119:96];
    12:O_vdieo_data<=S_fifo_rd_data[95:72];
    13:O_vdieo_data<=S_fifo_rd_data[71:48];
    14:O_vdieo_data<=S_fifo_rd_data[47:24];
    15:O_vdieo_data<=S_fifo_rd_data[23:0];
   endcase
  end else O_vdieo_data<=0;
 end
end
// Preserve the diagnostic counter across HDMI-only resets.
always @(posedge I_dsi_clk or negedge I_rst_n) begin
 if(!I_rst_n) O_underflow_frames<=0;
 else if(pixel_rst_n && I_video_rd_en && unavailable && !display_bad && armed_sync[1])
  O_underflow_frames<=O_underflow_frames+1'b1;
end
endmodule
