`timescale 1ns/1ps
module tb_process_bridge;
reg sclk=0,dclk=0,run_s=1,run_d=1,checking=1,rst=0,valid=0;reg [127:0] data=0;
always #4.444 if(run_s)sclk=~sclk;
always #5 if(run_d)dclk=~dclk;
wire ov,overflow;wire [127:0] received;
frame_process_bridge dut(sclk,dclk,rst,data,valid,received,ov,overflow);
reg [127:0] expected[0:19999];integer sent=0,seen=0;
always @(posedge sclk)if(rst && valid)begin expected[sent]=data;sent++;end
always @(negedge dclk)if(rst && ov && checking)begin
 if(seen>=sent || received!==expected[seen])$fatal(1,"CDC event lost/reordered index=%0d expected=%h actual=%h",seen,expected[seen],received);
 seen++;
end
initial begin
 repeat(8)@(negedge sclk);rst=1;repeat(12)@(negedge sclk);
 for(integer row=0;row<24;row++)begin
  for(integer x=0;x<256;x++)begin
   @(negedge sclk);valid=1;data={32'(row),32'(x),32'(row*256+x),32'(~(row*256+x))};
   // Contiguous 112.5MHz burst stresses the slower continuous consumer.
  end
  @(negedge sclk);valid=0;repeat(98)@(negedge sclk);
 end
 repeat(3)@(negedge sclk);run_s=0;#20000;
 if(seen!=sent || overflow)$fatal(1,"stopped source did not drain ordered events sent=%0d seen=%0d",sent,seen);
 run_s=1;repeat(8)@(negedge sclk);
 for(integer x=0;x<2048;x++)begin
  @(negedge sclk);valid=x%3==0;data={32'h12345678,32'(x),32'(x*7),32'(x*13)};
 end
 @(negedge sclk);valid=0;repeat(8)@(negedge sclk);run_s=0;#20000;
 if(seen!=sent || overflow)$fatal(1,"resume/bubble CDC drain failed");
 checking=0;run_s=1;@(negedge dclk);run_d=0;
 for(integer x=0;x<700;x++)begin @(negedge sclk);valid=1;data=x;end
 @(negedge sclk);valid=0;run_d=1;#20000;
 if(!overflow)$fatal(1,"lost bridge records were not reported as overflow");
 rst=0;#100;rst=1;#200;
 if(overflow)$fatal(1,"bridge overflow did not clear on reset");
 $display("PASS process bridge: %0d exact 128-bit ordered payloads, asynchronous phases, dense/bubbled bursts, stopped source drain and resume, overflow latched until reset",seen);$finish;
end
initial begin #200000;$fatal(1,"process bridge watchdog");end
endmodule
