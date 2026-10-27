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
