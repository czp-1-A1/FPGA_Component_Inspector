`timescale 1ns/1ps
module tb_switch_recorder_controls;
 reg clk=0,rst_n=0;always #5 clk=~clk;
 reg sw=0;reg [3:0] buttons=15;wire [16:0] request;
 wire [15:0] exposure,gain;wire wb_tune,ae_req;wire [31:0] wb;
 reg ae_done=1;integer ack_count=0,checks=0;
 always @(posedge clk)begin
  if(ae_req)begin ae_done<=0;ack_count<=6;end
  else if(ack_count!=0)begin ack_count<=ack_count-1;if(ack_count==1)ae_done<=1;end
 end
 pocket_switch_run_controls #(.CLK_HZ(10000),.HOLD_MS(20),.DEBOUNCE_MS(2)) controls(clk,rst_n,sw,buttons,request);
 ae_set #(.COUNT_COMMANDS(1),.CLK_HZ(10000),.DEBOUNCE_MS(2),.HOLD_MS(50),.REPEAT_MS(10),.WB_HOLD_MS(20)) ae(
  .I_clk(clk),.I_rst(!rst_n),.I_btn(buttons),.I_ae_cfg_done(ae_done),.I_cam_cfg_done(1'b1),
  .O_ae_req(ae_req),.O_ae(exposure),.O_ag(gain),.O_wb_tune(wb_tune),.O_wb_request(wb));
 task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
 task check(input good,input [511:0] msg);begin checks++;if(!good)$fatal(1,"%s request=%h",msg,request);end endtask
 initial begin
  ticks(4);rst_n=1;ticks(100);check(request==0,"power-up down does not start");
  sw=1;ticks(60);sw=0;ticks(60);check(request==17'd2,"SW3 down edge starts");
  ticks(500);check(request==17'd2,"held SW3 single start");
  sw=1;ticks(60);check(request==17'd2,"SW3 up rearms only");
  repeat(5)begin sw=0;ticks(5);sw=1;ticks(5);end
  ticks(50);check(request==17'd2,"switch bounce rejected");
  sw=0;ticks(60);check(request==17'd4,"second down starts new run");
  buttons=6;ticks(400);buttons=15;ticks(100);check(request==17'd4,"K1+K4 no longer starts");
  buttons=7;ticks(45);buttons=3;ticks(300);check(request==17'd7,"staggered K4 then K3 clear");
  ticks(400);check(request==17'd7,"held clear one-shot");
  buttons=15;ticks(100);sw=1;ticks(60);sw=0;ticks(60);check(request==17'd8,"start after clear without reflash");
  buttons=11;ticks(45);buttons=3;ticks(300);check(request==17'd11,"staggered K3 then K4 clear");
  check(exposure==1092 && gain==40 && wb==32'h6464 && !wb_tune,"start/clear do not tune recipe");
  buttons=15;ticks(100);buttons=14;ticks(60);buttons=15;ticks(100);
  check(exposure==1076 && request==17'd11,"normal exposure key retained");
  buttons=11;ticks(60);buttons=15;ticks(100);check(gain==39,"normal gain key retained");
  // A switch transition while the clear chord is pressed cannot restart.
  sw=1;ticks(60);buttons=3;ticks(50);sw=0;ticks(300);
  check(request==17'd13,"clear has priority over concurrent start switch");
  $display("PASS switch recorder controls: %0d checks, E11 edge/boot/bounce/hold/key removal/clear/recipe",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"switch timeout");end
endmodule
