`timescale 1ns/1ps
module tb_observation;
reg ref_clk=0,rx_clk=0,dclk=0,rst=0,rx_running=1;
always #10 ref_clk=~ref_clk;
always #4 if(rx_running) rx_clk=~rx_clk;
always #9 dclk=~dclk;
reg [1:0] sw=0;wire [17:0] request,received,displayed;
observation_controls #(.STABLE_CYCLES(4)) controls(ref_clk,rst,sw,request);
status_cdc #(.WIDTH(18)) receive(ref_clk,rx_clk,rst,request,received);
status_cdc #(.WIDTH(18)) request_display(ref_clk,dclk,rst,request,displayed);
reg [17:0] tag=0;reg [27:0] legacy=0;
reg [12:0] cp=6400,ec=321;reg [23:0] strength=123456;
reg cfg=1;reg [15:0] ex=2244,ga=48,fps=27;
wire [82:0] source_record,record;
wire invalid=!cfg || tag!=received;
roi_observation_snapshot snapshot(rx_clk,rst,invalid,tag,legacy,cp,ec,strength,source_record);
status_cdc #(.WIDTH(83)) result(rx_clk,dclk,rst,source_record,record);
wire valid;wire [1:0] state;
wire [27:0] gated_record={record[27:25],(record[24] && record[45:28]==displayed),record[23:0]};
roi_display_state gate(dclk,rst,cfg,ex,ga,fps,1'b0,gated_record,displayed,valid,state);
task rticks;input integer n;begin repeat(n) @(negedge ref_clk);end endtask
task dticks;input integer n;begin repeat(n) @(negedge dclk);end endtask
task choose;input [1:0] value;input [15:0] epoch;
 begin sw=value;rticks(12);dticks(12);if(request!=={epoch,value} || displayed!==request) $fatal(1,"stable SW/epoch request %h expected %h",request,{epoch,value});end
endtask
task complete;begin
 repeat(15) @(negedge rx_clk);tag=received;dticks(45);
 legacy={~legacy[27],2'd0,1'b1,8'd100,8'd20,8'd200};
 dticks(100);
 if(!valid || state!=0 || record[82:28]!=={strength,ec,tag} || record[23:0]!==24'h6414c8) $fatal(1,"new atomic record not accepted valid=%b state=%d tag=%h cp=%d legacy=%h record=%h",valid,state,tag,cp,legacy,record);
end endtask
initial begin
 rticks(5);rst=1;rticks(5);
 sw=1;rticks(2);sw=2;rticks(1);sw=0;rticks(10);
 if(request!==0) $fatal(1,"switch bounce applied");
 choose(1,1);complete;
 choose(3,2);if(valid) $fatal(1,"mode change kept old statistics");complete;
 choose(2,3);complete;
 choose(0,4);complete;
 // Destination remains clocked while CSI is stopped. The independent request
 // must remove a frozen source record without waiting for a CSI edge.
 @(negedge rx_clk);rx_running=0;
 choose(1,5);dticks(80);if(valid || state!=1) $fatal(1,"stopped CSI switch failed to cancel");
 choose(0,6);dticks(80);if(valid) $fatal(1,"rapid round trip revived frozen mode record");
 rx_running=1;dticks(100);if(valid) $fatal(1,"resume accepted old mailbox without new frame");complete;
 ex=2228;dticks(80);if(valid) $fatal(1,"tuning failed to cancel");complete;
 cfg=0;dticks(10);cfg=1;dticks(80);if(valid) $fatal(1,"configuration recovery revived old token");complete;
 cp=0;complete; // RAW valid relies on the native/legacy frame proof.
 choose(2,7);cp=6400;complete;
 cp=6399;complete_incomplete;
 cp=6400;complete;choose(0,8);complete;
 // Counter rollover still needs a fresh completion; matching a retained tag
 // by itself must not rearm a sample.
 @(negedge ref_clk);controls.request={16'hffff,2'b00};
 choose(1,0);dticks(80);if(valid) $fatal(1,"epoch rollover revived sample");complete;
 rst=0;sw=3;rticks(5);rst=1;rticks(15);dticks(80);
 if(request!==18'd7 || valid) $fatal(1,"up-position startup or reset retained sample");complete;
 ex=2100;ga=49;choose(2,2);dticks(80);
 if(valid) $fatal(1,"simultaneous tuning and mode change retained sample");complete;
 cfg=0;ex=2068;choose(3,3);cfg=1;dticks(80);
 if(valid) $fatal(1,"concurrent configuration/mode recovery accepted old sample");complete;
 $display("PASS observation: independent pair debounce, four states, tagged atomic records, round trip, stopped CSI, tuning/config recovery, incomplete edge core and epoch rollover");$finish;
end
task complete_incomplete;begin
 repeat(15) @(negedge rx_clk);tag=received;repeat(5) @(negedge rx_clk);
 legacy={~legacy[27],2'd0,1'b1,8'd100,8'd20,8'd200};dticks(100);
 if(valid || record[24]) $fatal(1,"incomplete edge core accepted");
end endtask
initial begin #1000000;$fatal(1,"observation watchdog");end
endmodule
