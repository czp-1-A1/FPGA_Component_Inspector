`timescale 1ns/1ps
// Recorder-only mechanism tests; synthetic classified measurements, not field RAW.
module tb_local_stream;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start_run=0,finish_run=0,sample_new=0;
reg [31:0] frame_id=0;reg [607:0] objects=0;
wire busy,ev,hv;wire [2:0] state;wire [3:0] reason;wire [8:0] total,pt,et,eid;
wire [31:0] ef;wire [1:0] ek;wire [10:0] hx;wire [9:0] hy;wire [15:0] diag;
reg source_start=0,frame_commit=0;reg [16:0] command=0;
wire [255:0] packet,live;wire record_ready;
always @(negedge clk)begin
 if(start_run)command<={command[16:1]+16'd1,1'b0};
 else if(finish_run)command<={command[16:1]+16'd1,1'b1};
end
classified_count_pipeline #(.LOCAL_RECOVERY(1),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(2000000)) pipeline(
 .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(frame_commit),.frame_bad(1'b0),
 .sample_new(sample_new),.config_tag(64'hcc),.objects(objects),.empty_probe(32'd0),.command(command),
 .frame_record(packet),.live_record(live),.record_ready(record_ready),
 .event_valid(ev),.event_id(eid),.event_frame(ef),.event_kind(ek),.hold_valid(hv),.hold_x(hx),.hold_y(hy));
assign busy=pipeline.counter.busy;
assign state=live[50:48];assign reason=live[54:51];assign diag=live[255:240];
assign total=live[66:58];assign pt=live[75:67];assign et=live[84:76];
integer checks=0,scenario=0,f,k,j,q,x,delta,dir,mode,speed,swap,events=0;
integer ranks[0:3],distances[0:3],preferred,dd,offset;
integer truth[0:26],armed_truth[0:26],seen_cross[0:26];
integer errors=0,sensitive=0,expected_events,held=0;reg oracle=0;
function integer klass(input integer n,p);
 begin
  if(p==0)klass=(n==1 || n==5 || n==10 || n==11 || n==18 || n==23)?3:2;
  else if(p==1)klass=(n==13 || n==17 || n==18 || n==25)?3:2;
  else klass=(n==0 || n==6 || n==18 || n==20 || n==24)?3:2;
 end
endfunction
function [75:0] obj(input integer xx,kind);
 integer h;begin h=kind==3?4:19;obj={1'b1,kind[1:0],4'd0,13'd100,7'd38,7'd38,11'(xx-h),11'(xx+h),10'd310,10'd330};end
endfunction
task check(input bit good,input string what);
 begin checks++;if(!good)begin errors++;$display("MISMATCH %s case%0d f%0d S%0d C%0d D%04h T%0d P%0d E%0d",what,scenario,f,state,reason,diag,total,pt,et);end end
endtask
task send;
 integer n;begin
 @(negedge clk);source_start=1;frame_id++;@(negedge clk);source_start=0;
 repeat(3)@(negedge clk);frame_commit=1;@(negedge clk);frame_commit=0;
 repeat(3)@(negedge clk);sample_new=1;@(negedge clk);sample_new=0;
 repeat(3)@(negedge clk);n=0;
 while(!record_ready)begin @(negedge clk);n++;if(n>3500)$fatal(1,"pipeline source budget");end
 repeat(3)@(negedge clk);
 if(packet[31:0]!=frame_id || packet[223]!=1 || packet[66:58]!=total || packet[84:76]!=et)$fatal(1,"atomic source/class/number tuple");
 end
endtask
always @(negedge clk)if(ev)begin
 events++;
 if(oracle)begin
  check(eid==events && eid<=27,"unique physical numbering");
  if(eid>=1 && eid<=27)begin
   check(ef==truth[eid-1] && truth[eid-1]!=0,"actual classified crossing source");
   check(ek==klass(eid-1,mode),"class is actual shared result");
  end
 end
end
task stream(input integer direction,pattern,which);
integer ecount,last_errors,limit;
begin
 scenario=which;dir=direction;mode=pattern;events=0;held=0;offset=0;last_errors=errors;oracle=0;
 for(k=0;k<27;k++)begin truth[k]=0;armed_truth[k]=0;seen_cross[k]=0;end
 @(negedge clk);start_run=1;@(negedge clk);start_run=0;oracle=1;
 for(f=0;f<180;f++)begin
  speed=which==1 ? (f<6?8:f<8?14:f<10?20:f<12?26:f<14?32:36) : 10;
  if(f!=0)offset+=speed;
  objects=0;preferred=-1;
  for(j=0;j<4;j++)begin ranks[j]=-1;distances[j]=999999;end
  for(k=0;k<27;k++)begin
   x=(dir>0?402:878)+dir*(offset-k*50);
   // Leading E disappears twice just after lock, then actually returns.
   if(x>=400 && x<880 && !((which==2 || which==3) && k==0 && f>=5 && f<(which==2?7:20)))begin
    if(hv && x>=hx-12 && x<=hx+12)preferred=k;
    dd=x>640?x-640:640-x;
    for(j=0;j<4;j++)if(dd<distances[j])begin
     for(q=3;q>j;q--)begin ranks[q]=ranks[q-1];distances[q]=distances[q-1];end
     ranks[j]=k;distances[j]=dd;j=4;
    end
   end
  end
  if(ranks[0]!=-1 && ranks[1]!=-1 && dir*(ranks[0]-ranks[1])<0)begin swap=ranks[0];ranks[0]=ranks[1];ranks[1]=swap;end
  if(preferred!=-1 && ranks[0]!=preferred && ranks[1]!=preferred && ranks[2]!=preferred)ranks[3]=preferred;
  for(j=0;j<4;j++)if(ranks[j]!=-1)begin
   k=ranks[j];x=(dir>0?402:878)+dir*(offset-k*50);objects[j*76+:76]=obj(x,klass(k,pattern));
   // Independent truth uses actual supplied observations; missing frames do
   // not create a crossing. All cases acquire far upstream of the line.
   if(f>=4 && (dir>0?x<636:x>644))armed_truth[k]=1;
   if(armed_truth[k] && !seen_cross[k] && (dir>0?x>644:x<636))begin seen_cross[k]=1;truth[k]=frame_id+1;end
  end
  send();if(state==5)held++;
  check(state!=3 && state!=6,"real available stream cannot permanently stop");
 end
 oracle=0;ecount=pattern==0?6:pattern==1?4:5;
 check(events==27 && total==27 && pt==27-ecount && et==ecount,"27-hole field arrangements/count composition");
 if(errors>last_errors)sensitive++;
 $display("CASE case%0d dir%0d E%0d errors%0d T%0d P%0d E%0d S%0d C%0d diag%04h",which,dir,ecount,errors-last_errors,total,pt,et,state,reason,diag);
end
endtask
task widened_pitch;
integer prior_errors;
begin
 scenario=4;events=0;oracle=0;prior_errors=errors;
 @(negedge clk);start_run=1;@(negedge clk);start_run=0;
 // First pair is two real nonadjacent P,100px apart. E then becomes visible.
 for(f=0;f<12;f++)begin
  objects=0;objects[0+:76]=obj(400+18*f,2);objects[76+:76]=obj(500+18*f,2);
  if(f>=5)objects[152+:76]=obj(450+18*f,3);
  send();check(state!=5 && state!=6 && state!=3,"returning measured E cannot steal its neighboring P");
 end
 if(errors>prior_errors)sensitive++;
 $display("CASE doubled_initial_spacing errors%0d state%0d C%0d D%04h",errors-prior_errors,state,reason,diag);
end
endtask
initial begin
 repeat(5)@(negedge clk);rst_n=1;
 widened_pitch();stream(1,0,1);stream(-1,0,1);stream(1,1,1);stream(-1,1,1);
 stream(1,2,2);stream(-1,2,2);stream(1,2,3);stream(-1,2,3);
`ifdef R9_REFERENCE
 if(sensitive<3)$fatal(1,"R9 sensitivity not established: %0d",sensitive);
 $display("PASS R9 sensitivity: same fixed mechanism tests expose %0d cases; %0d checks/%0d expected mismatches",sensitive,checks,errors);
`else
 if(errors!=0)$fatal(1,"R10 mechanism contract failed %0d/%0d",errors,checks);
 $display("PASS local stream: %0d checks, both directions,27/E6,27/E4,leadingE/27/E5, ramp8to36/50px, actual return, unresolved gap",checks);
`endif
 $finish;
end
initial begin #1000000000;$fatal(1,"watchdog");end
endmodule
