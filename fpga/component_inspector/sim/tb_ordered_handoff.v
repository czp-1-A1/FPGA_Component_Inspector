`timescale 1ns/1ps
module tb_ordered_handoff;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,start_run=0,finish_run=0,frame_bad=0,sample_new=0;
 reg [31:0] frame_id=0;reg [63:0] config_tag=64'h88;
 reg [607:0] candidates=0;reg [303:0] legacy=0;
 wire hold_valid;wire [10:0] hold_x;wire [9:0] hold_y;
 wire busy,snapshot_new,ev,dv,dr,region;wire [2:0] state;wire [3:0] reason;
 wire [15:0] run_id,er;wire [8:0] total,pt,et,rt,eid;wire [31:0] ef;
 wire [1:0] ek;wire [3:0] em;wire [35:0] ids;
 reg [8:0] la=0,ea=0;wire [5:0] ld;wire [8:0] empty_id;
`ifdef BASELINE_R7
 classified_pocket_counter #(.RECORD_ONLY(1),.HYST(4),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1)) dut(
 .objects(legacy),
`else
 classified_pocket_counter #(.RECORD_ONLY(1),.HYST(4),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1)) dut(
 .objects(candidates),.hold_valid(hold_valid),.hold_x(hold_x),.hold_y(hold_y),
`endif
 .clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(finish_run),.frame_bad(frame_bad),.sample_new(sample_new),.frame_id(frame_id),.config_tag(config_tag),
 .busy(busy),.snapshot_new(snapshot_new),.state(state),.reason(reason),.run_id(run_id),.total(total),.present_total(pt),.empty_total(et),.review_total(rt),
 .direction_valid(dv),.direction_right(dr),.region(region),.object_ids(ids),.event_valid(ev),.event_run(er),.event_id(eid),.event_frame(ef),.event_kind(ek),.event_reason(em),
 .ledger_address(la),.ledger_data(ld),.empty_address(ea),.empty_id(empty_id));
`ifndef BASELINE_R7
 wire upstream_gap_finished;
 ordered_upstream_gap_regression upstream_reach_contract(upstream_gap_finished);
`endif
 integer checks=0,events=0,scenario=0,dir=1,step=18,frames=100,spacing=44;
 integer preferred_index;integer f,k,j,q,z,best,rank[0:3],distance_rank[0:3],x,ax,swap,t,kk,why;
 integer truth_frame[0:14],truth_kind[0:14],truth_reason[0:14];
 integer armed_truth[0:14],event_seen[0:14],first_event[0:14];
 reg [75:0] observation[0:3];integer original_index[0:3];
 reg oracle=0;integer baseline_failures=0;
 function integer kind(input integer index);
  begin kind=(index==5 || index==10 || index==11) ? 3 : 2;end
 endfunction
 function [75:0] obj(input integer xx,kind_value,mask);
  integer half;begin half=kind_value==3 ? 4 : 19;
   obj={1'b1,kind_value[1:0],mask[3:0],13'd100,7'd38,7'd38,11'(xx-half),11'(xx+half),10'd310,10'd330};end
 endfunction
 task check(input good,input [639:0] message);
  begin checks++;if(!good)begin $display("FAIL ordered %s scenario%0d f%0d state%0d C%0d total%0d E%0d",message,scenario,frame_id,state,reason,total,et);$fatal(1);end end
 endtask
 task send;
  integer watchdog;
  begin
   @(negedge clk);sample_new=1;frame_id++;@(negedge clk);sample_new=0;
   repeat(2)@(negedge clk);watchdog=0;
   while(busy)begin @(negedge clk);watchdog++;if(watchdog>2000)$fatal(1,"bounded per-frame processing budget exceeded");end
   repeat(2)@(negedge clk);
  end
 endtask
 always @(negedge clk)if(ev)begin
  events++;
`ifndef BASELINE_R7
  if(oracle)begin
   check(eid==events && eid<=15 && er==run_id,"one ordered identity per physical pocket");
   check(!event_seen[eid-1],"no repeat identity");event_seen[eid-1]=1;
   check(truth_frame[eid-1]!=0 && ef==truth_frame[eid-1],"deferred event retains actual observed crossing source frame");
   check(ek==truth_kind[eid-1] && em==truth_reason[eid-1],"class/reason fixed at actual crossing, no later reclassification");
   check(kind(eid-1)==ek,"finite15/3 physical class sequence");
  end
`endif
 end
 task stream(input integer direction,mode,speed);
  begin
   oracle=0;scenario=mode;dir=direction;step=speed;events=0;
   for(k=0;k<15;k++)begin truth_frame[k]=0;truth_kind[k]=0;truth_reason[k]=0;armed_truth[k]=0;event_seen[k]=0;end
   @(negedge clk);start_run=1;@(negedge clk);start_run=0;oracle=1;
   for(f=0;f<110;f++)begin
    for(j=0;j<4;j++)begin rank[j]=-1;distance_rank[j]=999999;end
    preferred_index=-1;
    for(k=0;k<15;k++)begin
     x=(dir>0 ? 500 : 780)+dir*(f*step-k*spacing);ax=dir>0 ? x : 1280-x;
     // mode1 real empty10 is absent only in the near-line phase600..648.
     // Its earlier true upstream observations exist outside the nearest2.
     // mode2/3 remove the earlier empty5 at4/5 proved source opportunities
     // beginning at its first downstream observation. LaterP6 may cross first.
     if(x>=410 && x<=870 && !(mode==1 && k==10 && ax>=600 && ax<=648) &&
        !(mode>=2 && k==5 && ax>=646 && ax<646+(mode==3 ? 5 : 4)*step))begin
