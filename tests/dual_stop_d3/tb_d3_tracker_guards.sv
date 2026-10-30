`timescale 1ns/1ps
module tb_d3_tracker_guards;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,source_start=0,actual_motor_running=0;
reg [1:0] start_run=0,clear_run=0,good_frame=0,bad_frame=0,main_snapshot=0,motion_valid=0,seed_valid=0,event_valid=0;
reg [25:0] motion_dx=0;reg [11:0] motion_radius={6'd32,6'd32};
reg [21:0] seed_x=300;reg [19:0] seed_y=320;reg [31:0] main_run={16'd1,16'd1};
reg [63:0] main_frame={32'd1,32'd1};reg [17:0] event_id=1,query_id=1;reg [3:0] event_kind=3;
reg [607:0] objects=0;
wire [1:0] position_new,position_fault,search_valid;wire [17:0] position_id;wire [31:0] position_run;
wire [63:0] position_frame;wire [21:0] position_x,search_x;wire [19:0] position_y,search_y;wire [11:0] search_radius;
global_empty_position_tracker dut(.*);
integer measurements=0,checks=0;
function [75:0] aperture(input integer x,k);
 aperture={1'b1,2'(k),4'd0,13'd64,7'd8,7'd8,11'(x-4),11'(x+4),10'd316,10'd324};
endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task issue;begin good_frame=3;ticks(1);good_frame=0;ticks(4);main_snapshot=3;ticks(1);main_snapshot=0;ticks(400);end endtask
always @(posedge clk)if(rst_n && position_new[0] && !position_fault[0])begin
 if(position_id[8:0]!=1 || position_run[15:0]!=1 || position_frame[31:0]!=main_frame[31:0] || position_x[10:0]!=300)$fatal(1,"wrong ID/epoch or inferred position");
 measurements++;
end
initial begin
 ticks(4);rst_n=1;start_run=3;ticks(1);start_run=0;
 event_valid=1;seed_valid=1;ticks(1);event_valid=0;seed_valid=0;
 objects[75:0]=aperture(290,3);objects[151:76]=aperture(310,3);issue();
 if(measurements!=0 || position_fault!=0)$fatal(1,"ambiguous aperture selected as a unique physical ID");checks++;
 main_frame={32'd2,32'd2};objects=0;objects[75:0]=aperture(300,2);issue();
 if(measurements!=0)$fatal(1,"wrong class accepted");checks++;
 main_frame={32'd3,32'd3};objects[75:0]=aperture(300,3);issue();
 if(measurements!=1)$fatal(1,"real returning hole did not preserve ID");checks++;
 good_frame=3;ticks(1);good_frame=0;source_start=1;ticks(1);source_start=0;ticks(4);
 if(position_fault!=3)$fatal(1,"unfinished source epoch was silently replaced");checks++;
 start_run=3;ticks(1);start_run=0;ticks(4);
 if(position_fault!=0 || position_new!=0)$fatal(1,"new RUN did not clear observer fault/old pulses");checks++;
 event_valid=1;seed_valid=0;ticks(1);event_valid=0;ticks(1);
 if(!position_fault[0])$fatal(1,"missing real count seed accepted");checks++;
 $display("PASS D3 TRACKER GUARDS: %0d checks, ambiguity, class, real return, actual ID/frame, unfinished epoch, new RUN and unmeasured seed",checks);$finish;
end
initial begin #1000000;$fatal(1,"watchdog");end
endmodule
