`timescale 1ns/1ps
module tb_hold_recovery;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start_run=0,finish_run=0,frame_bad=0,sample_new=0;
reg [31:0] frame_id=0;reg [63:0] config_tag=64'h99;reg [607:0] candidates=0;
wire busy,ev,hold_valid;wire [10:0] hold_x;wire [9:0] hold_y;
wire [2:0] state;wire [3:0] reason;wire [8:0] total,pt,et,eid;wire [31:0] ef;
wire [1:0] ek;wire [15:0] diagnostic;
classified_pocket_counter #(.RECORD_ONLY(1),.HYST(4),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1)
`ifndef R8_REFERENCE
 ,.RECOVERABLE(1)
`endif
 ) dut(.clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(finish_run),.frame_bad(frame_bad),
 .sample_new(sample_new),.frame_id(frame_id),.config_tag(config_tag),.objects(candidates),.busy(busy),
 .state(state),.reason(reason),.total(total),.present_total(pt),.empty_total(et),
 .event_valid(ev),.event_id(eid),.event_frame(ef),.event_kind(ek),.ledger_address(9'd511),.empty_address(9'd511),
 .hold_valid(hold_valid),.hold_x(hold_x),.hold_y(hold_y)
`ifndef R8_REFERENCE
 ,.diagnostic(diagnostic)
`endif
 );
integer checks=0,events=0,scenario=0,dir=1,count=28,speed=18,mode=0;
integer f,k,j,q,x,z,t,swap,preferred,rank[0:3],distance_rank[0:3];
integer crossed[0:299],armed_truth[0:299],truth_frame[0:299],jittered[0:299];
integer held_frames,baseline_failures=0,initial_frame;reg oracle=0;
function integer kind(input integer n,input integer pattern);
begin
 if(pattern==0)kind=(n==0 || n==7 || n==18 || n==21 || n==22 || n==26) ? 3 : 2;
 else if(pattern==1)kind=(n==18 || n==20 || n==22 || n==24 || n==25) ? 3 : 2;
 else if(pattern==2)kind=(n==5 || n==10 || n==11) ? 3 : 2;
 else kind=pattern==3 ? 3 : 2;
end endfunction
function [75:0] object_at(input integer xx,klass);
integer half;begin half=klass==3 ? 4 : 19;
 object_at={1'b1,klass[1:0],4'd0,13'd100,7'd38,7'd38,11'(xx-half),11'(xx+half),10'd310,10'd330};end
endfunction
task check(input bit good,input string message);
 begin checks++;if(!good)$fatal(1,"%s case%0d f%0d state%0d C%0d T%0d E%0d",message,scenario,f,state,reason,total,et);end
endtask
task send;
integer n;begin
 @(negedge clk);sample_new=1;frame_id++;@(negedge clk);sample_new=0;
 repeat(2)@(negedge clk);n=0;
 while(busy)begin @(negedge clk);n++;if(n>2500)$fatal(1,"per-source budget");end
 repeat(2)@(negedge clk);
end endtask
always @(negedge clk)if(ev)begin
 events++;
 if(oracle)begin
 check(eid==events && eid<=count,"monotonic physical ID/no duplicate");
 check(truth_frame[eid-1]!=0 && ef==truth_frame[eid-1],"event source is actual observed classified crossing");
 check(ek==kind(eid-1,mode),"class remains shared classifier result");
 end
end
task stream(input integer direction,pattern,targets,which);
integer ax,limit,missing_index;
begin
 oracle=0;dir=direction;mode=pattern;count=targets;scenario=which;events=0;held_frames=0;initial_frame=frame_id;
 for(k=0;k<300;k++)begin crossed[k]=0;armed_truth[k]=0;truth_frame[k]=0;jittered[k]=0;end
 @(negedge clk);start_run=1;@(negedge clk);start_run=0;oracle=1;
 limit=(targets*50+500)/speed;
 for(f=0;f<limit;f++)begin
 for(j=0;j<4;j++)begin rank[j]=-1;distance_rank[j]=999999;end
 preferred=-1;missing_index=pattern==0 ? 0 : pattern==1 ? 18 : 5;
 for(k=0;k<targets;k++)begin
 x=(dir>0 ? 500 : 780)+dir*(f*speed-k*50);ax=dir>0 ? x : 1280-x;
 if(x>=410 && x<=870 && !((which==1 || which==2) && k==missing_index && ax>=628 && ax<628+(which==1 ? 8 : 9)*speed))begin
 if(hold_valid && x>=hold_x-12 && x<=hold_x+12)preferred=k;
 t=x>640 ? x-640 : 640-x;
 for(j=0;j<4;j++)if(t<distance_rank[j])begin
 for(q=3;q>j;q--)begin rank[q]=rank[q-1];distance_rank[q]=distance_rank[q-1];end
 rank[j]=k;distance_rank[j]=t;j=4;end
 end
 end
 if(rank[0]!=-1 && rank[1]!=-1 && dir*(rank[0]-rank[1])<0)begin swap=rank[0];rank[0]=rank[1];rank[1]=swap;end
 if(preferred!=-1)rank[3]=(rank[0]==preferred || rank[1]==preferred || rank[2]==preferred) ? -1 : preferred;
 candidates=0;
 for(j=0;j<4;j++)if(rank[j]!=-1)begin
 k=rank[j];x=(dir>0 ? 500 : 780)+dir*(f*speed-k*50);
 // Synthetic centre disturbance AFTER a genuine empty was recorded. It is
 // not claimed to be measured phone/RAW motion from the user's clips.
 if(which==3 && kind(k,pattern)==3 && crossed[k] && !jittered[k])begin x=x-dir*24;jittered[k]=1;end
 candidates[j*76+:76]=object_at(x,kind(k,pattern));
 if(f>=4 && (dir>0 ? x<636 : x>644))armed_truth[k]=1;
 if(f>=4 && armed_truth[k] && !crossed[k] && (dir>0 ? x>644 : x<636))begin crossed[k]=1;truth_frame[k]=frame_id+1;end
 end
 send();if(state==5)held_frames++;
`ifdef R8_REFERENCE
 if(state==3)begin baseline_failures++;$display("R8_SENSITIVITY case%0d pattern%0d dir%0d T%0d E%0d C%0d",which,pattern,dir,total,et,reason);f=limit;end
