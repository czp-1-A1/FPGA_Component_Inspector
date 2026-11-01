`timescale 1ns/1ps
module tb_restart_epoch;
 reg clk=0,rst_n=0,fs=0,commit=0,bad=0,sn=0;
 always #5 clk=~clk;
 reg [16:0] command=0;
 reg [63:0] config_tag=1;
 wire [511:0] live,record;
 wire ready;wire [1:0] events;
 integer checks=0,offset,step,b;
 dual_region_count_pipeline #(.STOP_CYCLES(4096),.PAGE_CYCLES(20000)) dut(
  .clk(clk),.rst_n(rst_n),.source_start(fs),.frame_commit(commit),.frame_bad(bad),.sample_new(sn),
  .config_tag(config_tag),.objects(608'd0),.empty_probe(32'd0),.command(command),
  .frame_record(record),.record_ready(ready),.live_record(live),.event_valid(events));
 task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
 task check(input logic good,input string msg);
  begin checks++;if(good!==1'b1)$fatal(1,"%s offset=%0d live=%h ready=%b",msg,offset,live,ready);end
 endtask
 task reset;
  begin rst_n=0;fs=0;commit=0;bad=0;sn=0;command=0;config_tag=1;ticks(4);rst_n=1;ticks(4);end
 endtask
 task pulse_fs;
  begin fs=1;ticks(1);fs=0;end
 endtask
 task complete_frame;
  begin commit=1;ticks(1);commit=0;ticks(2);sn=1;ticks(1);sn=0;ticks(200);end
 endtask
 task acquire_only;
  begin
   for(b=0;b<2;b++)begin
    check(live[b*256+48+:3]==1 && live[b*256+51+:4]==1,"restart inherited preceding epoch");
    check(live[b*256+32+:16]==2 && live[b*256+58+:36]==0,"restart generation/totals");
   end
   check(!ready && record==0 && events==0,"old metadata/event escaped restart");
  end
 endtask
 task lost(input logic invalid_frame);
  begin
   ticks(200);
   for(b=0;b<2;b++)check(live[b*256+48+:3]==3 && live[b*256+51+:4]==6,"genuine post-start fault lost C6");
   check((!invalid_frame || !ready) && events==0,"invalid frame cannot publish; no fault can count");
  end
 endtask
 always @(negedge clk)if(rst_n)check(events==0,"empty fixtures cannot count");
 initial begin
  // Restart at every processing-clock phase through capture, proof, result,
  // counter work and metadata assembly. No intervening FS is allowed to
  // make an old result or a latched old fault part of the new run.
  for(offset=1;offset<=150;offset++)begin
   reset();command=2;ticks(1);
   for(step=0;step<=151;step++)begin
    fs=step==0;commit=step==4;sn=step==8;
    if(step==offset)command=4;
    ticks(1);
   end
   fs=0;commit=0;sn=0;bad=1;ticks(3);commit=1;sn=1;ticks(1);
   bad=0;commit=0;sn=0;ticks(200);acquire_only();
   pulse_fs();complete_frame();
   check(ready && record[31:0]==2 && record[287:256]==2,"first complete post-command source epoch");
   check(record[47:32]==2 && record[303:288]==2,"both banks belong to new generation");
   // The first admitted source still requires full capture proof.
   pulse_fs();bad=1;ticks(1);bad=0;lost(1);
  end
  // Command and FS on the same edge admit that complete new source only;
  // failure of the preceding source cannot veto the explicit new run.
  reset();command=2;ticks(1);pulse_fs();ticks(3);
  command=4;fs=1;ticks(1);fs=0;complete_frame();
  check(ready && record[31:0]==2 && record[47:32]==2,"same-edge FS/restart");
  // Missing result/proof after joining a new source must still stop counting.
  pulse_fs();commit=1;ticks(1);commit=0;pulse_fs();lost(1);
  reset();command=2;ticks(1);pulse_fs();command=4;ticks(200);pulse_fs();ticks(2);pulse_fs();lost(1);
  // Waiting for the first new source cannot disable the source-stop timeout.
  reset();command=2;ticks(1);pulse_fs();command=4;ticks(4300);lost(1);
  // A config change within an admitted run remains a continuity error.
  reset();command=2;ticks(1);pulse_fs();complete_frame();config_tag=2;pulse_fs();complete_frame();lost(0);
  // Restart after an already latched C6 does not inherit its bad epoch.
  command=4;ticks(200);acquire_only();pulse_fs();complete_frame();
  check(ready && record[47:32]==2 && record[303:288]==2,"restart after latched LOST");
  $display("PASS RESTART_EPOCH: %0d checks, 150 command phases, dual fresh-source boundary, old-tail exclusion, same-edge FS, true faults, timeout, config and LOST restart",checks);
  $finish;
 end
 initial begin #20000000;$fatal(1,"restart epoch watchdog");end
endmodule
