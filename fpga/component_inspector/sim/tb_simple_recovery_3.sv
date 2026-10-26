`define EXPECT_LOCAL
`define CASE 3
`timescale 1ns/1ps
// Literal packet vectors frozen before the RTL edit. These are not phone RAW.
`ifndef CASE
`define CASE 0
`endif
module tb_simple_recovery_3;
 localparam CASE_ID=`CASE;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,start_run=0,finish_run=0,sample_new=0,frame_bad=0;
 reg [31:0] frame_id=0;reg [607:0] objects=0;
 wire busy,event_valid;wire [2:0] state;wire [3:0] reason;wire [8:0] total,pt,et,event_id;wire [1:0] event_kind;
 wire [31:0] event_frame;wire [15:0] diagnostic;
 integer f,n,events=0,i;integer ids[0:7],kinds[0:7],sources[0:7];
 reg source_start=0,frame_commit=0;reg [16:0] command=0;
 wire [255:0] packet,live,raw_packet,raw_live;wire record_ready;
 count_record_view packet_view(raw_packet,packet);
 count_record_view live_view(raw_live,live);
 classified_count_pipeline #(.LOCAL_RECOVERY(1),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(2000000)) dut(
 .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(frame_commit),.frame_bad(frame_bad),.sample_new(sample_new),.config_tag(64'd1),.objects(objects),.empty_probe(32'd0),.command(command),.frame_record(raw_packet),.live_record(raw_live),.record_ready(record_ready),.event_valid(event_valid),.event_id(event_id),.event_kind(event_kind),.event_frame(event_frame));
wire [255:0] old_frame_record,old_live_record;wire old_record_ready,old_event_valid;wire [8:0] old_event_id;wire [1:0] old_event_kind;wire [31:0] old_event_frame;
 R14_classified_count_pipeline #(.LOCAL_RECOVERY(1),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(2000000)) old(
 .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(frame_commit),.frame_bad(frame_bad),.sample_new(sample_new),.config_tag(64'd1),.objects(objects),.empty_probe(32'd0),.command(command),.frame_record(old_frame_record),.live_record(old_live_record),.record_ready(old_record_ready),.event_valid(old_event_valid),.event_id(old_event_id),.event_kind(old_event_kind),.event_frame(old_event_frame));

reg [255:0] expected_packet,expected_live;
integer eq_cycles=0,eq_packets=0;
always @(posedge clk)begin
 #1;
 if(rst_n)begin
  expected_packet=old_frame_record;expected_live=old_live_record;
  if(expected_packet[57])begin expected_packet[102:94]=0;expected_packet[111:103]=0;end
  else begin expected_packet[120:112]=0;expected_packet[129:121]=0;end
  if(expected_live[57])begin expected_live[102:94]=0;expected_live[111:103]=0;end
  else begin expected_live[120:112]=0;expected_live[129:121]=0;end
  if(packet!==expected_packet || live!==expected_live)$fatal(1,"only removed inactive-ROI warning codec may differ");
  if(record_ready!==old_record_ready || {event_valid,event_id,event_kind,event_frame}!=={old_event_valid,old_event_id,old_event_kind,old_event_frame})$fatal(1,"event or publication latency changed");
  eq_cycles++;
  if(record_ready)eq_packets++;
 end
end
final $display("PASS independent R14 pipeline comparison cycles=%0d ready_clocks=%0d",eq_cycles,eq_packets);

 assign busy=dut.counter.busy;
 assign state=live[50:48];assign reason=live[54:51];assign total=live[66:58];assign pt=live[75:67];assign et=live[84:76];assign diagnostic=live[255:240];
 always @(negedge clk)if(start_run)command<={command[16:1]+16'd1,1'b0};else if(finish_run)command<={command[16:1]+16'd1,1'b1};
 always @(posedge clk)if(event_valid)begin
  if(events>=8)$fatal(1,"duplicate or fabricated event");
  ids[events]=event_id;kinds[events]=event_kind;sources[events]=event_frame;events=events+1;
 end
 function [75:0] object_at(input integer cx,kind);
  integer h;begin h=kind==3?4:19;object_at={1'b1,kind[1:0],4'd0,13'd100,7'd38,7'd38,11'(cx-h),11'(cx+h),10'd310,10'd330};end
 endfunction
 function integer pos(input integer x);begin pos=CASE_ID==4?1280-x:x;end endfunction
 task send_packet;
  begin
   @(negedge clk);source_start=1;frame_id=frame_id+1;@(negedge clk);source_start=0;
   repeat(3)@(negedge clk);frame_commit=1;@(negedge clk);frame_commit=0;repeat(3)@(negedge clk);
   sample_new=1;@(negedge clk);sample_new=0;repeat(2)@(negedge clk);n=0;
   while(!record_ready)begin @(negedge clk);n=n+1;if(n>3000)$fatal(1,"bounded recorder work");end
   repeat(3)@(negedge clk);
   if(packet[31:0]!=frame_id || !packet[223] || packet[66:58]!=total || packet[120:112]!=0 || packet[129:121]!=0)$fatal(1,"atomic warning/source/total codec");
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst_n=1;@(negedge clk);start_run=1;@(negedge clk);start_run=0;
  for(f=0;f<=25;f=f+1)begin
   objects=0;
   objects[0+:76]=object_at(pos((CASE_ID==4?530:480)+10*f),2);
   objects[76+:76]=object_at(pos((CASE_ID==4?480:530)+10*f),2);
   // Short return=7 missed packets, long return=9, permanent absent=never.
   if(f<=3 || (CASE_ID==1 && f>=11) || ((CASE_ID==0 || CASE_ID==4) && f>=13) || CASE_ID==3)
    objects[152+:76]=object_at(pos(580+10*f),3);
   if(CASE_ID==3 && f==8)objects[228+:76]=objects[0+:76];
   send_packet();
   if(f==12 && CASE_ID!=1 && CASE_ID!=3)begin
`ifdef EXPECT_LOCAL
    if(state!=2 || total!=1 || pt!=1 || et!=0 || dut.counter.uncertainty_from!=1)$fatal(1,"long missing must release later true P: state%0d T%0d P%0d E%0d gap%0d",state,total,pt,et,dut.counter.uncertainty_from);
