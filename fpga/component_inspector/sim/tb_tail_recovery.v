`timescale 1ns/1ps
module tb_tail_recovery;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,start_run=0,finish_run=0,frame_bad=0,sample_new=0;
 reg [31:0] frame_id=0;reg [63:0] config_tag=64'h1234;reg [303:0] objects=0;
 wire busy,snapshot_new,ev,dv,dr,region;wire [2:0] state;wire [3:0] reason;
 wire [15:0] run_id,er;wire [8:0] total,pt,et,rt,eid;wire [31:0] ef;
 wire [1:0] ek;wire [3:0] em;wire [35:0] ids;
 reg [8:0] la=0,ea=0;wire [5:0] ld;wire [8:0] empty_id;
 classified_pocket_counter #(.RECORD_ONLY(1),.HYST(4),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1)) dut(clk,rst_n,start_run,finish_run,frame_bad,sample_new,frame_id,config_tag,objects,
 busy,snapshot_new,state,reason,run_id,total,pt,et,rt,dv,dr,region,ids,ev,er,eid,ef,ek,em,la,ld,ea,empty_id);
 integer checks=0,events=0,oracle=0,f,k,j,a,b,tmp,x,d,best,second,offset,index,pitch,step,dir,material,drop_mode;
 integer state_before;
 integer count_truth,empty_truth,present_truth,kind_truth[0:299],frame_truth[0:299],empty_numbers[0:299];
 reg [1023:0] armed_truth,counted_truth;integer saved_run,saved_total;
 function integer kind(input integer n);begin kind=material==3 ? ((n==6 || n==7 || n==10) ? 3 : 2) : material==1 ? 3 : material==2 ? 2 : n%3==0 ? 3 : 2;end endfunction
 function [75:0] obj(input integer xx,kk,yy);
  integer half;begin half=kk==3 ? 4 : 20;
   obj={1'b1,kk[1:0],4'd0,13'd100,7'd40,7'd40,11'(xx-half),11'(xx+half),10'(yy-8),10'(yy+8)};
  end
 endfunction
 task check(input good,input [511:0] message);
  begin checks++;if(!good)begin $display("FAIL %s F=%0d state=%0d code=%0d total=%0d truth=%0d",message,frame_id,state,reason,total,count_truth);$fatal(1);end end
 endtask
 task new_run;
  begin @(negedge clk);start_run=1;@(negedge clk);start_run=0;events=0;frame_id=0;end
 endtask
 task send(input [303:0] data);
  begin
   @(negedge clk);objects=data;frame_id++;sample_new=1;@(negedge clk);sample_new=0;
   repeat(2)@(negedge clk);while(busy)@(negedge clk);repeat(2)@(negedge clk);
  end
 endtask
 always @(negedge clk)if(snapshot_new && state==3)check(reason!=0,"LOST always carries a nonzero cause");
 always @(negedge clk)if(ev)begin
  events++;
  if(oracle)begin
   check(events<=count_truth,"no event invented from spacing");
   check(eid==events && er==run_id,"unique monotonic identity");
   check(ek==kind_truth[events-1] && em==0,"shared classifier result retained");
   check(ef==frame_truth[events-1],"event binds actual source result");
  end
 end
 task stream(input integer direction,spacing,speed,frames,mat,drop);
  begin
   oracle=0;new_run;oracle=1;dir=direction;pitch=spacing;step=speed;material=mat;drop_mode=drop;
   offset=0;armed_truth=0;counted_truth=0;count_truth=0;empty_truth=0;present_truth=0;
   for(f=0;f<frames;f++)begin
    best=999999;second=999999;a=-1;b=-1;
    for(k=0;k<1024;k++)begin
     x=640+(k-512)*pitch+offset;d=x>=640 ? x-640 : 640-x;
     if(d<best)begin second=best;b=a;best=d;a=k;end
     else if(d<second)begin second=d;b=k;end
    end
    if(a>b)begin tmp=a;a=b;b=tmp;end
    objects=0;
    for(j=0;j<2;j++)begin
     index=j==0 ? a : b;x=640+(index-512)*pitch+offset;
     // Two single-source missing observations, before/near the line. No
     // oracle count occurs while absent; recovered *actual* coordinates count.
     if(!(drop && j==0 && (f==5 || f==36)))begin
      objects[j*76+:76]=obj(x,kind(index),320);
      if(state==2 && count_truth<300)begin
       if(dir>0 ? x<636 : x>644)armed_truth[index]=1;
       if(armed_truth[index] && !counted_truth[index] && (dir>0 ? x>644 : x<636))begin
        counted_truth[index]=1;kind_truth[count_truth]=kind(index);frame_truth[count_truth]=frame_id+1;
        if(kind(index)==3)begin empty_numbers[empty_truth]=count_truth+1;empty_truth++;end else present_truth++;
        count_truth++;
       end
      end
     end
    end
    state_before=state;send(objects);
    // RUN starts in the result being consumed. An actually observed upstream
    // target in that entry frame is eligible for its later complete crossing;
    // already-downstream targets at entry remain excluded.
    if(state_before==1 && state==2)for(j=0;j<2;j++)begin
     index=j==0 ? a : b;x=640+(index-512)*pitch+offset;
     if(objects[j*76+75] && (dir>0 ? x<636 : x>644))armed_truth[index]=1;
    end
    check(state!=3,"rank churn and dropout retain known identity");check(total==count_truth,"physical centre crossing oracle");
    if(f%31>2)offset+=dir*step;
   end
   check(events==count_truth && et==empty_truth && pt==present_truth,"class totals");
   for(k=0;k<empty_truth;k++)begin ea=k;repeat(3)@(negedge clk);check(empty_id==empty_numbers[k],"all empty numbers");end
   oracle=0;
  end
 endtask
 task finite(input integer direction);
  integer lead,delta,n,p0,p1,prev_state;
  begin
   oracle=0;new_run;oracle=1;material=3;dir=direction;offset=0;
   armed_truth=0;counted_truth=0;count_truth=0;empty_truth=0;present_truth=0;
   for(f=0;f<58;f++)begin
    lead=dir>0 ? 500+offset : 780-offset;
    best=999999;second=999999;a=-1;b=-1;
    for(k=0;k<15;k++)begin
     x=lead-dir*k*44;d=x>=640 ? x-640 : 640-x;
     if(x>=410 && x<=870)begin
      if(d<best)begin second=best;b=a;best=d;a=k;end
      else if(d<second)begin second=d;b=k;end
     end
    end
    if(a!=-1 && b!=-1 && lead-dir*a*44>lead-dir*b*44)begin tmp=a;a=b;b=tmp;end
    objects=0;
    for(j=0;j<2;j++)begin
     index=j==0 ? a : b;
     if(index!=-1 && !(index==0 && (f==6 || f==7)))begin
      x=lead-dir*index*44;objects[j*76+:76]=obj(x,kind(index),320);
      if(state==2)begin
       if(dir>0 ? x<636 : x>644)armed_truth[index]=1;
       if(armed_truth[index] && !counted_truth[index] && (dir>0 ? x>644 : x<636))begin
        counted_truth[index]=1;kind_truth[count_truth]=kind(index);frame_truth[count_truth]=frame_id+1;
        if(kind(index)==3)begin empty_numbers[empty_truth]=count_truth+1;empty_truth++;end else present_truth++;
        count_truth++;
       end
      end
     end
    end
    prev_state=state;send(objects);
    if(prev_state==1 && state==2)for(j=0;j<2;j++)begin
     index=j==0 ? a : b;
     if(index!=-1 && objects[j*76+75])begin x=lead-dir*index*44;if(dir>0 ? x<636 : x>644)armed_truth[index]=1;end
    end
    check(state!=3,"finite15 speed20/gap2/hand slip stays associated");check(total==count_truth,"finite15 independent physical identity oracle");
    delta=f==24 ? -9 : f==25 ? 0 : f==26 ? 9 : 20;
    offset+=delta;
   end
   check(events==15 && total==15 && pt==12 && et==3,"human15/3 finite sequence both directions");
   for(k=0;k<3;k++)begin ea=k;repeat(3)@(negedge clk);check(empty_id==empty_numbers[k],"finite empty identities");end
   oracle=0;
  end
 endtask
 task tail_finite(input integer direction,gap);
  integer lead,n,pidx,prev_state,tail_x,completed;
  reg keep;
  begin
   oracle=0;new_run;oracle=1;material=3;dir=direction;offset=0;
   armed_truth=0;counted_truth=0;count_truth=0;empty_truth=0;present_truth=0;completed=0;
   for(f=0;f<48;f++)begin
    lead=dir>0 ? 500+20*f : 780-20*f;
    best=999999;second=999999;a=-1;b=-1;
    for(k=0;k<15;k++)begin
     x=lead-dir*k*44;d=x>=640 ? x-640 : 640-x;
     // Already-recorded holes are occluded in this stimulus: the tail must
     // recover without another same-frame matched target. Never occlude an
     // unrecorded leading hole to manufacture a false known15 expectation.
     keep=x>=410 && x<=870 && !counted_truth[k] &&
      !(k==14 && f>=38 && f<38+gap);
     if(keep)begin
      if(d<best)begin second=best;b=a;best=d;a=k;end
      else if(d<second)begin second=d;b=k;end
     end
    end
    if(a!=-1 && b!=-1 && lead-dir*a*44>lead-dir*b*44)begin tmp=a;a=b;b=tmp;end
    objects=0;
    for(j=0;j<2;j++)begin
     index=j==0 ? a : b;
     if(index!=-1)begin
      x=lead-dir*index*44;objects[j*76+:76]=obj(x,kind(index),320);
      if(state==2)begin
       if(dir>0 ? x<636 : x>644)armed_truth[index]=1;
       if(armed_truth[index] && !counted_truth[index] && (dir>0 ? x>644 : x<636))begin
        counted_truth[index]=1;kind_truth[count_truth]=kind(index);frame_truth[count_truth]=frame_id+1;
        if(kind(index)==3)begin empty_numbers[empty_truth]=count_truth+1;empty_truth++;end else present_truth++;
        count_truth++;
       end
      end
     end
    end
    prev_state=state;send(objects);
    if(prev_state==1 && state==2)for(j=0;j<2;j++)begin
     index=j==0 ? a : b;
     if(index!=-1)begin x=lead-dir*index*44;if(dir>0 ? x<636 : x>644)armed_truth[index]=1;end
    end
    check(state!=3,"finite tail-only actual result/gap does not false-lose");
    check(total==count_truth,"finite tail uses only actual classified crossings");
   end
   check(events==15 && total==15 && pt==12 && et==3,"all15 including final PRESENT; never forced from expected15");
   for(k=0;k<3;k++)begin ea=k;repeat(3)@(negedge clk);check(empty_id==empty_numbers[k],"tail all empty IDs stable");end
   // A stationary already-counted last result may return after silence.
   tail_x=dir>0 ? 664 : 616;
   // Use the last actually observed location from the snapshot rather than
   // pretending the tape continued to move during the absent packets.
   tail_x=dir>0 ? (500+20*(gap==2?40:39)-14*44) : (780-20*(gap==2?40:39)+14*44);
   send({228'd0,obj(tail_x,2,320)});
   check(total==15 && events==15,"last result reappearance never counts twice");
   oracle=0;
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  finite(1);finite(-1);
  tail_finite(1,0);tail_finite(-1,0);tail_finite(1,1);tail_finite(-1,1);tail_finite(1,2);tail_finite(-1,2);
  stream(1,44,6,350,0,1);check(total>20 && dr,"right mixed short pitch/drop");
  stream(-1,44,6,350,0,0);check(total>20 && !dr,"left mixed short pitch");
  stream(1,44,14,350,0,1);stream(-1,44,20,350,0,1);stream(1,44,20,350,0,1);stream(1,44,14,180,0,0);check(total>20,"faster observed association below half spacing");
  stream(1,48,8,2100,1,0);check(total==300 && et==300 && state==4,"all300 empty and auto end");
  stream(-1,48,8,2100,2,0);check(total==300 && pt==300 && et==0,"all300 present");
  saved_run=run_id;@(negedge clk);finish_run=1;@(negedge clk);finish_run=0;repeat(3)@(negedge clk);
  check(state==0 && total==0 && pt==0 && et==0 && rt==0 && ids==0 && !dv,"clear all without hardware reset");
  check(run_id==saved_run,"internal event generation is not reused by clear");
  la=0;ea=0;repeat(3)@(negedge clk);check(ld==0 && empty_id==0,"old RAM hidden after clear");
  new_run;check(run_id==saved_run+1,"new generation after clear");
  // Single recognized result is sufficient to determine real motion. The
  // latest upstream classifier class at crossing is recorded without veto.
  for(k=0;k<8;k++)send({228'd0,obj(580+k*6,k<6 ? 2 : 3,320)});
  check(state==2 && total==0,"single-result lock and class change accepted");
  for(k=8;k<13;k++)send({228'd0,obj(580+k*6,3,320)});
  check(total==1 && et==1 && events==1,"record current EMPTY classification");
  saved_total=total;@(negedge clk);sample_new=1;@(negedge clk);sample_new=0;repeat(200)@(negedge clk);
  check(total==saved_total,"repeated HDMI/source result cannot add count");
  // Two missing proved frames retain an armed target. No event is emitted
  // without an observation; return must have an unambiguous bounded match.
  new_run;for(k=0;k<6;k++)send({152'd0,obj(630+k*4,2,320),obj(586+k*4,3,320)});
  check(state==2,"gap fixture locked");saved_total=total;
  send({152'd0,obj(654,2,320),76'd0});send({152'd0,obj(658,2,320),76'd0});
  check(state==2 && total==saved_total,"two-frame gap pauses without guessed event");
  send({152'd0,obj(662,2,320),obj(618,3,320)});check(state==2,"two-frame recovery bounded observed match");
  // Unresolved target at line stops rather than being silently skipped.
  for(k=0;k<3;k++)send({152'd0,obj(666+k*4,2,320),76'd0});
  check(state==3 && reason==4,"third missing observation stops safely");
  new_run;for(k=0;k<6;k++)send({152'd0,obj(630+k*4,2,320),obj(586+k*4,3,320)});
  send({152'd0,obj(641,2,320),obj(597,3,320)});check(state==2,"9px hand slip is tolerated");
  send({152'd0,obj(650,2,320),obj(606,3,320)});check(state==2,"resume same identities after slip");
  send({152'd0,obj(630,2,320),obj(586,3,320)});check(state==2,"20px bounded hand slip is tolerated");
  send({152'd0,obj(626,2,320),obj(582,3,320)});check(state==3 && reason==5,"sustained reverse beyond unique half-spacing stops");
  new_run;send({152'd0,obj(600,2,320),obj(598,3,320)});check(state==3,"ambiguous identity stops");
  new_run;send({228'd0,obj(600,2,320)});@(negedge clk);frame_bad=1;@(negedge clk);frame_bad=0;
  check(state==3 && reason==6,"bad source frame stops");
  new_run;send({228'd0,obj(600,2,320)});frame_id++;send({228'd0,obj(604,2,320)});
  check(state==3 && reason==6,"skipped source frame stops");
  new_run;for(k=0;k<6;k++)send({152'd0,obj(630+k*4,2,320),obj(586+k*4,3,320)});
  send({152'd0,obj(760,2,320),obj(716,3,320)});
  check(state==3 && total==0,"unmatched excessive displacement stops before any invented count");
  $display("PASS tail recovery: %0d checks, shared class/short pitch/rank/drop/source/clear/300",checks);$finish;
 end
 initial begin #100000000;$fatal(1,"recorder timeout");end
endmodule
