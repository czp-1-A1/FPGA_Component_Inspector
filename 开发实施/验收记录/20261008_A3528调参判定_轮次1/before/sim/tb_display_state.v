`timescale 1ns/1ps
module tb_display_state;
reg sclk=0,dclk=0,run_source=1,rst=0;
always #4.444 if(run_source) sclk=~sclk;
always #9.615 dclk=~dclk;
reg fs=0,bad=0,sv=0,sn=0,cal=1,cfg=1;
reg [15:0] ex=2244,ga=48,fps=27;
reg [7:0] mean=0,lo=0,hi=0;
wire [1:0] source_state,dest_state;
wire [27:0] sr,dr;wire valid;
roi_classifier classifier(sclk,rst,cal,fs,bad,sv,sn,mean,8'd58,1'b1,source_state);
roi_result_snapshot snapshot(sclk,rst,fs,bad,cal,sv,sn,source_state,mean,lo,hi,sr);
status_cdc #(.WIDTH(28)) mailbox(sclk,dclk,rst,sr,dr);
roi_display_state gate(dclk,rst,cfg,ex,ga,fps,cal,dr,18'd0,valid,dest_state);
task wait_dest;input integer n;begin repeat(n) @(negedge dclk);end endtask
task sample;input [7:0] v,mn,mx;input [1:0] expected;
reg old_token;
begin
 @(negedge sclk);fs=1;@(negedge sclk);fs=0;
 if(source_state!== (cal ? 1 : 0)) $fatal(1,"classifier FS freshness");
 repeat(12) @(negedge sclk);
 old_token=sr[27];mean=v;lo=mn;hi=mx;sv=1;sn=1;
 @(negedge sclk);sn=0;
 if(sr[27]!==old_token) $fatal(1,"published before classifier settled");
 @(negedge sclk);
 if(sr!=={~old_token,expected,1'b1,v,mn,mx}) $fatal(1,"mixed snapshot %h",sr);
 wait_dest(20);
 if(!valid || dest_state!==expected || dr[23:0]!=={v,mn,mx}) $fatal(1,"coherent mailbox sample %h state%d",dr,dest_state);
end endtask
reg [27:0] held;reg token;
initial begin
 wait_dest(4);rst=1;wait_dest(45);
 if(valid || dest_state!==1) $fatal(1,"startup fabricated sample");
 sample(85,27,255,2);held=sr;token=sr[27];
 repeat(5) begin
  @(negedge sclk);fs=1;@(negedge sclk);fs=0;wait_dest(12);
  if(sr!==held || !valid || dest_state!==2 || sr[27]!==token) $fatal(1,"normal FS/poll flicker");
 end
 sample(36,26,112,3);
 @(negedge sclk);bad=1;sv=0;@(negedge sclk);bad=0;wait_dest(20);
 if(valid || dest_state!==1) $fatal(1,"invalid sample retained");
 sv=1;wait_dest(20);if(valid) $fatal(1,"old fields rearmed without new sample");
 sample(86,28,254,2);
 cfg=0;wait_dest(2);if(valid || dest_state!==1) $fatal(1,"configuration priority");
 @(negedge sclk);sn=1;@(negedge sclk);sn=0;cfg=1;ex=2308;
 wait_dest(45);if(valid) $fatal(1,"old mailbox restored after parameter change");
 cal=0;sample(87,29,253,0);
 ex=2244;cal=1;wait_dest(45);if(valid) $fatal(1,"recipe return used old sample");
 sample(88,30,252,2);
 cal=0;wait_dest(20);if(dest_state!==0 || !valid) $fatal(1,"UNCAL lost statistics");
 cal=1;wait_dest(20);if(dest_state!==0) $fatal(1,"calibration return reused old classification");
 sample(37,25,110,3);
 @(negedge sclk);run_source=0;fps=0;wait_dest(4);
 if(valid || dest_state!==1) $fatal(1,"stopped CSI failed destination invalidation");
 fps=27;wait_dest(45);if(valid) $fatal(1,"frozen mailbox rearmed after FPS recovery");
 run_source=1;sample(85,27,255,2);
 @(negedge sclk);sn=1;@(negedge sclk);sn=0;fs=1;token=sr[27];
 @(negedge sclk);fs=0;if(sr[27]!==token) $fatal(1,"publication crossed FS");
 rst=0;wait_dest(3);rst=1;wait_dest(45);
 if(valid || dest_state!==1) $fatal(1,"reset restored classification");
 $display("PASS display state: coherent 28-bit real CDC; normal FS hold, bad frame, config, late old payload, recipe mismatch/return, stopped CSI, FPS recovery and reset require fresh sample");$finish;
end
initial begin #1000000;$fatal(1,"display state watchdog");end
endmodule