`else
    if(state!=6 || reason!=4 || total!=0)$fatal(1,"old same-vector sensitivity must stop CHECK/C4");
`endif
   end
  end
`ifdef EXPECT_LOCAL
  if(state!=2 || reason!=0)$fatal(1,"ordinary missing must not terminate run");
  if(CASE_ID==2)begin
   if(total!=2 || pt!=2 || et!=0 || events!=2 || sources[0]!=13 || sources[1]!=18)$fatal(1,"permanent missing fabricated/blocked event");
  end else begin
   if(total!=3 || pt!=2 || et!=1 || events!=3)$fatal(1,"late or short return lost/duplicated %0d/%0d/%0d events%0d",total,pt,et,events);
   if(CASE_ID==0 || CASE_ID==4)begin
    if(kinds[0]!=2 || kinds[1]!=3 || kinds[2]!=2 || sources[0]!=13 || sources[1]!=14 || sources[2]!=18)$fatal(1,"late return must keep actual source/kind and flag sequence");
   end else if(kinds[0]!=3 || kinds[1]!=2 || kinds[2]!=2 || sources[0]!=8 || sources[1]!=13 || sources[2]!=18)begin
    // The short return is genuinely seen at source12, not source8.
    if(CASE_ID!=1 || kinds[0]!=3 || kinds[1]!=2 || kinds[2]!=2 || sources[0]!=12 || sources[1]!=13 || sources[2]!=18)$fatal(1,"short return or independent mapping ordering");
   end
  end
  if((CASE_ID==1 || CASE_ID==3) ? dut.counter.uncertainty_from!=0 : dut.counter.uncertainty_from!=1)$fatal(1,"uncertainty must distinguish recovered ordered gap vs bypass");
  // Proved source repeat and a stationary return cannot emit again.
  for(i=0;i<35;i=i+1)send_packet();
  if(total!=(CASE_ID==2?2:3))$fatal(1,"pause or return duplicate");
  @(negedge clk);finish_run=1;@(negedge clk);finish_run=0;repeat(120)@(negedge clk);
  if(total!=0 || et!=0 || pt!=0 || dut.counter.uncertainty_from!=0 || diagnostic!=0 || state!=0)$fatal(1,"full-clear must clear warning and counts");
  $display("PASS simple_recovery_3: local pipeline case=%0d: actual events, local gap, return de-duplication, source binding, pause, full clear",CASE_ID);
`else
  if(CASE_ID==0 || CASE_ID==2 || CASE_ID==4)begin if(state!=6 || total!=0)$fatal(1,"old sensitivity disappeared");end
  $display("PASS old local-recovery sensitivity case=%0d: baseline global CHECK reproduced",CASE_ID);
`endif
  $finish;
 end
 initial begin #10000000;$fatal(1,"watchdog");end
endmodule
