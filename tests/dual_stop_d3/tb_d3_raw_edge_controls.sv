`timescale 1ns/1ps
module tb_d3_raw_edge_controls;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg [1:0] sw=0;wire [17:0] request;
 observation_controls #(.RAW_EDGE_ONLY(1),.STABLE_CYCLES(8)) dut(.clk(clk),.rst_n(rst),.switches(sw),.request(request));
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 initial begin
  ticks(4);rst=1;ticks(16);if(request!==0)$fatal(1,"power-on mode");
  sw=1;ticks(16);if(request!==0)$fatal(1,"SW1 must not change mode/epoch");
  sw=3;ticks(4);if(request!==0)$fatal(1,"unstable SW2 accepted");
  sw=1;ticks(16);if(request!==0)$fatal(1,"bounce changed mode");
  sw=2;ticks(16);if(request!==18'd6)$fatal(1,"SW2 should select epoch1 EDGE2");
  repeat(30)begin sw[0]=~sw[0];ticks(1);end
  ticks(16);if(request!==18'd6)$fatal(1,"SW1 interfered with EDGE epoch");
  sw=0;ticks(16);if(request!==18'd8)$fatal(1,"SW2 should select epoch2 RAW0");
  rst=0;ticks(2);if(request!==0)$fatal(1,"reset failed");
  sw=3;rst=1;ticks(16);if(request!==18'd6)$fatal(1,"held SW2 power-on selection failed");
  $display("PASS RAW_EDGE_CONTROLS: SW2 RAW0/EDGE2, SW1 ignored without epoch/debounce interference, stable20ms semantics, bounce/held/reset");$finish;
 end
 initial begin #100000;$fatal(1,"display controls watchdog");end
endmodule
