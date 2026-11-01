// Exact production motor register body, not a second implementation.
module extracted_production_motor(input S_process_clk,S_rst_n,input [2:0] relay_mode,input relay_feed,relay_alarm,output O_relay_control);
parameter ENABLE_AUTO_RELAY=1;
wire relay_auto=relay_mode==1 || relay_mode==2;
wire relay_paused=relay_mode==2;
reg motor_output;
always @(posedge S_process_clk or negedge S_rst_n)
 if(!S_rst_n)motor_output<=0;
 else motor_output<=ENABLE_AUTO_RELAY && !relay_alarm && (relay_mode==3 || (relay_auto && !relay_paused && relay_feed));
assign O_relay_control=motor_output;
endmodule
