`timescale 1ns/1ps
module center_capture_pair #(parameter PROFILE=0,OBS_PER_REGION=2,RECORD=0,MOTION=0,TAIL=0,ORDERED=0,REC=0,VELOCITY=0,LOCAL=0)(input wire clk,output reg done=0);
reg  rst_n=0;
reg  start_run=0;
reg  finish_run=0;
reg  frame_bad=0;
reg  sample_new=0;
reg [31:0] frame_id=0;
reg [63:0] config_tag=0;
reg [152*OBS_PER_REGION-1:0] objects=0;
wire  busy_a,busy_b;
wire  snapshot_new_a,snapshot_new_b;
wire [2:0] state_a,state_b;
wire [3:0] reason_a,reason_b;
wire [15:0] run_id_a,run_id_b;
wire [8:0] total_a,total_b;
wire [8:0] present_total_a,present_total_b;
wire [8:0] empty_total_a,empty_total_b;
wire [8:0] review_total_a,review_total_b;
wire  direction_valid_a,direction_valid_b;
wire  direction_right_a,direction_right_b;
wire  region_a,region_b;
wire [35:0] object_ids_a,object_ids_b;
wire  event_valid_a,event_valid_b;
wire [15:0] event_run_a,event_run_b;
wire [8:0] event_id_a,event_id_b;
wire [31:0] event_frame_a,event_frame_b;
wire [1:0] event_kind_a,event_kind_b;
wire [3:0] event_reason_a,event_reason_b;
reg [8:0] ledger_address=0;
wire [5:0] ledger_data_a,ledger_data_b;
reg [8:0] empty_address=0;
wire [8:0] empty_id_a,empty_id_b;
wire  hold_valid_a,hold_valid_b;
wire [10:0] hold_x_a,hold_x_b;
wire [9:0] hold_y_a,hold_y_b;
wire [15:0] diagnostic_a,diagnostic_b;
wire [8:0] uncertainty_from_a,uncertainty_from_b;
R15_precenter_classified_pocket_counter #(.OBS_PER_REGION(OBS_PER_REGION),.RECORD_ONLY(RECORD),.MOTION_RECOVERY(MOTION),.TAIL_RECOVERY(TAIL),.ORDERED_HANDOFF(ORDERED),.RECOVERABLE(REC),.VELOCITY_ASSOC(VELOCITY),.LOCAL_RECOVERY(LOCAL)) a(.clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(finish_run),.frame_bad(frame_bad),.sample_new(sample_new),.frame_id(frame_id),.config_tag(config_tag),.objects(objects),.ledger_address(ledger_address),.empty_address(empty_address),.busy(busy_a),.snapshot_new(snapshot_new_a),.state(state_a),.reason(reason_a),.run_id(run_id_a),.total(total_a),.present_total(present_total_a),.empty_total(empty_total_a),.review_total(review_total_a),.direction_valid(direction_valid_a),.direction_right(direction_right_a),.region(region_a),.object_ids(object_ids_a),.event_valid(event_valid_a),.event_run(event_run_a),.event_id(event_id_a),.event_frame(event_frame_a),.event_kind(event_kind_a),.event_reason(event_reason_a),.ledger_data(ledger_data_a),.empty_id(empty_id_a),.hold_valid(hold_valid_a),.hold_x(hold_x_a),.hold_y(hold_y_a),.diagnostic(diagnostic_a),.uncertainty_from(uncertainty_from_a));
classified_pocket_counter #(.OBS_PER_REGION(OBS_PER_REGION),.RECORD_ONLY(RECORD),.MOTION_RECOVERY(MOTION),.TAIL_RECOVERY(TAIL),.ORDERED_HANDOFF(ORDERED),.RECOVERABLE(REC),.VELOCITY_ASSOC(VELOCITY),.LOCAL_RECOVERY(LOCAL)) b(.clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(finish_run),.frame_bad(frame_bad),.sample_new(sample_new),.frame_id(frame_id),.config_tag(config_tag),.objects(objects),.ledger_address(ledger_address),.empty_address(empty_address),.busy(busy_b),.snapshot_new(snapshot_new_b),.state(state_b),.reason(reason_b),.run_id(run_id_b),.total(total_b),.present_total(present_total_b),.empty_total(empty_total_b),.review_total(review_total_b),.direction_valid(direction_valid_b),.direction_right(direction_right_b),.region(region_b),.object_ids(object_ids_b),.event_valid(event_valid_b),.event_run(event_run_b),.event_id(event_id_b),.event_frame(event_frame_b),.event_kind(event_kind_b),.event_reason(event_reason_b),.ledger_data(ledger_data_b),.empty_id(empty_id_b),.hold_valid(hold_valid_b),.hold_x(hold_x_b),.hold_y(hold_y_b),.diagnostic(diagnostic_b),.uncertainty_from(uncertainty_from_b));
integer f,i,cycles=0,events=0,scans=0,applies=0,k,x;reg [1:0] kind;reg [3:0] mask;
function [75:0] observation(input integer left,input integer top,input integer odd,input reg [1:0] category,input reg [3:0] why);
 begin observation={1'b1,category,why,13'd256,7'd17,7'd16,left[10:0],11'(left+16),top[9:0],10'(top+16+odd)};end
endfunction
always @(posedge clk)begin
 #1;
 if(rst_n)begin
  cycles=cycles+1;
  if({busy_a,snapshot_new_a,state_a,reason_a,run_id_a,total_a,present_total_a,empty_total_a,review_total_a,direction_valid_a,direction_right_a,region_a,object_ids_a,event_valid_a,event_run_a,event_id_a,event_frame_a,event_kind_a,event_reason_a,ledger_data_a,empty_id_a,hold_valid_a,hold_x_a,hold_y_a,diagnostic_a,uncertainty_from_a} !== {busy_b,snapshot_new_b,state_b,reason_b,run_id_b,total_b,present_total_b,empty_total_b,review_total_b,direction_valid_b,direction_right_b,region_b,object_ids_b,event_valid_b,event_run_b,event_id_b,event_frame_b,event_kind_b,event_reason_b,ledger_data_b,empty_id_b,hold_valid_b,hold_x_b,hold_y_b,diagnostic_b,uncertainty_from_b})$fatal(1,"center capture public mismatch profile%0d f%0d cycle%0d oldphase%0d newphase%0d",PROFILE,f,cycles,a.phase,b.phase);
  if(event_valid_b)events=events+1;
  // Compare arithmetic only in phases that consume it, independently of
  // public event checks. The source packet and FSM clocks are unchanged.
  if(b.phase==3 || b.phase==4 || b.phase==7)begin
   if({a.cx,a.cy} !== {b.cx,b.cy})$fatal(1,"centre consumer mismatch profile%0d f%0d phase%0d",PROFILE,f,b.phase);
   if(b.phase==3)scans=scans+1;else if(b.phase==7)applies=applies+1;
  end
 end
end
task tick(input integer n);begin repeat(n)@(negedge clk);end endtask
initial begin
 config_tag=64'h10203040;tick(5);rst_n=1;tick(3);
 for(f=1;f<=160;f=f+1)begin
  if(f==1 || f==61 || f==102 || f==131 || f==145)begin start_run=1;tick(1);start_run=0;tick(2);end
  objects=0;
  for(i=0;i<OBS_PER_REGION;i=i+1)begin
   x=f<61 ? 400+i*56+f*7 : f<102 ? 1100-i*56-(f-61)*9 : 420+i*56+(f-102)*9;
   if(f>=45 && f<50)x=400+i*56+44*7;
   if(f==50 || f==51)x=400+i*56+44*7+(f==50 ? -1 : 1);
   kind=(i+(f<45 ? 0 : f/17))%3==0 ? 3 : 2;mask=(f%13==0 && kind==2) ? 4'h8 : 0;
   if(f==53 || f==54)kind=i==0 ? 1 : kind;
   k=(f>=61 && f<102) ? OBS_PER_REGION+i : i;
   objects[k*76+:76]=observation(x,300+(i%2),(f+i)%2,kind,mask);
   if((f>=55 && f<=59 && i==0) || (f>=108 && f<=117 && i==1))objects[k*76+75]=0;
  end
  if(f==121)config_tag=config_tag+1;
  if(f==125)begin frame_bad=1;tick(1);frame_bad=0;end
  if(f==130)begin finish_run=1;tick(1);finish_run=0;end
  if(f==140)begin rst_n=0;tick(2);rst_n=1;tick(2);end
  frame_id=f==48 ? 47 : f>=90 && f<102 ? f+1 : f;
  ledger_address=(f*7)%301;empty_address=(f*11)%301;
  sample_new=1;tick(1);sample_new=0;
  // The original public busy schedule is part of the equivalence contract.
  k=0;while(busy_a || busy_b)begin tick(1);k=k+1;if(k>2000)$fatal(1,"counter busy timeout");end
  tick(7);
 end
 if(events==0 || scans<100 || applies<4)$fatal(1,"insufficient centre equivalence coverage p%0d events%0d scans%0d apply%0d",PROFILE,events,scans,applies);
 $display("PASS center capture profile%0d cycles%0d events%0d scan%0d apply%0d every public signal and consumer centre exact",PROFILE,cycles,events,scans,applies);done=1;
end
endmodule
module tb_center_capture_equivalence;
reg clk=0;always #5 clk=~clk;wire [7:0] done;
center_capture_pair #(.PROFILE(0)) p0(clk,done[0]);
center_capture_pair #(.PROFILE(1),.RECORD(1)) p1(clk,done[1]);
center_capture_pair #(.PROFILE(2),.RECORD(1),.MOTION(1)) p2(clk,done[2]);
center_capture_pair #(.PROFILE(3),.OBS_PER_REGION(4),.RECORD(1),.MOTION(1),.TAIL(1),.ORDERED(1)) p3(clk,done[3]);
center_capture_pair #(.PROFILE(4),.OBS_PER_REGION(4),.RECORD(1),.MOTION(1),.TAIL(1),.ORDERED(1),.REC(1)) p4(clk,done[4]);
center_capture_pair #(.PROFILE(5),.OBS_PER_REGION(4),.RECORD(1),.MOTION(1),.TAIL(1),.ORDERED(1),.REC(1),.VELOCITY(1)) p5(clk,done[5]);
center_capture_pair #(.PROFILE(6),.OBS_PER_REGION(4),.RECORD(1),.MOTION(1),.TAIL(1),.ORDERED(1),.REC(1),.VELOCITY(1),.LOCAL(1)) p6(clk,done[6]);
center_capture_pair #(.PROFILE(7),.RECORD(1),.MOTION(1),.TAIL(1),.REC(1),.VELOCITY(1),.LOCAL(1)) p7(clk,done[7]);
initial begin wait(&done);$display("PASS center capture equivalence:160 frames eight parameter sets exact public cycles, centre values, events, IDs, clearing and faults");$finish;end
initial begin #100000000;$fatal(1,"centre equivalence timeout");end
endmodule
