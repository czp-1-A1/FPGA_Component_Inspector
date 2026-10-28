`timescale 1ns/1ps
// Independently declared finite truth:15 pockets, EMPTY003 and EMPTY014.
// Synthetic RGB motion/shape stress, not reconstructed field RAW.
module tb_robust_empty15_clear;
reg clk=0,rst=0,fs=0,sof=0,accept=0,commit=0;
always #5 clk=~clk;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
reg [16:0] command=0;
wire [607:0] records,old_records;
wire sn,old_sn,ready,old_ready,cr,old_cr,ev,old_ev,hold,old_hold;
wire [10:0] hx,old_hx;wire [9:0] hy,old_hy;
wire [255:0] packet,old_packet,live,old_live;
wire [15:0] er,old_er;wire [8:0] ei,old_ei;wire [31:0] ef,old_ef;
wire [1:0] ek,old_ek;wire [3:0] em,old_em;
frame_shape_search #(.ROBUST_SMALL_EMPTY(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),
 .COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),
 .MULTITHRESHOLD_EMPTY(1),.SURFACE_REVIEW(1),.STANDING_REVIEW(1),.REVIEW_PROBE(0)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(1'b0),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sn),.recorder_objects(records),
 .recorder_hold_valid(hold),.recorder_hold_x(hx),.recorder_hold_y(hy));
frame_shape_search_r18 #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),
 .COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),
 .MULTITHRESHOLD_EMPTY(1),.SURFACE_REVIEW(1),.STANDING_REVIEW(1),.REVIEW_PROBE(0)) reference(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(1'b0),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(old_ready),.sample_new(old_sn),.recorder_objects(old_records),
 .recorder_hold_valid(old_hold),.recorder_hold_x(old_hx),.recorder_hold_y(old_hy));
classified_count_pipeline #(.STOP_CYCLES(15000000),.PAGE_CYCLES(200000000),.RECORD_ONLY(1),
 .MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.LOCAL_RECOVERY(1)) pipeline(
 .clk(clk),.rst_n(rst),.source_start(fs),.frame_commit(commit),.frame_bad(1'b0),.sample_new(sn),
 .config_tag(64'h0444002800006464),.objects(records),.empty_probe(32'd0),.command(command),
 .frame_record(packet),.record_ready(cr),.live_record(live),.event_valid(ev),.event_run(er),
 .event_id(ei),.event_frame(ef),.event_kind(ek),.event_reason(em),.hold_valid(hold),.hold_x(hx),.hold_y(hy));
classified_count_pipeline #(.STOP_CYCLES(15000000),.PAGE_CYCLES(200000000),.RECORD_ONLY(1),
 .MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.LOCAL_RECOVERY(1)) old_pipeline(
 .clk(clk),.rst_n(rst),.source_start(fs),.frame_commit(commit),.frame_bad(1'b0),.sample_new(old_sn),
 .config_tag(64'h0444002800006464),.objects(old_records),.empty_probe(32'd0),.command(command),
 .frame_record(old_packet),.record_ready(old_cr),.live_record(old_live),.event_valid(old_ev),.event_run(old_er),
 .event_id(old_ei),.event_frame(old_ef),.event_kind(old_ek),.event_reason(old_em),.hold_valid(old_hold),.hold_x(old_hx),.hold_y(old_hy));
integer speed=14,blur=0,rightward=1,offset=0,f,px,py,l,v,cycles,events=0,old_events=0,empty_events=0;
function automatic integer dot(input integer dx,dy);
 begin dot=dx>=-4 && dx<6 && dy>=-4 && dy<6 &&
 !((dx< -2 || dx>=4) && (dy< -2 || dy>=4)) ? 110 : 30;end
endfunction
function automatic integer circle7(input integer xx,yy);
 begin circle7=xx>=0 && yy>=0 && xx<7 && yy<7 &&
 !(((xx==0 || xx==6) && (yy<2 || yy>=5)) || ((xx==1 || xx==5) && (yy==0 || yy==6)));end
endfunction
function automatic integer image(input integer xx,yy);
 integer index,cx,dx,dy,a,b,r,sum,q;
 begin
  image=30;
  if(yy>=250 && yy<350)begin
   if(rightward!=0)begin index=(350+offset-xx+32+6400)/64-100;cx=350+offset-index*64;end
   else begin index=(xx-(930-offset)+32+6400)/64-100;cx=930-offset+index*64;end
   if(index>=0 && index<15)begin
    dx=xx-cx;dy=yy-320;
    if(index!=2 && index!=13)begin
     if(dx>=-18 && dx<18 && dy>=-22 && dy<22 &&
      !((dx< -14 || dx>=14) && (dy< -14 || dy>=14)))image=180;
    end else if(dx>=-20 && dx<=20 && dy>=-4 && dy<6)begin
     r=index==13 ? blur : 0;sum=0;
     for(q=-r;q<=r;q=q+1)sum=sum+dot(dx+q,dy);
     image=sum/(2*r+1);
    end
    dy=yy-280;a=(dx+7)/2;b=(dy+7)/2;
    if(dx>=-7 && dy>=-7 && circle7(a,b))begin
     image=90;if(a>=2 && a<5 && b>=2 && b<5)image=110;
    end
   end
  end
 end
endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
always @(negedge clk)if(rst)begin
 if(ev)begin
  events=events+1;if(ek==3)empty_events=empty_events+1;
  if(ei!=events || er!=1 || ef<1 || ef>f+1 || ek!=((events==3 || events==14) ? 3 : 2))
   $fatal(1,"15-hole actual event identity/class mismatch gotID%0d expectedID%0d kind%0d source%0d current%0d",ei,events,ek,ef,f+1);
  $display("EVENT new source=%0d id=%0d class=%0d reason=%h",ef,ei,ek,em);
 end
 if(old_ev)begin
  old_events=old_events+1;
  if(old_ei!=old_events || old_er!=1 || old_ef<1 || old_ef>f+1)$fatal(1,"old reference identity/source fault");
  $display("EVENT R18 source=%0d id=%0d class=%0d reason=%h",old_ef,old_ei,old_ek,old_em);
 end
end
initial begin
 if(!$value$plusargs("SPEED=%d",speed))speed=14;
 if(!$value$plusargs("BLUR=%d",blur))blur=0;
 if(!$value$plusargs("RIGHTWARD=%d",rightward))rightward=1;
 ticks(5);rst=1;ticks(5);command=2;ticks(5);
 for(f=0;offset<=1350;f=f+1)begin
  fs=1;ticks(1);fs=0;ticks(3);
  for(py=0;py<720;py=py+1)begin
   for(px=0;px<1280;px=px+4)begin
    x=px;y=py;accept=1;sof=px==0 && py==0;
    for(l=0;l<4;l=l+1)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
    ticks(1);accept=0;sof=0;
   end ticks(2);
  end
  commit=1;ticks(1);commit=0;cycles=0;
  while((!cr || !old_cr) && cycles<600000)begin ticks(1);cycles=cycles+1;end
  if(!cr || !old_cr)$fatal(1,"actual RGB classifier/pipeline deadline source%0d",f+1);
  if(packet[50:48]==3 || packet[50:48]==6)$fatal(1,"candidate stopped source%0d state%0d C%0d",f+1,packet[50:48],packet[54:51]);
  if(packet[31:0]!=f+1 || packet[66:58]!=events)$fatal(1,"candidate source/count snapshot binding");
  if(f%10==0)$display("OBS source=%0d offset=%0d new%0d E%0d old%0d oldE%0d",f+1,offset,packet[66:58],packet[84:76],old_packet[66:58],old_packet[84:76]);
  $display("PIXEL_OBSERVATIONS source=%0d data=%0152h",f+1,records);
  offset=offset+speed;
 end
 ticks(100);
 if(events!=15 || empty_events!=2 || live[66:58]!=15 || live[75:67]!=13 || live[84:76]!=2 || live[138:130]!=3 || live[147:139]!=14)
  $fatal(1,"finite physical truth:15/P13/E2/IDs003,014 required; got%0d P%0d E%0d ids%0d,%0d",events,live[75:67],live[84:76],live[138:130],live[147:139]);
 if(blur==0 && (old_events!=15 || old_live[84:76]!=2))$fatal(1,"unblurred baseline fixture not healthy in R18");
 $display("PASS EMPTY15_MOTION: speed%0d blurRadius%0d right%0d sourceFrames%0d new15/P13/E2/IDs003,014 oldTotal%0d oldE%0d, actual RGB no forced result or predicted event",speed,blur,rightward,f,old_events,old_live[84:76]);$finish;
end
initial begin #650000000;$fatal(1,"15-hole motion watchdog");end
endmodule
