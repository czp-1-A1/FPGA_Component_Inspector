module pocket_run_controls #(parameter CLK_HZ=24074074,HOLD_MS=1000,DEBOUNCE_MS=20)(
 input wire clk,rst_n,input wire [3:0] buttons,output reg [16:0] request
);
reg [3:0] meta,sync,stable;reg [$clog2(CLK_HZ/1000)-1:0] divider;
reg [9:0] debounce,held;reg fired;reg [1:0] selected;
wire tick=divider==CLK_HZ/1000-1;
wire [1:0] chord=((stable & 4'b1100)==4'b1100) ? 2 : ((stable & 4'b1001)==4'b1001) ? 1 : 0;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin meta<=0;sync<=0;stable<=0;divider<=0;debounce<=0;held<=0;fired<=0;selected<=0;request<=0;end
 else begin
  meta<=~buttons;sync<=meta;divider<=tick ? 0 : divider+1'b1;
  if(tick)begin
   if(stable!=sync)begin if(debounce==DEBOUNCE_MS-1)begin stable<=sync;debounce<=0;end else debounce<=debounce+1'b1;end
   else debounce<=0;
   if(stable==0)begin fired<=0;held<=0;selected<=0;end
   else if(!fired)begin
    if(chord==0 || selected!=chord)begin held<=0;selected<=chord;end
    else if(held==HOLD_MS-1)begin request<={request[16:1]+16'd1,chord==2};fired<=1;held<=0;end
    else held<=held+1'b1;
   end
  end
 end
end
endmodule

// V3: one debounced press per release. The command and motor mode share one
// held CDC payload, so a new RUN cannot arrive with the previous permission.
// K1=new automatic RUN, K2=pause/resume (manual motor when idle), K3=clear,
// K4=stop. SW3 up stops; its next down edge starts a fresh RUN.
module pocket_key_motor_controls #(parameter CLK_HZ=24074074,DEBOUNCE_MS=20)(
 input wire clk,rst_n,start_switch,input wire [3:0] buttons,
 output wire [19:0] request
);
 localparam IDLE=0,AUTO=1,PAUSED=2,MANUAL=3,MANUAL_PAUSED=4;
 localparam DB=CLK_HZ/1000>1 ? $clog2(CLK_HZ/1000) : 1;
 (* async_reg="true" *) reg [1:0] sw_sync;
 (* async_reg="true" *) reg [3:0] button_meta,button_sync;
 reg [3:0] candidate,stable_buttons,armed;
 reg [9:0] debounce[0:3];reg [9:0] sw_debounce;
 reg sw_candidate,sw_stable,sw_armed;
 reg [DB-1:0] divider;
 reg [16:0] command;reg [2:0] mode;
 wire tick=divider==CLK_HZ/1000-1;
 wire [3:0] press;
 wire sw_change=sw_sync[1]==sw_candidate && sw_debounce==DEBOUNCE_MS-1 && sw_stable!=sw_candidate;
 wire sw_up=sw_change && sw_candidate;
 wire sw_down=sw_change && !sw_candidate && sw_armed;
 genvar g;
 generate for(g=0;g<4;g=g+1)begin : edges
  assign press[g]=button_sync[g]==candidate[g] && debounce[g]==DEBOUNCE_MS-1 &&
   candidate[g] && !stable_buttons[g] && armed[g];
 end endgenerate
 assign request={mode,command};
 integer k;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   sw_sync<=3;button_meta<=0;button_sync<=0;candidate<=15;stable_buttons<=15;armed<=0;
   sw_candidate<=1;sw_stable<=1;sw_armed<=0;sw_debounce<=0;divider<=0;command<=0;mode<=IDLE;
   for(k=0;k<4;k=k+1)debounce[k]<=0;
  end else begin
   sw_sync<={sw_sync[0],start_switch};button_meta<=~buttons;button_sync<=button_meta;
   divider<=tick ? 0 : divider+1'b1;
   if(tick)begin
    for(k=0;k<4;k=k+1)begin
     if(button_sync[k]!=candidate[k])begin candidate[k]<=button_sync[k];debounce[k]<=0;end
     else if(debounce[k]<DEBOUNCE_MS-1)debounce[k]<=debounce[k]+1'b1;
     else begin
      stable_buttons[k]<=candidate[k];
      if(!candidate[k])armed[k]<=1;else if(press[k])armed[k]<=0;
     end
    end
    if(sw_sync[1]!=sw_candidate)begin sw_candidate<=sw_sync[1];sw_debounce<=0;end
    else if(sw_debounce<DEBOUNCE_MS-1)sw_debounce<=sw_debounce+1'b1;
    else begin sw_stable<=sw_candidate;if(sw_candidate)sw_armed<=1;else if(sw_change)sw_armed<=0;end
    if(press[2])begin command<={command[16:1]+16'd1,1'b1};mode<=IDLE;end
    else if(press[3] || sw_up)mode<=IDLE;
    else if(press[0] || sw_down)begin command<={command[16:1]+16'd1,1'b0};mode<=AUTO;end
    else if(press[1])case(mode)
     AUTO:mode<=PAUSED;
     PAUSED:mode<=AUTO;
     MANUAL:mode<=MANUAL_PAUSED;
     default:mode<=MANUAL;
    endcase
   end
  end
 end
endmodule

// Physical SW3: up=1, down=0. Start only on a debounced up-to-down edge.
// Power-up with SW3 down does not auto-start. Up rearms; holding down cannot
// restart repeatedly. K3+K4 is the only button command, held 1s to clear all.
module pocket_switch_run_controls #(parameter CLK_HZ=24074074,HOLD_MS=1000,DEBOUNCE_MS=20)(
 input wire clk,rst_n,start_switch,input wire [3:0] buttons,output reg [16:0] request
);
 (* async_reg="true" *) reg [1:0] sw_sync;
 (* async_reg="true" *) reg [3:0] button_meta,button_sync;
 reg sw_stable,sw_candidate,sw_armed,clear_fired;reg [3:0] stable_buttons;
 reg [$clog2(CLK_HZ/1000)-1:0] divider;
 reg [9:0] sw_debounce,button_debounce,held;
 wire tick=divider==CLK_HZ/1000-1;
 wire clear_chord=(stable_buttons & 4'b1100)==4'b1100;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   sw_sync<=3;button_meta<=0;button_sync<=0;sw_stable<=1;sw_candidate<=1;sw_armed<=0;
   clear_fired<=0;stable_buttons<=0;divider<=0;sw_debounce<=0;button_debounce<=0;held<=0;request<=0;
  end else begin
   sw_sync<={sw_sync[0],start_switch};button_meta<=~buttons;button_sync<=button_meta;
   divider<=tick ? 0 : divider+1'b1;
   if(tick)begin
    if(sw_sync[1]!=sw_candidate)begin sw_candidate<=sw_sync[1];sw_debounce<=0;end
    else if(sw_debounce<DEBOUNCE_MS-1)sw_debounce<=sw_debounce+1'b1;
    else begin
     sw_stable<=sw_candidate;
     if(sw_candidate && !clear_fired)sw_armed<=1;
     else if(sw_stable && !sw_candidate)begin
      sw_armed<=0;
      if(sw_armed && !clear_chord && !clear_fired && button_sync==0)request<={request[16:1]+16'd1,1'b0};
     end
    end
    if(stable_buttons!=button_sync)begin
     if(button_debounce==DEBOUNCE_MS-1)begin stable_buttons<=button_sync;button_debounce<=0;end
     else button_debounce<=button_debounce+1'b1;
    end else button_debounce<=0;
    if(!clear_chord)held<=0;
    else if(!clear_fired)begin
     if(held==HOLD_MS-1)begin request<={request[16:1]+16'd1,1'b1};clear_fired<=1;held<=0;sw_armed<=0;end
     else held<=held+1'b1;
    end
    if(stable_buttons==0)clear_fired<=0;
   end
  end
 end
endmodule
