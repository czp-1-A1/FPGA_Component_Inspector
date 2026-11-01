// Two independent numbered queues and measured stations share ONE motor.
// The accepted R27B main counters remain the sole source of global IDs.
module dual_lane_parking #(
 parameter CLK_HZ=100000000,TARGET_X=152,ADVANCE_PX=32,TOL_PX=80,HOLD_MS=1000
)(
 input wire clk,rst_n,permit,pause,actual_motor_running,
 input wire source_start,frame_commit,frame_bad,sample_new,
 input wire [63:0] config_tag,input wire [16:0] command,
 input wire [607:0] station_objects,
 input wire [1:0] main_snapshot,main_motion_valid,main_seed_valid,
 input wire [25:0] main_dx,input wire [11:0] main_radius,
 input wire [21:0] main_seed_x,input wire [19:0] main_seed_y,
 input wire [1:0] main_start,main_clear,main_good,main_bad,
 input wire [31:0] main_run,input wire [63:0] main_frame,
 input wire [5:0] main_state,input wire [1:0] main_dv,main_dr,
 input wire [17:0] main_total,main_uncertainty,
 input wire [1:0] event_valid,input wire [31:0] event_run,
 input wire [17:0] event_id,input wire [3:0] event_kind,
 input wire [1:0] transport_occupied,
 output wire feed_enable,alarm_stop,
 output wire [127:0] status,output wire [191:0] diagnostic,
 output wire [1:0] cycle_done,
 output wire [1:0] hold_valid,hold_empty_only,
 output wire [21:0] hold_x,output wire [19:0] hold_y,
 output wire [11:0] hold_radius
);
 wire [1:0] lane_feed,lane_alarm,position_new,position_fault;
 wire [17:0] queries,position_id;wire [31:0] position_run;wire [63:0] position_frame;
 wire [21:0] position_x;wire [19:0] position_y;
 global_empty_position_tracker tracker(.clk(clk),.rst_n(rst_n),.source_start(source_start),.actual_motor_running(actual_motor_running),
  .start_run(main_start),.clear_run(main_clear),.good_frame(main_good),.bad_frame(main_bad),
  .main_snapshot(main_snapshot),.motion_valid(main_motion_valid),.motion_dx(main_dx),.motion_radius(main_radius),
  .seed_valid(main_seed_valid),.seed_x(main_seed_x),.seed_y(main_seed_y),.main_run(main_run),.main_frame(main_frame),
  .event_valid(event_valid),.event_id(event_id),.event_kind(event_kind),.query_id(queries),.objects(station_objects),
  .position_new(position_new),.position_fault(position_fault),.position_id(position_id),.position_run(position_run),
  .position_frame(position_frame),.position_x(position_x),.position_y(position_y),
  .search_valid(hold_valid),.search_x(hold_x),.search_y(hold_y),.search_radius(hold_radius));
 assign hold_empty_only=hold_valid;
 assign feed_enable=&lane_feed;assign alarm_stop=|lane_alarm;
 genvar lane;generate for(lane=0;lane<2;lane=lane+1)begin : lanes
  pocket_relay_stop_v2 #(.DIRECT_GLOBAL_TRACK(1),.REGISTER_HISTORY(1),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.RESTART_NEW_RUN(1),
   .CLK_HZ(CLK_HZ),.TARGET_X(TARGET_X),.ADVANCE_PX(ADVANCE_PX),.POSITION_TOL_PX(TOL_PX),.HOLD_MS(HOLD_MS)) controller(
   .clk(clk),.rst_n(rst_n),.permit(permit),.pause(pause),.external_hold(!actual_motor_running),
   .start_run(main_start[lane]),.clear_run(main_clear[lane]),
   .good_frame(main_good[lane]),.bad_frame(main_bad[lane]),.local_position_fault(position_fault[lane]),.transport_occupied(transport_occupied[lane]),
   .current_frame(main_frame[lane*32+:32]),.counter_run(main_run[lane*16+:16]),
   .counter_state(main_state[lane*3+:3]),.direction_valid(main_dv[lane]),.direction_right(main_dr[lane]),
   .counter_total(main_total[lane*9+:9]),.counter_uncertainty(main_uncertainty[lane*9+:9]),
   .station_run(16'd0),.station_state(3'd0),.station_dv(1'b0),.station_dr(1'b0),
   .station_total(9'd0),.station_uncertainty(9'd0),
   .event_valid(event_valid[lane]),.event_run(event_run[lane*16+:16]),.event_id(event_id[lane*9+:9]),.event_kind(event_kind[lane*2+:2]),
   .station_event_valid(1'b0),.station_event_run(16'd0),.station_event_id(9'd0),.station_event_kind(2'd0),
   .query_id(queries[lane*9+:9]),.position_new(position_new[lane]),.position_id(position_id[lane*9+:9]),.position_run(position_run[lane*16+:16]),.position_frame(position_frame[lane*32+:32]),
   .position_x(position_x[lane*11+:11]),.position_y(position_y[lane*10+:10]),.feed_enable(lane_feed[lane]),.alarm_stop(lane_alarm[lane]),
   .station_diagnostic(64'd0),.diagnostic(diagnostic[lane*96+:96]),
   .status(status[lane*64+:64]),.cycle_done(cycle_done[lane]));
 end endgenerate
endmodule