`else
 if(which!=2)check(state!=3 && state!=6,"recoverable discontinuity cannot permanently stop");
`endif
 end
 oracle=0;
`ifndef R8_REFERENCE
 if(which==2)check(state==6 && total<targets,"nine missing opportunities require CHECK, no invented counts");
 else begin
 check(total==targets && events==targets,"all real physical pockets counted exactly once");
 if(pattern==0)check(pt==22 && et==6,"synthetic28/22/6 composition");
 if(pattern==1)check(pt==22 && et==5,"synthetic27/22/5 composition");
 if(pattern==2)check(pt==12 && et==3,"known15/12/3 composition");
 if(which==1)check(held_frames>0,"long true missing gap visibly enters HOLD");
 end
`endif
 $display("CASE_DONE scenario%0d pattern%0d count%0d dir%0d state%0d T%0d P%0d E%0d HOLDframes%0d",which,pattern,targets,dir,state,total,pt,et,held_frames);
end endtask
initial begin
 repeat(5)@(negedge clk);rst_n=1;
 stream(1,0,28,3);stream(1,0,28,1);
`ifdef R8_REFERENCE
 check(baseline_failures==2,"R8 same-input sensitivities established");
 $display("PASS R8 sensitivity for new recovery contract; not a new implementation pass");
`else
 stream(-1,0,28,3);stream(-1,0,28,1);
 stream(1,1,27,1);stream(-1,1,27,1);
 stream(1,2,15,0);stream(-1,2,15,0);
 stream(1,0,28,2);stream(-1,0,28,2);
 speed=6;stream(1,3,300,0);stream(-1,4,300,0);
 @(negedge clk);finish_run=1;@(negedge clk);finish_run=0;repeat(4)@(negedge clk);
 check(state==0 && total==0 && et==0 && pt==0 && diagnostic==0,"full clear still works");
 $display("PASS hold recovery: %0d checks, synthetic28/6 and27/5 arrangements, both directions, real-return8 gaps, unresolved9, countedE jitter,15/3,300allE/P,fullclear",checks);
`endif
 $finish;
end
initial begin #1000000000;$fatal(1,"watchdog");end
endmodule
