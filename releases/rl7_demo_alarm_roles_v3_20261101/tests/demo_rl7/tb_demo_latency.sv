`timescale 1ns/1ps
module tb_demo_latency;
reg clk=0;always #6.7 clk=~clk;
reg refclk=0;always #5 refclk=~refclk;
reg cclk=0,crun=1;always #4.444 if(crun)cclk=~cclk;
reg rst_n=0,vs=0,de=0,frame_valid=1;
reg [31:0] gray=0,latest=0;reg [64:0] capture_info=0;
wire fresh,valid;wire [15:0] ms10,lag;wire [31:0] source;wire [39:0] source_bcd;
contest_latency_display dut(clk,rst_n,gray,vs,de,frame_valid,capture_info,latest,fresh,valid,ms10,lag,source,source_bcd);
wire [31:0] actual_gray,capture_us;wire capture_valid;
contest_latency_clock clocker(refclk,rst_n,actual_gray);
contest_latency_capture capturer(cclk,rst_n,actual_gray,capture_us,capture_valid);
integer checks=0,i;reg [31:0] actual_bin,old_bin,now_us,cap_us,id,expect_lag,n;
reg [39:0] expected_bcd;reg expected_valid;
function [31:0] binary(input [31:0] g);
 reg[31:0] b;integer j;begin b[31]=g[31];for(j=30;j>=0;j--)b[j]=b[j+1]^g[j];return b;end
endfunction
task ht(input integer count);repeat(count)@(negedge clk);endtask
task measure(input [31:0] now_value,cap_value,frame_id,latest_id,input bit good);
 reg[31:0] elapsed;reg[39:0] wanted;reg[31:0] temp;
 begin
  gray=now_value^(now_value>>1);capture_info={good,frame_id,cap_value};latest=latest_id;
  vs=1;de=0;ht(6);vs=0;ht(2);de=1;ht(1);de=0;
  wait(fresh);#1;
  elapsed=now_value-cap_value;
  expected_valid=good && frame_valid && elapsed<=6553599 && (latest_id-frame_id)<32'h80000000;
  if(valid!==expected_valid)$fatal(1,"valid mismatch now%0d cap%0d id%0d",now_value,cap_value,frame_id);
  if(valid && ms10!=elapsed/100)$fatal(1,"measured time wrong %0d expected%0d",ms10,elapsed/100);
  expect_lag=latest_id-frame_id;if(expect_lag>999)expect_lag=999;
  if(valid && lag!=expect_lag)$fatal(1,"frame lag wrong");
  if(source!=frame_id)$fatal(1,"source tuple changed identity");
  wanted=0;temp=frame_id;
  for(integer d=0;d<10;d++)begin wanted[d*4+:4]=temp%10;temp=temp/10;end
  if(source_bcd!==wanted)$fatal(1,"full32-bit frame decimal conversion wrong id%0d bcd%h",frame_id,source_bcd);
  checks++;ht(3);
 end
endtask
initial begin
 ht(5);rst_n=1;ht(10);
 measure(100000,58600,1720,1721,1);
 measure(116667,58600,1720,1722,1); // SAME repeated frame gets greater real age.
 measure(200000,190000,70000,70000,1); // no16-bit source-number truncation.
 measure(1000,32'hfffffc18,32'hfffffffe,32'hffffffff,1); // time wrap.
 measure(1000000,999999,32'hffffffff,32'hffffffff,1);
 measure(12000000,1000,9,12,1); // stale/out-of-range: unavailable.
 measure(100,200,7,7,1); // future stamp: unavailable.
 measure(400,100,7,6,1); // future source ID: unavailable.
 measure(100000,58600,1720,1721,0); // missing stamp never fabricates latency.
 frame_valid=0;measure(100000,58600,1720,1721,1);if(valid)$fatal(1,"display invalid was ignored");frame_valid=1;
 crun=0;cclk=0;#100000;crun=1;repeat(4)@(negedge cclk);#1;
 if(!capture_valid || binary(actual_gray)-capture_us>1)$fatal(1,"CSI resumed after blanking did not reacquire common time before decoded SOF");
 $display("PASS DEMO LATENCY: %0d coherent samples, real age/repeats, wrap, full32-bit decimal ID, unavailable/future/stale guards",checks);$finish;
end
initial begin
 wait(rst_n);old_bin=0;
 for(i=0;i<300;i++)begin @(posedge refclk);#1;actual_bin=binary(actual_gray);
  if(i>2 && actual_bin-old_bin>1)$fatal(1,"time did not advance by registered1us Gray steps");
  if(i>2 && $countones(actual_gray^((old_bin>>1)^old_bin))>1)$fatal(1,"Gray bus changed multiple bits");
  old_bin=actual_bin;
 end
end
initial begin #200000;$fatal(1,"latency timeout");end
endmodule
