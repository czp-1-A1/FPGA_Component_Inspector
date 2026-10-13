`timescale 1ns/1ps
module tb_wb_controls;
reg clk=0,rst=1,done=1;always #5 clk=~clk;
reg [3:0] btn=15;
wire req,tune;wire [15:0] ae,ag;wire [31:0] wb;
ae_set #(.CLK_HZ(10000),.DEBOUNCE_MS(3),.HOLD_MS(8),.REPEAT_MS(2),.WB_HOLD_MS(30)) dut(
 .I_clk(clk),.I_rst(rst),.I_btn(btn),.I_cam_cfg_done(1'b1),.I_ae_cfg_done(done),
 .O_ae_req(req),.O_ae(ae),.O_ag(ag),.O_wb_tune(tune),.O_wb_request(wb));
reg [3:0] busy=0;integer requests=0;
reg [31:0] held_camera;
always @(posedge clk) begin
 if(rst)begin done<=1;busy<=0;end
 else if(req)begin done<=0;busy<=10;held_camera<={ae,ag};requests=requests+1;end
 else if(busy!=0)begin
  if({ae,ag}!==held_camera)$fatal(1,"camera payload changed while busy");
  busy<=busy-1'b1;
 end else done<=1;
end
task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
task click;input [3:0] key;begin btn=key;ticks(45);btn=15;ticks(55);end endtask
task chord;begin
 btn=14;ticks(35);btn=12;ticks(370);
 if(ae!=2244 || ag!=48 || wb[15:0]!=16'h4040)$fatal(1,"chord changed parameters");
 ticks(400);btn=14;ticks(40);btn=15;ticks(60);
end endtask
integer i,previous_requests;reg [31:0] saved;
initial begin
 ticks(5);rst=0;ticks(20);
 if(tune || wb!==32'h00004040)$fatal(1,"WB reset");
 // A short two-key press is consumed without toggling or a release click.
 btn=12;ticks(100);btn=14;ticks(40);btn=15;ticks(60);
 if(tune || ae!=2244 || requests!=0)$fatal(1,"short chord leaked exposure");
 chord;if(!tune || requests!=0)$fatal(1,"long chord failed or repeated toggle");
 click(14);if(wb!==32'h00013f40)$fatal(1,"red decrement %h",wb);
 click(13);if(wb!==32'h00024040)$fatal(1,"red increment %h",wb);
 click(11);if(wb!==32'h0003403f)$fatal(1,"blue decrement %h",wb);
 click(7); if(wb!==32'h00044040)$fatal(1,"blue increment %h",wb);
 if(ae!=2244 || ag!=48 || requests!=0)$fatal(1,"WB keys reached camera writer");
 // Bounce, hold-repeat and both color clamps; saturating presses do not bump epoch.
 saved=wb;btn=14;ticks(10);btn=15;ticks(50);if(wb!==saved)$fatal(1,"WB bounce");
 btn=14;ticks(1000);btn=15;ticks(60);if(wb[15:8]!=32)$fatal(1,"red lower clamp");
 saved=wb;click(14);if(wb!==saved)$fatal(1,"epoch advanced at lower clamp");
 btn=13;ticks(3400);btn=15;ticks(60);if(wb[15:8]!=192)$fatal(1,"red upper clamp");
 btn=11;ticks(1000);btn=15;ticks(60);if(wb[7:0]!=32)$fatal(1,"blue lower clamp");
 btn=7;ticks(3400);btn=15;ticks(60);if(wb[7:0]!=192)$fatal(1,"blue upper clamp");
 saved=wb;btn=0;ticks(800);btn=15;ticks(60);
 if(tune || wb!==saved || requests!=0)$fatal(1,"exit chord leaked keys");
 click(14);if(ae!=2228 || wb!==saved)$fatal(1,"normal exposure did not resume");
 click(11);if(ag!=47 || wb!==saved)$fatal(1,"normal sensor gain did not resume");
 rst=1;ticks(5);rst=0;ticks(20);
 if(tune || wb!==32'h00004040 || ae!=2244 || ag!=48)$fatal(1,"reset defaults");
 $display("PASS WB controls: staggered/short/long chords, one toggle per release, four keys, no camera writes in WB, debounce, repeat, both clamps, epoch and normal controls restored");$finish;
end
initial begin #300000;$fatal(1,"WB controls watchdog");end
endmodule
