// All inputs are in the 100 MHz processing domain. The counter is driven by
// source results, never VS/DDR readout. The 256-bit extension accompanies the
// unchanged legacy metadata through the existing slot/epoch attachment.
module classified_count_pipeline #(parameter LINE_X=640,STOP_CYCLES=15000000,PAGE_CYCLES=200000000,DIAGNOSTICS=0,RECORD_ONLY=0,MOTION_RECOVERY=0,TAIL_RECOVERY=0,OBS_PER_REGION=2,ORDERED_HANDOFF=0,RECOVERABLE=0,VELOCITY_ASSOC=0,LOCAL_RECOVERY=0)(
 input wire clk,rst_n,source_start,frame_commit,frame_bad,sample_new,
 input wire [63:0] config_tag,input wire [152*OBS_PER_REGION-1:0] objects,input wire [31:0] empty_probe,
 input wire [16:0] command,
 output reg [255:0] frame_record,output reg record_ready,
 output reg [255:0] live_record,
 output wire event_valid,output wire [15:0] event_run,
 output wire [8:0] event_id,output wire [31:0] event_frame,
 output wire [1:0] event_kind,output wire [3:0] event_reason,
 output wire hold_valid,output wire [10:0] hold_x,output wire [9:0] hold_y
);
 reg [15:0] command_seen,visible_run;reg [31:0] source_id;
 reg epoch_open,proved,result_seen,epoch_bad;reg [31:0] probe_snapshot;
 reg [27:0] silence,page_timer;reg timeout_sent;
 wire begin_run=command[16:1]!=command_seen && !command[0];
 wire end_run=command[16:1]!=command_seen && command[0];
 wire timeout_bad=silence==STOP_CYCLES-1 && !timeout_sent;
 wire lost_epoch=source_start && epoch_open && (!proved || !result_seen);
 wire reject=(frame_bad && epoch_open) || timeout_bad || lost_epoch;
 wire accept=sample_new && proved && !epoch_bad && !frame_bad && !source_start;
 wire busy,snapshot_new,dv,dr,region;wire [2:0] state;wire [3:0] reason;
 wire [15:0] run;wire [8:0] total,pt,et,rt;wire [35:0] ids;
 reg [8:0] empty_address;wire [8:0] empty_value;
 wire [5:0] unused_ledger;wire [15:0] diagnostic;wire [8:0] uncertainty_from;
 classified_pocket_counter #(.LINE_X(LINE_X),.HYST(RECORD_ONLY ? 4 : 3),.RECORD_ONLY(RECORD_ONLY),.MOTION_RECOVERY(MOTION_RECOVERY),.TAIL_RECOVERY(TAIL_RECOVERY),.OBS_PER_REGION(OBS_PER_REGION),.ORDERED_HANDOFF(ORDERED_HANDOFF),.RECOVERABLE(RECOVERABLE),.VELOCITY_ASSOC(VELOCITY_ASSOC),.LOCAL_RECOVERY(LOCAL_RECOVERY)) counter(
  .clk(clk),.rst_n(rst_n),.start_run(begin_run),.finish_run(end_run),.frame_bad(reject),
  .sample_new(accept),.frame_id(source_id),.config_tag(config_tag),.objects(objects),
  .busy(busy),.snapshot_new(snapshot_new),.state(state),.reason(reason),.run_id(run),
  .total(total),.present_total(pt),.empty_total(et),.review_total(rt),
  .direction_valid(dv),.direction_right(dr),.region(region),.object_ids(ids),
  .event_valid(event_valid),.event_run(event_run),.event_id(event_id),.event_frame(event_frame),
  .event_kind(event_kind),.event_reason(event_reason),
  .hold_valid(hold_valid),.hold_x(hold_x),.hold_y(hold_y),.diagnostic(diagnostic),.uncertainty_from(uncertainty_from),
  .ledger_address(9'd511),.ledger_data(unused_ledger),.empty_address(empty_address),.empty_id(empty_value));
 reg [8:0] last_id;reg [1:0] last_kind;reg [3:0] last_reason;
 reg [5:0] page;reg [71:0] page_ids;
 reg [3:0] fetch;reg [2:0] lane;reg [1:0] wait_read;
 reg build_pending,frame_pending;reg [2:0] settle;
 wire page_tick=page_timer==PAGE_CYCLES-1;
 wire [5:0] pages_minus_one=et==0 ? 0 : (et-1'b1)>>3;
 wire [35:0] fresh_ids=(state==2 || (RECOVERABLE && state==5)) ? ids : 36'd0;
 // Only one region is allowed. In R11, inactive ROI's low9 ID bits carry
 // the first uncertain RECORD number. Active18 IDs and CDC width unchanged.
 wire [35:0] annotated_ids=!LOCAL_RECOVERY ? fresh_ids : region ?
  {fresh_ids[35:18],9'd0,uncertainty_from} : {9'd0,uncertainty_from,fresh_ids[17:0]};
 wire [31:0] extension=RECORD_ONLY ? {(RECOVERABLE ? diagnostic : 16'd0),visible_run} : probe_snapshot;
 wire [255:0] bundle={extension,1'b1,page,last_reason,last_kind,last_id,page_ids,annotated_ids,rt,et,pt,total,region,dr,dv,reason,state,run,source_id};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   command_seen<=0;visible_run<=0;source_id<=0;epoch_open<=0;proved<=0;result_seen<=0;epoch_bad<=0;
   silence<=0;timeout_sent<=0;page_timer<=0;page<=0;page_ids<=0;
   last_id<=0;last_kind<=0;last_reason<=0;empty_address<=0;
   fetch<=0;lane<=0;wait_read<=0;build_pending<=0;frame_pending<=0;settle<=0;
   frame_record<=0;record_ready<=0;live_record<=0;probe_snapshot<=0;
  end else begin
   command_seen<=command[16:1];
   if(source_start)begin
    source_id<=source_id+1'b1;epoch_open<=1;proved<=0;result_seen<=0;epoch_bad<=0;
    silence<=0;timeout_sent<=0;record_ready<=0;frame_pending<=0;probe_snapshot<=0;
   end else begin
    if(silence<STOP_CYCLES)silence<=silence+1'b1;
    if(timeout_bad)timeout_sent<=1;
    if(frame_commit)proved<=1;
    if(frame_bad)epoch_bad<=1;
    if(accept)begin probe_snapshot<=DIAGNOSTICS ? empty_probe : 32'd0;result_seen<=1;record_ready<=0;frame_pending<=1;build_pending<=1;settle<=3;fetch<=0;end
   end
   if(page_tick)begin
    page_timer<=0;page<=page>=pages_minus_one ? 0 : page+1'b1;build_pending<=1;settle<=3;fetch<=0;
   end else page_timer<=page_timer+1'b1;
   if(begin_run || (RECORD_ONLY && end_run))begin
    page<=0;page_timer<=0;page_ids<=0;last_id<=0;last_kind<=0;last_reason<=0;record_ready<=0;
    if(RECORD_ONLY)begin
     visible_run<=end_run ? 16'd0 : visible_run+16'd1;
     silence<=0;timeout_sent<=0;frame_pending<=0;build_pending<=1;settle<=3;fetch<=0;
     if(end_run)begin frame_record<=0;epoch_open<=0;proved<=0;result_seen<=0;epoch_bad<=0;end
    end
   end
   if(event_valid && !begin_run && !(RECORD_ONLY && end_run))begin last_id<=event_id;last_kind<=event_kind;last_reason<=event_reason;end
   if(reject)record_ready<=0;
   if(snapshot_new)begin build_pending<=1;settle<=3;fetch<=0;end
   if(build_pending && !busy && !page_tick && !snapshot_new && !accept && !begin_run && !end_run && !source_start)begin
    if(settle!=0)settle<=settle-1'b1;
    else if(fetch==0)begin empty_address<={page,3'd0};lane<=0;wait_read<=2;fetch<=1;end
    else if(fetch==1)begin
     if(wait_read!=0)wait_read<=wait_read-1'b1;
     else begin
      page_ids[lane*9+:9]<=empty_value;
      if(lane==7)fetch<=2;
      else begin lane<=lane+1'b1;empty_address<=empty_address+1'b1;wait_read<=2;end
     end
    end else begin
     live_record<=bundle;
     if(frame_pending && !epoch_bad && !frame_bad && !reject)begin frame_record<=bundle;record_ready<=1;end
     frame_pending<=0;build_pending<=0;fetch<=0;
    end
   end
  end
 end
endmodule
