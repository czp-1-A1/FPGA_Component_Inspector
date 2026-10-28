// Numbered EMPTY queue and measured-position stop. No predicted coordinates.
// Coordinates are PROCESSING pixels; factory values require field calibration.
module pocket_relay_stop #(
 parameter CLK_HZ=100000000, TARGET_X=760, ADVANCE_PX=24,
 parameter POSITION_TOL_PX=8, STILL_PX=2, HOLD_MS=1000,
 parameter STALE_MS=150, STOP_TIMEOUT_MS=1200, QUEUE_DEPTH=8,
 parameter EXPECT_RIGHT=1
)(
 input wire clk,rst_n,permit,start_run,clear_run,
 input wire good_frame,bad_frame,input wire [31:0] current_frame,
 input wire [15:0] counter_run,input wire [2:0] counter_state,
 input wire direction_valid,direction_right,
 input wire event_valid,input wire [15:0] event_run,
 input wire [8:0] event_id,input wire [1:0] event_kind,
 output wire [8:0] query_id,
 input wire position_new,input wire [8:0] position_id,
 input wire [15:0] position_run,input wire [31:0] position_frame,
 input wire [10:0] position_x,input wire [9:0] position_y,
 output reg feed_enable,output reg [2:0] state,output reg [3:0] fault,
 output wire [31:0] status,output reg cycle_done
);
 localparam IDLE=0,FEED=1,SETTLE=2,HOLD=3,FAULT=4;
 localparam DIV=CLK_HZ/1000;
 localparam DB=DIV>1 ? $clog2(DIV) : 1;
 localparam QB=$clog2(QUEUE_DEPTH);
 localparam PARAM_OK=CLK_HZ>=1000 && CLK_HZ%1000==0 && QUEUE_DEPTH>=2 &&
  (QUEUE_DEPTH&(QUEUE_DEPTH-1))==0 && QUEUE_DEPTH<=8 && HOLD_MS>=1 && HOLD_MS<=2047 &&
  STALE_MS>=2 && STALE_MS<255 && STOP_TIMEOUT_MS>=1 && STOP_TIMEOUT_MS<=2047 &&
  TARGET_X>POSITION_TOL_PX && TARGET_X<1280-POSITION_TOL_PX &&
  ADVANCE_PX>=0 && (EXPECT_RIGHT ? TARGET_X-ADVANCE_PX>644 : TARGET_X+ADVANCE_PX<636);
 (* ram_style="distributed" *) reg [8:0] queue[0:QUEUE_DEPTH-1];
 reg [QB-1:0] rd,wr;reg [QB:0] count;
 reg active;reg [15:0] active_run;reg [8:0] last_empty;
 reg [DB-1:0] divider;reg [7:0] frame_age,position_age;
 reg [10:0] phase_ms,last_x,anchor_x;reg [9:0] last_y,anchor_y;
 reg [1:0] stable;reg have_position,have_source;
 reg [31:0] last_position_frame;
 wire tick=divider==DIV-1;
 assign query_id=count!=0 ? queue[rd] : 9'd0;
 wire measured=position_new && count!=0 && position_id==query_id &&
  position_run==active_run && position_frame==current_frame &&
  (!have_source || position_frame!=last_position_frame);
 wire push=active && event_valid && event_kind==3 && event_run==active_run && event_id>last_empty;
 wire within_x=position_x>=TARGET_X-POSITION_TOL_PX && position_x<=TARGET_X+POSITION_TOL_PX;
 wire nearby=have_position && {1'b0,position_x}+STILL_PX>=last_x &&
  {1'b0,position_x}<=last_x+STILL_PX && {1'b0,position_y}+STILL_PX>=last_y &&
  {1'b0,position_y}<=last_y+STILL_PX;
 wire at_anchor={1'b0,position_x}+STILL_PX>=anchor_x && position_x<=anchor_x+STILL_PX &&
  {1'b0,position_y}+STILL_PX>=anchor_y && position_y<=anchor_y+STILL_PX;
 wire healthy=!bad_frame && counter_state!=3 && counter_state!=4 && counter_state!=6 &&
  (!direction_valid || direction_right==EXPECT_RIGHT) &&
  (!event_valid || event_run==active_run) && !(push && count==QUEUE_DEPTH);
 wire pop=active && state==HOLD && healthy && tick && phase_ms==HOLD_MS-1 &&
  position_age<STALE_MS-1 && frame_age<STALE_MS-1 && !bad_frame && permit &&
  !(measured && (!within_x || !at_anchor));
 assign status={state,fault,{{(3-QB){1'b0}},count},query_id,last_x,feed_enable};
 task fail;
  input [3:0] why;
  begin state<=FAULT;fault<=why;feed_enable<=0;end
 endtask
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;fault<=0;feed_enable<=0;active<=0;active_run<=0;
   rd<=0;wr<=0;count<=0;last_empty<=0;divider<=0;frame_age<=0;position_age<=0;
   phase_ms<=0;last_x<=0;last_y<=0;anchor_x<=0;anchor_y<=0;stable<=0;
   have_position<=0;have_source<=0;last_position_frame<=0;cycle_done<=0;
  end else begin
   cycle_done<=0;
   divider<=tick ? 0 : divider+1'b1;
   if(tick)begin
    if(frame_age!=255)frame_age<=frame_age+1'b1;
    if(position_age!=255)position_age<=position_age+1'b1;
    if((state==SETTLE || state==HOLD) && phase_ms!=2047)phase_ms<=phase_ms+1'b1;
   end
   if(good_frame)frame_age<=0;
   if(measured)begin
    last_position_frame<=position_frame;have_source<=1;position_age<=0;
    last_x<=position_x;last_y<=position_y;have_position<=1;
   end
   // Explicit R22 clear chord acknowledges/discards the current run queue.
   // A mere SW3 up/down cannot silently discard unresolved EMPTY records.
   if(clear_run)begin
    active<=0;state<=IDLE;fault<=0;feed_enable<=0;
    rd<=0;wr<=0;count<=0;last_empty<=0;have_position<=0;have_source<=0;
   end else if(start_run)begin
    if(count!=0)begin active<=0;fail(10);end
    else if(!PARAM_OK || !permit)begin active<=0;fail(11);end
    else begin
     active<=1;state<=FEED;fault<=0;feed_enable<=1;
     active_run<=counter_run+16'd1;last_empty<=0;rd<=0;wr<=0;count<=0;
     frame_age<=0;position_age<=0;phase_ms<=0;stable<=0;have_position<=0;have_source<=0;
    end
   end else if(!permit)begin active<=0;feed_enable<=0;if(state!=FAULT)state<=IDLE;end
   else if(active && state!=FAULT)begin
    // Queue mutation and faults are independent: a fault freezes queued IDs.
    if(push && count<QUEUE_DEPTH)begin queue[wr]<=event_id;wr<=wr+1'b1;last_empty<=event_id;end
    if(pop)begin
     rd<=rd+1'b1;cycle_done<=1;state<=FEED;feed_enable<=1;
     have_position<=0;have_source<=0;position_age<=0;stable<=0;phase_ms<=0;
    end
    case({push && count<QUEUE_DEPTH,pop})
     2'b10:count<=count+1'b1;
     2'b01:count<=count-1'b1;
     default:begin end
    endcase
    if(count==0 && push)begin have_position<=0;have_source<=0;position_age<=0;end
    if(bad_frame || counter_state==3 || counter_state==6 || counter_state==4)fail(1);
    else if(tick && frame_age>=STALE_MS-1 && !good_frame)fail(2);
    else if(direction_valid && direction_right!=EXPECT_RIGHT)fail(3);
    else if(event_valid && event_run!=active_run)fail(4);
    else if(push && count==QUEUE_DEPTH)fail(5);
    else if(count!=0 && tick && position_age>=STALE_MS-1 && !measured)fail(6);
    else case(state)
     FEED:if(measured)begin
      if(EXPECT_RIGHT ? position_x>TARGET_X+POSITION_TOL_PX : position_x<TARGET_X-POSITION_TOL_PX)fail(7);
      else if(EXPECT_RIGHT ? position_x>=TARGET_X-ADVANCE_PX : position_x<=TARGET_X+ADVANCE_PX)begin
       state<=SETTLE;feed_enable<=0;phase_ms<=0;stable<=0;have_position<=0;
      end
     end
     SETTLE:begin
      if(measured)begin
       if(within_x && nearby)begin
        if(stable==2)begin
         state<=HOLD;anchor_x<=position_x;anchor_y<=position_y;
         phase_ms<=0;divider<=0;
        end else stable<=stable+1'b1;
       end else stable<=within_x ? 1 : 0;
      end
      if(tick && phase_ms>=STOP_TIMEOUT_MS-1)fail(8);
     end
     HOLD:if(measured && (!within_x || !at_anchor))fail(9);
     default:begin end
    endcase
   end
  end
 end
endmodule
