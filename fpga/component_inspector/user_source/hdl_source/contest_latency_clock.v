// RL7 demo instruments. No classifier, motor, or video-flow decisions here.
// Time is one microsecond, modulo 2^32; both clock crossings use registered
// Gray time. Valid CSI SOF follows packet decoding, after clock resumption.
module contest_latency_clock #(parameter CLK_HZ=100000000)(
 input wire clk,rst_n,output reg [31:0] us_gray
);
localparam DIV=CLK_HZ/1000000, DB=DIV>1 ? $clog2(DIV) : 1;
reg [DB-1:0] divider;reg [31:0] us_binary;
wire [31:0] next_us=us_binary+1'b1;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin divider<=0;us_binary<=0;us_gray<=0;end
 else if(divider==DIV-1)begin
  divider<=0;us_binary<=next_us;us_gray<=next_us^(next_us>>1);
 end else divider<=divider+1'b1;
end
endmodule

module contest_latency_capture(
 input wire clk,rst_n,input wire [31:0] us_gray,
 output wire [31:0] time_us,output wire time_valid
);
(* async_reg="true" *) reg [31:0] gray_meta,gray_sync;
reg [2:0] warm;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin gray_meta<=0;gray_sync<=0;warm<=0;end
 else begin gray_meta<=us_gray;gray_sync<=gray_meta;warm<={warm[1:0],1'b1};end
end
function [31:0] binary;input [31:0] g;integer i;begin
 binary[31]=g[31];for(i=30;i>=0;i=i-1)binary[i]=binary[i+1]^g[i];
end endfunction
assign time_us=binary(gray_sync);assign time_valid=&warm;
endmodule

// The tuple is sampled at the FIRST actual HDMI valid pixel of every raster,
// including a repeated source frame. No FPS-derived time, slot-ID age guess,
// or detector-ready timestamp is used. Serial division/BCD finish in48 clocks, before OSD row8.
module contest_latency_display(
 input wire clk,rst_n,input wire [31:0] us_gray,
 input wire vs,de,frame_valid,input wire [64:0] capture_info,
 input wire [31:0] latest_source,
 output reg sample_new,sample_valid,output reg [15:0] latency_ms10,frame_lag,
 output reg [31:0] source_frame,output reg [39:0] source_bcd,
 output reg [19:0] latency_bcd,output reg [11:0] lag_bcd
);
(* async_reg="true" *) reg [31:0] gray_meta,gray_sync;
reg [2:0] warm;reg first_pixel;
reg busy,pending_valid;reg [5:0] step;
reg [31:0] dividend,quotient,id_shift,id_pending;reg [6:0] remainder;
reg [39:0] bcd_work,bcd_adjust;
reg [15:0] lag_pending,ms_pending,ms_shift,lag_shift;
reg [39:0] source_bcd_pending;
reg [19:0] decimal_work,decimal_adjust;
reg [11:0] lag_work,lag_adjust;
reg [63:0] observed_capture;reg expired;reg [1:0] tag_warm;
function [31:0] binary;input [31:0] g;integer i;begin
 binary[31]=g[31];for(i=30;i>=0;i=i-1)binary[i]=binary[i+1]^g[i];
end endfunction
wire [31:0] elapsed=binary(gray_sync)-capture_info[31:0];
wire [31:0] lag=latest_source-capture_info[63:32];
wire [7:0] next_remainder={remainder,dividend[31]};
wire subtract=next_remainder>=100;
wire [31:0] next_quotient={quotient[30:0],subtract};
integer j;
always @*begin
 decimal_adjust=decimal_work;lag_adjust=lag_work;
 for(j=0;j<5;j=j+1)if(decimal_work[j*4+:4]>=5)decimal_adjust[j*4+:4]=decimal_work[j*4+:4]+3;
 for(j=0;j<3;j=j+1)if(lag_work[j*4+:4]>=5)lag_adjust[j*4+:4]=lag_work[j*4+:4]+3;
 bcd_adjust=bcd_work;
 for(j=0;j<10;j=j+1)if(bcd_work[j*4+:4]>=5)bcd_adjust[j*4+:4]=bcd_work[j*4+:4]+3;
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  gray_meta<=0;gray_sync<=0;warm<=0;first_pixel<=1;busy<=0;step<=0;
  sample_new<=0;sample_valid<=0;latency_ms10<=0;frame_lag<=0;source_frame<=0;source_bcd<=0;
  pending_valid<=0;dividend<=0;quotient<=0;remainder<=0;id_shift<=0;id_pending<=0;
  bcd_work<=0;lag_pending<=0;ms_pending<=0;ms_shift<=0;lag_shift<=0;
  source_bcd_pending<=0;decimal_work<=0;lag_work<=0;latency_bcd<=0;lag_bcd<=0;
  observed_capture<=0;expired<=0;tag_warm<=0;
 end else begin
  gray_meta<=us_gray;gray_sync<=gray_meta;warm<={warm[1:0],1'b1};sample_new<=0;
  // Once an unchanged image ages out, a full timer wrap must not revive it.
  // The pixel clock keeps running even while the sensor is stopped.
  if(capture_info[63:0]!=observed_capture)begin observed_capture<=capture_info[63:0];expired<=0;tag_warm<=0;end
  else begin
   if(!(&tag_warm))tag_warm<=tag_warm+1'b1;
   if(capture_info[64] && (&warm) && (&tag_warm) && elapsed>32'd6553599)expired<=1;
  end
  if(vs)first_pixel<=1;
  if(!vs && de && first_pixel)begin
   first_pixel<=0;busy<=1;step<=0;dividend<=elapsed;quotient<=0;remainder<=0;
   id_shift<=capture_info[63:32];id_pending<=capture_info[63:32];bcd_work<=0;
   // Limit display to6553.5ms. A future/unbound tuple must show unavailable,
   // never a wrapped plausible value. Unsigned subtraction supports timer wrap.
   pending_valid<=(&warm) && frame_valid && capture_info[64] &&
       elapsed<=32'd6553599 && lag<32'h80000000 &&
       !(expired && capture_info[63:0]==observed_capture);
   lag_pending<=lag>999 ? 16'd999 : lag[15:0];
  end else if(busy)begin
   if(!frame_valid)pending_valid<=0;
   if(step<32)begin
    dividend<={dividend[30:0],1'b0};quotient<=next_quotient;
    remainder<=subtract ? next_remainder-100 : next_remainder[6:0];
    id_shift<={id_shift[30:0],1'b0};bcd_work<={bcd_adjust[38:0],id_shift[31]};
    if(step==31)begin
     ms_pending<=next_quotient[15:0];ms_shift<=next_quotient[15:0];lag_shift<=lag_pending;
     source_bcd_pending<={bcd_adjust[38:0],id_shift[31]};decimal_work<=0;lag_work<=0;
    end
   end else begin
    ms_shift<={ms_shift[14:0],1'b0};lag_shift<={lag_shift[14:0],1'b0};
    decimal_work<={decimal_adjust[18:0],ms_shift[15]};
    lag_work<={lag_adjust[10:0],lag_shift[15]};
    if(step==47)begin
     busy<=0;sample_new<=1;sample_valid<=pending_valid && frame_valid;
     latency_ms10<=pending_valid ? ms_pending : 16'd0;
     frame_lag<=pending_valid ? lag_pending : 16'd0;
     source_frame<=id_pending;source_bcd<=source_bcd_pending;
     latency_bcd<={decimal_adjust[18:0],ms_shift[15]};lag_bcd<={lag_adjust[10:0],lag_shift[15]};
    end
   end
   if(step!=47)step<=step+1'b1;
  end
 end
end
endmodule

// C12 board buzzer: active low. Alarm starts a fresh200ms burst, followed by
// 300ms silence. Low/high2kHz waveform exists only inside the enabled burst.
module contest_buzzer #(parameter CLK_HZ=100000000,TONE_HZ=2000,ON_MS=200,OFF_MS=300)(
 input wire clk,rst_n,alarm,output reg O_buzzer_n
);
localparam HALF=CLK_HZ/(TONE_HZ*2),TB=HALF>1 ? $clog2(HALF) : 1;
localparam MS=CLK_HZ/1000,MB=MS>1 ? $clog2(MS) : 1;
localparam CB=$clog2(ON_MS+OFF_MS);
reg [TB-1:0] tone_count;reg [MB-1:0] ms_count;reg [CB-1:0] phase_ms;
reg alarm_d;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin O_buzzer_n<=1;tone_count<=0;ms_count<=0;phase_ms<=0;alarm_d<=0;end
 else begin
  alarm_d<=alarm;
  if(!alarm)begin O_buzzer_n<=1;tone_count<=0;ms_count<=0;phase_ms<=0;end
  else if(!alarm_d)begin O_buzzer_n<=0;tone_count<=0;ms_count<=0;phase_ms<=0;end
  else begin
   if(ms_count==MS-1)begin
    ms_count<=0;phase_ms<=phase_ms==ON_MS+OFF_MS-1 ? 0 : phase_ms+1'b1;
    if(phase_ms==ON_MS-1)begin O_buzzer_n<=1;tone_count<=0;end
    else if(phase_ms==ON_MS+OFF_MS-1)begin O_buzzer_n<=0;tone_count<=0;end
   end else ms_count<=ms_count+1'b1;
   if(phase_ms<ON_MS && !(ms_count==MS-1 && phase_ms==ON_MS-1))begin
    if(tone_count==HALF-1)begin tone_count<=0;O_buzzer_n<=!O_buzzer_n;end
    else tone_count<=tone_count+1'b1;
   end else if(phase_ms>=ON_MS && !(ms_count==MS-1 && phase_ms==ON_MS+OFF_MS-1))begin
    O_buzzer_n<=1;tone_count<=0;
   end
  end
 end
end
endmodule
