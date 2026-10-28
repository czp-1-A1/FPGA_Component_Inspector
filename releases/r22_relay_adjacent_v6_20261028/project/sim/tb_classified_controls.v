`timescale 1ns/1ps
module tb_classified_controls;
 reg clk=0,rst_n=0;always #5 clk=~clk;
 reg [3:0] buttons=15;wire [16:0] request;
 wire [15:0] exposure,gain;wire wb_tune,ae_req;wire [31:0] wb;
 reg ae_done=1;integer ack_count=0;
 always @(posedge clk)begin
  if(ae_req)begin ae_done<=0;ack_count<=6;end
  else if(ack_count!=0)begin ack_count<=ack_count-1;if(ack_count==1)ae_done<=1;end
 end
 pocket_run_controls #(.CLK_HZ(10000),.HOLD_MS(20),.DEBOUNCE_MS(2)) controls(clk,rst_n,buttons,request);
 ae_set #(.COUNT_COMMANDS(1),.CLK_HZ(10000),.DEBOUNCE_MS(2),.HOLD_MS(50),.REPEAT_MS(10),.WB_HOLD_MS(20)) ae(
  .I_clk(clk),.I_rst(!rst_n),.I_btn(buttons),.I_ae_cfg_done(ae_done),.I_cam_cfg_done(1'b1),
  .O_ae_req(ae_req),.O_ae(exposure),.O_ag(gain),.O_wb_tune(wb_tune),.O_wb_request(wb));
 task ticks(input integer count);begin repeat(count)@(negedge clk);end endtask
 task chord(input [3:0] first,second,input integer seq,input bit finish);
  begin
   buttons=~first;ticks(45);buttons=~second;ticks(300);
   if(request!={16'(seq),finish})$fatal(1,"hold command wrong");
   ticks(300);if(request!={16'(seq),finish})$fatal(1,"held chord repeated");
   buttons=~first;ticks(40);buttons=15;ticks(100);
   if(exposure!=1092 || gain!=40 || wb!=32'h6464 || wb_tune)$fatal(1,"count chord changed image recipe");
  end
 endtask
 initial begin
  ticks(4);rst_n=1;ticks(100);
  chord(8,9,1,0);chord(1,9,2,0);chord(8,12,3,1);chord(4,12,4,1);
  buttons=14;ticks(60);buttons=15;ticks(100);
  if(exposure!=1076 || request!={16'd4,1'b1})$fatal(1,"single exposure control lost");
  buttons=11;ticks(60);buttons=15;ticks(100);
  if(gain!=39)$fatal(1,"single gain control lost");
  $display("PASS classified controls: both stagger orders start/finish, one-shot held chords, recipe/WB unchanged, exposure/gain singles retained");$finish;
 end
 initial begin #1000000;$fatal(1,"control timeout");end
endmodule