`ifndef BASELINE_R7
      if(hold_valid && x>=hold_x-12 && x<=hold_x+12)preferred_index=k;
`endif
      t=x>640 ? x-640 : 640-x;
      for(j=0;j<4;j++)if(t<distance_rank[j])begin
       for(q=3;q>j;q--)begin rank[q]=rank[q-1];distance_rank[q]=distance_rank[q-1];end
       rank[j]=k;distance_rank[j]=t;j=4;
      end
     end
    end
    // First2 are precisely original nearest2 sorted byX. Remaining2 are
    // additional actual candidates; output rank is never the identity.
    if(rank[0]!=-1 && rank[1]!=-1 && dir*(rank[0]-rank[1])<0)begin swap=rank[0];rank[0]=rank[1];rank[1]=swap;end
`ifndef BASELINE_R7
    if(preferred_index!=-1)begin
     rank[3]=(rank[0]==preferred_index || rank[1]==preferred_index || rank[2]==preferred_index) ? -1 : preferred_index;
    end
`endif
    candidates=0;legacy=0;
    for(j=0;j<4;j++)begin
     original_index[j]=rank[j];observation[j]=0;
     if(rank[j]!=-1)begin
      k=rank[j];x=(dir>0 ? 500 : 780)+dir*(f*step-k*spacing);kk=kind(k);why=0;
      // A later classifier change whileP6 waits behind a genuinely missing
      // earlierE must not overwrite the earlier actual crossing record.
      if(mode==2 && k==6 && truth_frame[k]!=0)begin kk=3;why=0;end
      else if(mode==2 && k==6)why=8;
      observation[j]=obj(x,kk,why);candidates[j*76+:76]=observation[j];
      if(j<2)legacy[j*76+:76]=observation[j];
      // Independent oracle uses actual supplied classified results and known
      // finite physical indices, never DUT mappings or predicted gap centres.
      if(state==2 && (dir>0 ? x<636 : x>644))armed_truth[k]=1;
      if(state==2 && armed_truth[k] && !truth_frame[k] && (dir>0 ? x>644 : x<636))begin
       truth_frame[k]=frame_id+1;truth_kind[k]=kk;truth_reason[k]=why;
      end
     end
    end
    send;
    if(state==2)for(j=0;j<4;j++)if(original_index[j]!=-1)begin
     k=original_index[j];x=(dir>0 ? 500 : 780)+dir*(f*step-k*spacing);
     if(dir>0 ? x<636 : x>644)armed_truth[k]=1;
    end
`ifndef BASELINE_R7
    if(mode<3)check(state!=3,"finite swap / short empty gap keeps ordered identities");
`endif
   end
`ifdef BASELINE_R7
   if(mode==1 && (total!=15 || et!=3 || state==3))begin baseline_failures++;$display("EXPECTED_R7_SENSITIVITY mode1 total%0d P%0d E%0d state%0d C%0d",total,pt,et,state,reason);end
   else if(mode==1)$fatal(1,"baseline did not expose nearest2 gap omission");
`else
   if(mode<3)begin
    check(events==15 && total==15 && pt==12 && et==3,"finite15 total and3 real empty pockets");
    for(k=0;k<3;k++)begin ea=k;repeat(3)@(negedge clk);check(empty_id==(k==0 ? 6 : k==1 ? 11 : 12),"all empty numbers preserve physical order");end
    if(mode==2)check(truth_frame[6]<truth_frame[5],"laterP really crossed before the absent earlierE returned");
    // Repeat displayed/source record must not re-emit any old event.
    repeat(3)begin @(negedge clk);sample_new=1;@(negedge clk);sample_new=0;repeat(4)@(negedge clk);end
    check(events==15 && total==15,"duplicate source refresh never recounts");
   end else check(state==3 && reason!=0 && total<15,"unresolved5-frame real absence stops without fabricated holes");
