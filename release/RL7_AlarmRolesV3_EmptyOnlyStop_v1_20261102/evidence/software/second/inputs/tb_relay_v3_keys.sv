`timescale 1ns/1ps
module tb_relay_v3_keys;
 reg clk=0,dclk=0,rst=0,sw=0;reg [3:0] keys=15;
 always #5 clk=~clk;always #7 dclk=~dclk;
 wire [19:0] request,received;
 pocket_key_motor_controls #(.CLK_HZ(10000),.DEBOUNCE_MS(2)) dut(clk,rst,sw,keys,request);
 status_cdc #(.WIDTH(20)) cdc(clk,dclk,rst,request,received);
 integer checks=0,n;
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task check(input bit ok,input string why);begin checks++;if(!ok)$fatal(1,"%s req=%h rx=%h",why,request,received);end endtask
 task key(input integer n);begin keys=15^(1<<n);ticks(70);keys=15;ticks(70);end endtask
 initial begin
  ticks(5);rst=1;ticks(100);check(request==0,"power-up SW3 down must stay stopped");
  key(1);check(request[19:17]==3 && received==request,"K2 starts manual motor via held mailbox");
  key(1);check(request[19:17]==4,"K2 pauses manual motor");
  key(1);check(request[19:17]==3,"K2 resumes manual motor");
  key(3);check(request[19:17]==0 && request[16:0]==0,"K4 stops without clearing");
  key(0);check(request[19:17]==1 && request[16:0]==2,"K1 starts without switch operation");
  keys=13;ticks(500);check(request[19:17]==2 && request[16:0]==2,"held K2 pauses only once, keeps RUN");
  keys=15;ticks(100);key(1);check(request[19:17]==1 && request[16:0]==2,"K2 resumes same automatic RUN");
  key(0);check(request[16:0]==4 && request[19:17]==1,"K1 starts fresh RUN without clear");
  for(n=0;n<6;n++)begin
   sw=1;ticks(80);check(request[19:17]==0,"SW3 up stops");
   sw=0;ticks(80);check(request[19:17]==1 && request[16:0]==6+2*n,"every SW3 cycle starts once without clear");
  end
  keys=11;ticks(500);check(request[16:0]==19 && request[19:17]==0,"K3 clears on one press, no hold repeat");
  keys=15;ticks(100);key(0);check(request[16:0]==20 && request[19:17]==1,"run directly after clear");
  repeat(5)begin keys=14;ticks(4);keys=15;ticks(4);end
  ticks(100);check(request[16:0]==20,"key bounce rejected");
  sw=1;ticks(80);repeat(5)begin sw=0;ticks(4);sw=1;ticks(4);end
  ticks(100);check(request[16:0]==20 && request[19:17]==0,"switch bounce rejected");
  // A held power-up key cannot start; release then press is required.
  rst=0;keys=14;ticks(5);rst=1;ticks(150);check(request==0,"held boot K1 inhibited");
  keys=15;ticks(100);key(0);check(request[16:0]==2,"boot key rearms on release");
  $display("PASS V3 keys: %0d checks; single keys, both motor modes, CDC, six SW3 runs, bounce and held boot",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"key test timeout");end
endmodule
