`timescale 1ns/1ps
module tb_demo_buzzer_real;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,alarm=0;wire beep;
contest_buzzer #(.CLK_HZ(100000000)) dut(clk,rst_n,alarm,beep);
integer i;time started;
task tick(input integer n);repeat(n)@(posedge clk);#1;endtask
initial begin
 tick(4);if(beep!==1)$fatal(1,"real reset not silent");
 @(negedge clk);rst_n=1;tick(4);
 @(negedge clk);alarm=1;tick(1);started=$time;if(beep!==0)$fatal(1,"real alarm not active-low");
 for(i=1;i<800;i++)begin
  tick(25000);if(beep!==i[0])$fatal(1,"actual100MHz2kHz half-period%0d mismatch",i);
 end
 tick(25000);if(beep!==1 || $time-started!=200000000)$fatal(1,"actual burst not exactly200ms");
 tick(15000000);if(beep!==1)$fatal(1,"silence interrupted");
 tick(15000000);if(beep!==0 || $time-started!=500000000)$fatal(1,"silence not exactly300ms/restart not active");
 @(negedge clk);alarm=0;tick(1);if(beep!==1)$fatal(1,"real alarm clear not silent");
 $display("PASS DEMO REAL BUZZER: actual100MHz50000000 clocks;2kHz250us half-periods;exact200ms ON300ms OFF;repeat/clear");$finish;
end
initial begin #510000000;$fatal(1,"real buzzer timeout");end
endmodule
