`timescale 1ns/1ps
module tb_result_recorder;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,start_run=0,finish_run=0,frame_bad=0,sample_new=0;
 reg [31:0] frame_id=0;reg [63:0] config_tag=64'h1234;reg [303:0] objects=0;
 wire busy,snapshot_new,ev,dv,dr,region;wire [2:0] state;wire [3:0] reason;
 wire [15:0] run_id,er;wire [8:0] total,pt,et,rt,eid;wire [31:0] ef;
 wire [1:0] ek;wire [3:0] em;wire [35:0] ids;
 reg [8:0] la=0,ea=0;wire [5:0] ld;wire [8:0] empty_id;
 classified_pocket_counter #(.RECORD_ONLY(1),.HYST(4)) dut(clk,rst_n,start_run,finish_run,frame_bad,sample_new,frame_id,config_tag,objects,
 busy,snapshot_new,state,reason,run_id,total,pt,et,rt,dv,dr,region,ids,ev,er,eid,ef,ek,em,la,ld,ea,empty_id);
 integer checks=0,events=0,oracle=0,f,k,j,a,b,tmp,x,d,best,second,offset,index,pitch,step,dir,material,drop_mode;
 integer count_truth,empty_truth,present_truth,kind_truth[0:299],frame_truth[0:299],empty_numbers[0:299];
 reg [1023:0] armed_truth,counted_truth;integer saved_run,saved_total;
 function integer kind(input integer n);begin kind=material==1 ? 3 : material==2 ? 2 : n%3==0 ? 3 : 2;end endfunction
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
    send(objects);check(state!=3,"rank churn and dropout retain known identity");check(total==count_truth,"physical centre crossing oracle");
    if(f%31>2)offset+=dir*step;
   end
   check(events==count_truth && et==empty_truth && pt==present_truth,"class totals");
   for(k=0;k<empty_truth;k++)begin ea=k;repeat(3)@(negedge clk);check(empty_id==empty_numbers[k],"all empty numbers");end
   oracle=0;
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  stream(1,44,6,350,0,1);check(total>20 && dr,"right mixed short pitch/drop");
  stream(-1,44,6,350,0,0);check(total>20 && !dr,"left mixed short pitch");
  stream(1,44,14,180,0,0);check(total>20,"faster observed association below half spacing");
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
  send({152'd0,obj(641,2,320),obj(597,3,320)});check(state==3 && reason==5,"clear reverse stops");
  new_run;send({152'd0,obj(600,2,320),obj(598,3,320)});check(state==3,"ambiguous identity stops");
  new_run;send({228'd0,obj(600,2,320)});@(negedge clk);frame_bad=1;@(negedge clk);frame_bad=0;
  check(state==3 && reason==6,"bad source frame stops");
  new_run;send({228'd0,obj(600,2,320)});frame_id++;send({228'd0,obj(604,2,320)});
  check(state==3 && reason==6,"skipped source frame stops");
  new_run;for(k=0;k<6;k++)send({152'd0,obj(630+k*4,2,320),obj(586+k*4,3,320)});
  send({152'd0,obj(760,2,320),obj(716,3,320)});
  check(state==3 && total==0,"unmatched excessive displacement stops before any invented count");
  $display("PASS result recorder: %0d checks, shared class/short pitch/rank/drop/source/clear/300",checks);$finish;
 end
 initial begin #100000000;$fatal(1,"recorder timeout");end
endmodule