`endif
   oracle=0;
  end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
`ifdef BASELINE_R7
  stream(1,1,18);check(baseline_failures==1,"R7 sensitivity established");
  $display("PASS ordered baseline sensitivity: nearest2 misses a genuine empty despite a complete15/3 physical sequence");
`else
  stream(1,0,18);stream(-1,0,18);
  stream(1,1,18);stream(-1,1,18);
  stream(1,2,18);stream(-1,2,18);
  stream(1,3,18);stream(-1,3,18);
  @(negedge clk);finish_run=1;@(negedge clk);finish_run=0;repeat(3)@(negedge clk);
  check(state==0 && total==0 && pt==0 && et==0,"full clear remains usable without reflash");
  wait(upstream_gap_finished);
  $display("PASS ordered handoff: checks=%0d; finite15/3 both directions, late empty phase, ordered pending crossing source/class, bounded missing and clear",checks);
`endif
  $finish;
 end
 initial begin #30000000;$fatal(1,"watchdog");end
endmodule

// Independent same-input early-upstream dropout regression.
`timescale 1ns/1ps
module ordered_upstream_gap_regression(output reg finished=0);
reg clk=0,rst=0,start=0,sample=0;always #5 clk=~clk;
reg[31:0] fs=0;reg[607:0] data=0;wire busy,ev;wire[2:0] state;wire[3:0] reason;wire[8:0] total,pt,et,id;wire[31:0] ef;wire[1:0] ek;
classified_pocket_counter #(.RECORD_ONLY(1),.HYST(4),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1)) dut(
.clk(clk),.rst_n(rst),.start_run(start),.finish_run(1'b0),.frame_bad(1'b0),.sample_new(sample),.frame_id(fs),.config_tag(64'h88),.objects(data),.busy(busy),.state(state),.reason(reason),.total(total),.present_total(pt),.empty_total(et),.event_valid(ev),.event_id(id),.event_frame(ef),.event_kind(ek),.ledger_address(9'd511),.empty_address(9'd511));
integer f,i,j,k,n,x,delta,nearest,distance_px,rank[0:3],pos[0:3],available[0:3],events=0;
function[75:0] object(input integer cx,kind);integer half;begin half=kind==3?4:19;object={1'b1,2'(kind),4'd0,13'd100,7'd38,7'd38,11'(cx-half),11'(cx+half),10'd310,10'd330};end endfunction
always@(negedge clk)if(ev)begin
events++;if(id!=events || ef!=(events==1?6:events==2?8:events==3?10:12) || ek!=((events==2||events==3)?3:2))$fatal(1,"actual crossing source/class/order");
end
initial begin
repeat(4)@(negedge clk);rst=1;start=1;@(negedge clk);start=0;
for(f=1;f<=14;f++)begin
for(i=0;i<4;i++)begin delta=(i==0||i==3)?3:((f+i)%2?3:2);pos[i]=558+(f-1)*20-i*44+delta;available[i]=!(i==2&&f>=7&&f<=9);end
for(j=0;j<4;j++)begin nearest=-1;distance_px=9999;for(i=0;i<4;i++)if(available[i]&&((pos[i]>640?pos[i]-640:640-pos[i])<distance_px))begin nearest=i;distance_px=pos[i]>640?pos[i]-640:640-pos[i];end rank[j]=nearest;if(nearest!=-1)available[nearest]=0;end
if(rank[0]!=-1&&rank[1]!=-1&&pos[rank[0]]>pos[rank[1]])begin n=rank[0];rank[0]=rank[1];rank[1]=n;end
data=0;for(j=0;j<4;j++)if(rank[j]!=-1)data[j*76+:76]=object(pos[rank[j]],rank[j]==1||rank[j]==2?3:2);
@(negedge clk);sample=1;fs=f;@(negedge clk);sample=0;repeat(2)@(negedge clk);while(busy)@(negedge clk);repeat(2)@(negedge clk);
$display("UPSTREAM_GAP source=%0d total=%0d P=%0d E=%0d state=%0d C=%0d",f,total,pt,et,state,reason);
if(state==3)$fatal(1,"bounded actual3-frame dropout must retain identity");
if(total!=(f<6?0:f<8?1:f<10?2:f<12?3:4))$fatal(1,"upstream armed identity silently discarded before4-frame recovery window");
end
if(total!=4||pt!=2||et!=2||events!=4)$fatal(1,"finite P,E,E,P truthful total/class");
$display("PASS upstream gap: same frozen native physical4/P2/E2/source6,8,10,12; old E572 held across3 real missing opportunities");$display("UPSTREAM_GAP_FINISHED");finished=1;
end
initial begin #10000000;if(!finished)$fatal(1,"upstream gap watchdog");end
endmodule
