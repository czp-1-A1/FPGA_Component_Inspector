`timescale 1ns/1ps
module tb_wb_epoch;
reg src=0,rx=0,pix=0,rst=0,running=1;
always #20 src=~src;always #4 if(running)rx=~rx;always #9 pix=~pix;
reg [31:0] request=32'h00004040,tag=32'h00004040;
wire [31:0] received,displayed;
status_cdc #(.WIDTH(32)) c0(src,rx,rst,request,received);
status_cdc #(.WIDTH(32)) c1(src,pix,rst,request,displayed);
reg [27:0] legacy=0;wire [114:0] sample,published;
wire invalid=tag!=received;
roi_observation_snapshot snapshot(rx,rst,invalid,18'd0,tag,legacy,13'd6400,13'd99,1'b0,37'd0,24'd40000,sample);
status_cdc #(.WIDTH(115)) c2(rx,pix,rst,sample,published);
wire [27:0] record={published[27:25],(published[24] && published[114:83]==displayed),published[23:0]};
wire valid;wire [1:0] state;
roi_display_state gate(pix,rst,1'b1,16'd2244,16'd48,16'd27,1'b1,record,18'd0,displayed,valid,state);
task ticks;input integer n;begin repeat(n)@(negedge pix);end endtask
task complete;begin
 repeat(40)@(negedge rx);tag=received;legacy[24]=0;repeat(5)@(negedge rx);
 legacy={~legacy[27],2'd2,1'b1,8'd100,8'd20,8'd200};ticks(100);
 if(!valid || state!=2 || published[114:83]!=request)$fatal(1,"fresh WB sample rejected");
end endtask
initial begin
 ticks(5);rst=1;ticks(100);complete;
 request=32'h00016020;ticks(100);
 if(valid || state!=1)$fatal(1,"old sample survived WB change");
 complete;
 @(negedge rx);running=0;
 request=32'h0002c020;ticks(100);request=32'h00036020;ticks(100);
 if(valid || state!=1)$fatal(1,"old coefficients reused stale result after round trip");
 running=1;ticks(100);if(valid)$fatal(1,"clock resume reused old token");
 complete;
 request=32'hffff4040;ticks(100);complete;
 request=32'h00004040;ticks(100);if(valid)$fatal(1,"epoch wrap reused prior token");complete;
 $display("PASS WB epoch: coherent held request/result, invalidation, change-away/back with stopped CSI, recovery, epoch wrap and fresh-token requirement");$finish;
end
initial begin #200000;$fatal(1,"WB epoch watchdog");end
endmodule
