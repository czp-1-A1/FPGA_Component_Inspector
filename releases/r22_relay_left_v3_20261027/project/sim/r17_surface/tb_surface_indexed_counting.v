`timescale 1ns/1ps
// Pixel fixtures use the independently specified 180-mm classifier recipe.
// They exercise the actual unchanged T100/T80 flood-fill, not injected boxes.
module tb_surface_indexed_counting;
 reg clk=0,rst_n=0,fs=0,sof=0,accept=0,commit=0,bad=0;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 always #5 clk=~clk;
 wire sn,ready;wire [607:0] candidates;wire hv;wire [10:0] hx;wire [9:0] hy;wire [303:0] objects;wire [255:0] packet,live;
 wire cr,ev;wire [15:0] er;wire [8:0] ei;wire [31:0] ef;wire [1:0] ek;wire [3:0] em;
 reg [16:0] command=0;
 frame_shape_search #(.SURFACE_REVIEW(1),.REVIEW_PROBE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_EMPTY_MARGIN(1)) detector(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(bad),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sn),.region_objects(objects),.recorder_objects(candidates),.recorder_hold_valid(hv),.recorder_hold_x(hx),.recorder_hold_y(hy));
 classified_count_pipeline #(.STOP_CYCLES(1500000),.PAGE_CYCLES(2000000),.OBS_PER_REGION(4),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.LOCAL_RECOVERY(1)) pipeline(
  .clk(clk),.rst_n(rst_n),.source_start(fs),.frame_commit(commit),.frame_bad(bad),.sample_new(sn),
  .config_tag(64'h0444002800006464),.objects(candidates),.command(command),.hold_valid(hv),.hold_x(hx),.hold_y(hy),
  .frame_record(packet),.record_ready(cr),.live_record(live),
  .event_valid(ev),.event_run(er),.event_id(ei),.event_frame(ef),.event_kind(ek),.event_reason(em));
 integer offset=0,f,px,py,l,v,z,n,dx,dy,ux,uy,events=0,checked=0,cycles,kind;
 function integer circle(input integer xx,yy,n);
  begin circle=xx>=0 && xx<n && yy>=0 && yy<n;
   if(n==5 && (xx==0 || xx==4) && (yy==0 || yy==4))circle=0;
   if(n==7 && (((xx==0 || xx==6) && (yy<2 || yy>=5)) || ((xx==1 || xx==5) && (yy==0 || yy==6))))circle=0;
  end
 endfunction
 function integer image(input integer xx,yy);
  integer index,cx,dx,dy,ux,uy;
  begin
   image=30;
   if(yy>=250 && yy<350)begin
    index=(xx-offset-640+8040)/80-100;
    cx=640+index*80+offset;dx=xx-cx;dy=yy-320;
    if((index+300)%3!=0)begin
     if(dx>=-18 && dx<18 && dy>=-22 && dy<22)begin
      ux=(dx+18)/2;uy=(dy+22)/2;
      if(!((ux<2 || ux>=16) && (uy<4 || uy>=18)))image=180;
     end
    end else begin
     ux=(dx+5)/2;uy=(dy+5)/2;
     if(dx>=-5 && dy>=-5 && circle(ux,uy,5))image=90;
    end
    // The round feed holes are visible but must never generate an event.
    dy=yy-280;ux=(dx+7)/2;uy=(dy+7)/2;
    if(dx>=-7 && dy>=-7 && circle(ux,uy,7))begin image=90;if(ux>=2 && ux<5 && uy>=2 && uy<5)image=110;end
   end
  end
 endfunction
 task ticks(input integer count);begin repeat(count)@(negedge clk);end endtask
 always @(negedge clk)if(ev)begin
  if(ek==2 && em!=0)$fatal(1,"normal body event retained review flags");
  events++;kind=(300-events)%3==0 ? 3 : 2;
  if(ei!=events || er!=1 || ek!=kind || ef!=f+1)$fatal(1,"actual classifier event mismatch id%0d kind%0d expected%0d frame%0d/%0d",ei,ek,kind,ef,f+1);
  $display("EVENT source=%0d pocket=%0d class=%0d reason=%h",ef,ei,ek,em);
 end
 initial begin
  ticks(5);rst_n=1;ticks(5);command=2;ticks(5);
  for(f=0;f<70;f++)begin
   fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px+=4)begin
     x=px;y=py;accept=1;sof=px==0 && py==0;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   commit=1;ticks(1);commit=0;cycles=0;
   while(!cr && cycles<600000)begin ticks(1);cycles++;end
   if(!cr || packet[50:48]==3)$fatal(1,"image counting lost frame=%0d state=%0d reason=%0d ready=%b",f,packet[50:48],packet[54:51],cr);
   if(packet[31:0]!=f+1 || !packet[223] || packet[66:58]!=events)$fatal(1,"packet source/count binding");
   for(z=0;z<4;z++)if(objects[z*76+75])begin
    if(z>=2 || objects[z*76+19-:10]+objects[z*76+9-:10]<620)$fatal(1,"feed hole/other region retained");
    checked++;
   end
   if(f%20!=0 && f%20!=1)offset=offset+6;
  end
  if(events<3 || live[84:76]!=1 || live[138:130]!=3)$fatal(1,"mixed count/empty-ID truth events%0d empty%0d first%0d",events,live[84:76],live[138:130]);
  // No source clock/CSI: independent process watchdog must retain the ledger.
  ticks(1500200);
  if(live[50:48]!=3 || live[54:51]!=6 || live[66:58]!=events)$fatal(1,"CSI-stop fail-safe");
  $display("PASS surface indexed counting: 70 actual T100/T80 frames, %0d classified observations, %0d crossings incl empty #3, feed exclusion, pause and independent CSI-stop",checked,events);$finish;
 end
 initial begin #500000000;$fatal(1,"image test watchdog");end
endmodule
