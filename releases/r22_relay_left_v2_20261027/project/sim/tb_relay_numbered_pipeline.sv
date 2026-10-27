`timescale 1ns/1ps
module tb_relay_numbered_pipeline;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,source_start=0,frame_commit=0,frame_bad=0,sample_new=0;
 reg [607:0] objects=0;reg [16:0] command=0;
 wire [8:0] query_id,position_id,event_id;wire position_new,event_valid;
 wire [10:0] position_x;wire [9:0] position_y;
 wire [15:0] position_run,event_run,counter_run;wire [31:0] position_frame,current_frame;
 wire [1:0] event_kind;wire start_run,clear_run,good_frame,bad_frame,direction_valid,direction_right;
 wire [2:0] counter_state,state;wire [3:0] fault;wire feed_enable,cycle_done;wire [31:0] status;
 classified_count_pipeline #(.STOP_POSITION(1),.LOCAL_RECOVERY(1),.RECORD_ONLY(1),.MOTION_RECOVERY(1),
 .TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(2000000)) pipeline(
  .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(frame_commit),.frame_bad(frame_bad),.sample_new(sample_new),
  .config_tag(64'd1),.objects(objects),.empty_probe(32'd0),.command(command),
  .event_valid(event_valid),.event_run(event_run),.event_id(event_id),.event_kind(event_kind),
  .stop_query_id(query_id),.stop_position_new(position_new),.stop_position_id(position_id),
  .stop_position_x(position_x),.stop_position_y(position_y),.stop_position_run(position_run),.stop_position_frame(position_frame),
  .stop_begin(start_run),.stop_clear(clear_run),.stop_good_frame(good_frame),.stop_bad_frame(bad_frame),
  .stop_current_frame(current_frame),.stop_run(counter_run),.stop_state(counter_state),
  .stop_direction_valid(direction_valid),.stop_direction_right(direction_right));
 pocket_relay_stop #(.CLK_HZ(1000000),.HOLD_MS(10)) controller(
  .clk(clk),.rst_n(rst_n),.permit(1'b1),.start_run(start_run),.clear_run(clear_run),
  .good_frame(good_frame),.bad_frame(bad_frame),.current_frame(current_frame),.counter_run(counter_run),.counter_state(counter_state),
  .direction_valid(direction_valid),.direction_right(direction_right),.event_valid(event_valid),.event_run(event_run),.event_id(event_id),.event_kind(event_kind),
  .query_id(query_id),.position_new(position_new),.position_id(position_id),.position_run(position_run),.position_frame(position_frame),
  .position_x(position_x),.position_y(position_y),.feed_enable(feed_enable),.state(state),.fault(fault),.status(status),.cycle_done(cycle_done));
 integer actual_x=560,events=0,positions=0,done=0,checks=0,k;reg saw_settle=0,saw_hold=0;
 function [75:0] obj(input integer x);
  obj={1'b1,2'd3,4'd0,13'd64,7'd8,7'd8,11'(x-4),11'(x+4),10'd312,10'd328};
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task frame(input integer x);
  begin actual_x=x;objects=0;objects[0+:76]=obj(x);source_start=1;ticks(1);source_start=0;
   ticks(2);frame_commit=1;ticks(1);frame_commit=0;ticks(2);sample_new=1;ticks(1);sample_new=0;ticks(4993);
  end
 endtask
 task check(input bit ok,input string message);
  begin checks++;if(!ok)begin $display("FAIL %s S%0d F%0d counter%0d x%0d",message,state,fault,counter_state,actual_x);$fatal(1);end end
 endtask
 always @(negedge clk)begin
  if(event_valid)begin events++;check(event_id==1 && event_kind==3,"real EMPTY numbered once");end
  if(position_new)begin
   positions++;check(position_id==1 && position_run==1 && position_frame==current_frame,"measurement bound to real RUN/ID/source");
   check(position_x==actual_x && position_y==320,"measurement equals actual current observation, no hold prediction");
  end
  if(state==2)begin saw_settle=1;check(!feed_enable,"settle output disabled");end
  if(state==3)begin saw_hold=1;check(!feed_enable,"hold output disabled");end
  if(cycle_done)done++;
 end
 initial begin
  ticks(4);rst_n=1;ticks(10);command=2;ticks(10);
  for(k=560;k<=736;k=k+4)frame(k);
  check(state==2 && !feed_enable,"genuine numbered crossing triggers relay stop");
  frame(744);frame(752);frame(760);frame(760);frame(760);frame(760);
  repeat(4)frame(760);
  check(events==1 && done==1 && positions>10 && saw_settle && saw_hold && feed_enable && query_id==0,"numbered EMPTY stop/verify/hold/resume integration");
  $display("PASS numbered relay pipeline: %0d checks, %0d positions, %0d event, %0d completion",checks,positions,events,done);$finish;
 end
 initial begin #10000000;$fatal(1,"pipeline timeout");end
endmodule
