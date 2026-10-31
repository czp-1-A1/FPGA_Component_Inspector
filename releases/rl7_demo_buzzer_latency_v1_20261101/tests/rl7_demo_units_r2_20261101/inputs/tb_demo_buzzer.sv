`timescale 1ns/1ps
module tb_demo_buzzer;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,alarm=0;wire beep,real_beep;
contest_buzzer #(.CLK_HZ(1000000)) dut(clk,rst_n,alarm,beep);
contest_buzzer #(.CLK_HZ(100000000)) production(clk,rst_n,alarm,real_beep);
integer cycle,expected,half_edges=0,checks=0;
reg previous_real;
task tick;@(posedge clk);#1;endtask
initial begin
 repeat(5)tick();if(beep!==1 || real_beep!==1)$fatal(1,"reset is not silent");
 @(negedge clk);rst_n=1;repeat(20)tick();if(beep!==1)$fatal(1,"idle must stay silent");
 @(negedge clk);alarm=1;tick();
 if(beep!==0 || real_beep!==0)$fatal(1,"alarm must start a fresh active-low burst");
 previous_real=real_beep;
 // Two complete500ms cycles in the scaled1MHz instance. Test an independent
 // mathematical waveform, plus physical100MHz/250us half-period simultaneously.
 for(cycle=1;cycle<=1000000;cycle=cycle+1)begin
  tick();
  expected=(cycle%500000)<200000 ? ((cycle%500000)/250)%2 : 1;
  if(beep!==expected[0])$fatal(1,"envelope/tone cycle%0d got%b expected%0d",cycle,beep,expected);
  if(real_beep!=previous_real)begin
   if(cycle%25000!=0)$fatal(1,"100MHz tone edge not at250us cycle%0d",cycle);
   half_edges++;previous_real=real_beep;
  end
  checks++;
 end
 if(half_edges!=40)$fatal(1,"physical2kHz period count %0d",half_edges);
 @(negedge clk);alarm=0;tick();if(beep!==1 || real_beep!==1)$fatal(1,"alarm clear must silence immediately");
 repeat(31)tick();@(negedge clk);alarm=1;tick();if(beep!==0)$fatal(1,"retrigger did not restart envelope");
 repeat(37)tick();@(negedge clk);rst_n=0;tick();if(beep!==1 || real_beep!==1)$fatal(1,"reset during alarm not silent");
 $display("PASS DEMO BUZZER: %0d envelope clocks, two200/300ms cycles at1MHz; actual100MHz tone40 half-periods250us; active-low/reset/clear/retrigger",checks);$finish;
end
initial begin #20000000;$fatal(1,"buzzer timeout");end
endmodule
