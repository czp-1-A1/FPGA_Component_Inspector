`timescale 1ns/1ps
module tb_classified_counter;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,start_run=0,finish_run=0,frame_bad=0,sample_new=0;
 reg [31:0] frame_id=0;reg [63:0] config_tag=64'h1234;reg [303:0] objects=0;
 wire busy,snapshot_new,ev,dv,dr,region;wire [2:0] state;wire [3:0] reason;
 wire [15:0] run_id,er;wire [8:0] total,pt,et,rt,eid;wire [31:0] ef;
 wire [1:0] ek;wire [3:0] em;wire [35:0] ids;
 reg [8:0] la=0,ea=0;wire [5:0] ld;wire [8:0] empty_id;
 classified_pocket_counter dut(clk,rst_n,start_run,finish_run,frame_bad,sample_new,frame_id,config_tag,objects,
 busy,snapshot_new,state,reason,run_id,total,pt,et,rt,dv,dr,region,ids,ev,er,eid,ef,ek,em,la,ld,ea,empty_id);
 integer material=0,test_region=0;
 integer checks=0,events=0,mode=0,frame,offset,k,a,b,distance_px,best,second,x,expected_count,expected_empty,expected_present,expected_review;
 integer expected_kind[0:299],expected_reason[0:299],expected_frame[0:299],empty_truth[0:299];
 reg [1023:0] truth_armed,truth_counted;integer direction=1,width,j,index;
 function integer target_kind(input integer k);
 begin target_kind=material==1 ? 3 : material==2 ? 2 : k%3==0 ? 3 : 2;end
 endfunction
 function integer target_reason(input integer k);
 begin target_reason=target_kind(k)==3 ? 0 : k%5==0 ? 4 : 0;end
 endfunction
 function [75:0] obj;
  input integer xx,kind,mask,yy;
  integer half;
  begin half=kind==3 ? 4 : 20;obj={1'b1,kind[1:0],mask[3:0],13'd100,7'd40,7'd40,11'(xx-half),11'(xx+half),10'(yy-8),10'(yy+8)};end
 endfunction
 task check;
  input good;input [255:0] message;
  begin checks=checks+1;if(!good)begin $display("FAIL %s state=%0d reason=%0d frame=%0d total=%0d expected=%0d",message,state,reason,frame_id,total,expected_count);$fatal(1);end end
 endtask
 task new_run;
  begin @(negedge clk);start_run=1;@(negedge clk);start_run=0;events=0;frame_id=0;config_tag=64'h1234;end
 endtask
 task send;
  input [303:0] data;
  begin
   @(negedge clk);objects=data;frame_id=frame_id+1;sample_new=1;
   @(negedge clk);sample_new=0;
   repeat(2)@(negedge clk);
   while(busy)@(negedge clk);
   repeat(2)@(negedge clk);
  end
 endtask
 always @(negedge clk)if(ev)begin
  events=events+1;
  if(mode==1)begin
   check(events<=expected_count,"no extra event");
   check(eid==events && er==run_id,"monotonic event identity");
   check(ek==expected_kind[events-1] && em==expected_reason[events-1],"class/reason follow physical hole");
   check(ef==expected_frame[events-1],"event uses source frame");
  end
 end
 task stream;
  input integer dir,frames;
  begin
   new_run;mode=1;direction=dir;offset=0;truth_armed=0;truth_counted=0;
   expected_count=0;expected_empty=0;expected_present=0;expected_review=0;
   for(frame=0;frame<frames;frame=frame+1)begin
    // Infinite known physical tape. Detector contract: two closest targets,
    // sorted by x; ranks swap and old targets disappear inside the fixed ROI.
    best=100000;second=100000;a=-1;b=-1;
    for(k=0;k<1024;k=k+1)begin
     x=640+(k-512)*80+offset;
     distance_px=x>=640 ? x-640 : 640-x;
     if(distance_px<best)begin second=best;b=a;best=distance_px;a=k;end
     else if(distance_px<second)begin second=distance_px;b=k;end
    end
    if(a>b)begin j=a;a=b;b=j;end
    objects=0;
    for(j=0;j<2;j=j+1)begin
     index=j==0 ? a : b;x=640+(index-512)*80+offset;
     objects[(j+test_region*2)*76+:76]=obj(x,target_kind(index),target_reason(index),test_region==0 ? 320 : 516);
    end
    if(state==2)begin
     for(k=0;k<1024;k=k+1)begin
      x=640+(k-512)*80+offset;width=target_kind(k)==3 ? 4 : 20;
      // Only genuinely observed upstream holes may be armed; no pitch fill.
      if(k==a || k==b)begin
       if(dir>0 ? x+width<637 : x-width>643)truth_armed[k]=1;
       if(truth_armed[k] && !truth_counted[k] && (dir>0 ? x-width>643 : x+width<637) && expected_count<300)begin
        truth_counted[k]=1;expected_kind[expected_count]=target_kind(k);
        expected_reason[expected_count]=target_reason(k);
        expected_frame[expected_count]=frame_id+1;
        if(target_kind(k)==3)begin empty_truth[expected_empty]=expected_count+1;expected_empty=expected_empty+1;end
        else begin expected_present=expected_present+1;if(target_reason(k)!=0)expected_review=expected_review+1;end
        expected_count=expected_count+1;
       end
      end
     end
    end
    send(objects);
    check(state!=3,"rank churn preserves identity");
    check(total==expected_count,"physical crossing count");
    // Stop for several repeated NEW source frames, then resume.
    if(frame%31!=0 && frame%31!=1 && frame%31!=2)offset=offset+dir*6;
   end
   check(events==expected_count && et==expected_empty && pt==expected_present && rt==expected_review,"totals and review subset");
   for(k=0;k<expected_count;k=k+1)begin
    la=k;repeat(3)@(negedge clk);check(ld=={2'(expected_kind[k]),4'(expected_reason[k])},"ledger content");
   end
   for(k=0;k<expected_empty;k=k+1)begin ea=k;repeat(3)@(negedge clk);check(empty_id==empty_truth[k],"empty physical IDs retained");end
   mode=0;
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  stream(1,350);check(total>10 && dr,"rightward mixed tape");
  stream(-1,350);check(total>10 && !dr,"leftward mixed tape");
  // Identical HDMI/sample publication cannot generate another event.
  a=total;@(negedge clk);sample_new=1;@(negedge clk);sample_new=0;repeat(200)@(negedge clk);check(total==a,"duplicate source result ignored");
  config_tag=config_tag+1;send(objects);check(state==3 && reason==6 && total==a,"configuration loss retains count");
  new_run;send({152'd0,obj(560,2,0,320),obj(480,2,0,320)});
  repeat(5)begin objects[75:0]=obj(480+frame_id*4,2,0,320);objects[151:76]=obj(560+frame_id*4,2,0,320);send(objects);end
  check(state==2,"acquires direction");
  objects[75:0]=obj(480+(frame_id-2)*4,2,0,320);objects[151:76]=obj(560+(frame_id-2)*4,2,0,320);send(objects);
  check(state==3 && reason==5,"reverse stops numbering");
  new_run;
  for(k=0;k<6;k++)send({152'd0,obj(580+k*4,2,0,320),obj(500+k*4,2,0,320)});
  check(state==2,"slow reverse setup");
  repeat(4)begin
   send({152'd0,obj(598,2,0,320),obj(518,2,0,320)});
   send({152'd0,obj(600,2,0,320),obj(520,2,0,320)});
   check(state==2 && total==0,"two-pixel jitter does not lose or count");
  end
  for(k=1;k<=5;k++)begin
   send({152'd0,obj(600-k,2,0,320),obj(520-k,2,0,320)});
   check(state==2 && total==0,"slow reverse evidence below hysteresis");
  end
  send({152'd0,obj(594,2,0,320),obj(514,2,0,320)});
  check(state==3 && reason==5 && total==0,"sustained one-pixel reverse stops");
  new_run;
  for(k=0;k<6;k++)send({152'd0,obj(800-k*4,2,0,320),obj(720-k*4,2,0,320)});
  check(state==2 && !dr,"leftward slow reverse setup");
  for(k=1;k<=6;k++)send({152'd0,obj(780+k,2,0,320),obj(700+k,2,0,320)});
  check(state==3 && reason==5 && total==0,"leftward one-pixel reverse stops");
  new_run;
  for(k=0;k<6;k++)send({152'd0,obj(580+k*4,2,0,320),obj(500+k*4,2,0,320)});
  for(k=1;k<=13;k++)send({152'd0,obj(600+k*5,2,0,320),obj(520+k*5,2,0,320)});
  check(state==2 && total==1 && events==1,"one complete crossing");
  repeat(4)begin
   send({152'd0,obj(662,2,0,320),obj(582,2,0,320)});
   send({152'd0,obj(665,2,0,320),obj(585,2,0,320)});
   check(state==2 && total==1 && events==1,"three-pixel count-line jitter keeps identity");
  end
  new_run;send({obj(620,2,0,516),76'd0,obj(620,2,0,320),76'd0});check(state==1 && reason==2,"two regions wait");
  new_run;send({152'd0,obj(560,2,0,320),obj(480,2,0,320)});
  send({obj(620,2,0,516),76'd0,obj(620,2,0,320),76'd0});
  for(k=0;k<6;k++)send({obj(620+k*4,2,0,516),obj(560+k*4,2,0,516),152'd0});
  check(state==2 && region==1 && total==0,"acquire clears stale pitch after region ambiguity");
  new_run;send({152'd0,obj(620,2,0,320),obj(625,2,0,320)});
  send({152'd0,obj(621,2,0,320),obj(626,2,0,320)});check(state==3 && reason==3,"ambiguous neighbors stop");
  new_run;send({152'd0,obj(620,2,0,320),obj(540,2,0,320)});
  frame_id=frame_id+1;send(objects);check(state==3 && reason==6,"skipped source frame stops");
  new_run;@(negedge clk);frame_bad=1;@(negedge clk);frame_bad=0;check(state==3 && reason==6,"bad frame stops");
  stream(1,4600);check(total==300 && state==4 && events==300,"300 automatic finish");
  material=1;test_region=1;stream(1,4600);check(total==300 && et==300 && pt==0 && region==1,"all300 empty second fixed region");
  material=2;stream(-1,4600);check(total==300 && et==0 && pt==300,"all300 present");
  new_run;check(total==0 && et==0 && pt==0,"new run clears logical bounds");
  ea=0;la=0;repeat(3)@(negedge clk);check(empty_id==0 && ld==0,"old RAM never leaks into new run");
  @(negedge clk);finish_run=1;@(negedge clk);finish_run=0;check(state==4,"manual finish");
  $display("PASS classified counter: %0d checks, mixed class/direction/rank/pause/ledger/300",checks);$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
