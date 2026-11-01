`timescale 1ns/1ps
// Held-out finite E,E,P,P,P feeding sequence. Pixels drive the frozen shared
// classifier and counter. No forced observations, predicted holes, or changed
// original recipes. Luma110 is a sensitivity probe, not measured camera RAW.
module tb_classified_empty_leading;
 reg clk=0,rst_n=0,fs=0,sof=0,accept=0,commit=0,bad=0;
 always #5 clk=~clk;
 reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
 wire sn,ready;wire [303:0] objects;wire [255:0] packet,live;
 wire cr,ev;wire [15:0] er;wire [8:0] ei;wire [31:0] ef;wire [1:0] ek;wire [3:0] em;
 reg [16:0] command=0;
 frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1)) detector(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(bad),
  .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sn),.region_objects(objects));
 classified_count_pipeline #(.STOP_CYCLES(1500000),.PAGE_CYCLES(2000000)) pipeline(
  .clk(clk),.rst_n(rst_n),.source_start(fs),.frame_commit(commit),.frame_bad(bad),.sample_new(sn),
  .config_tag(64'h0444002800006464),.objects(objects),.command(command),
  .frame_record(packet),.record_ready(cr),.live_record(live),
  .event_valid(ev),.event_run(er),.event_id(ei),.event_frame(ef),.event_kind(ek),.event_reason(em));
 integer empty_luma=90,empty_size=6,expect_empty=1,offset=0,frame,px,py,l,v,cycles,events=0,empty_events=0,first_run=-1;
 integer seen_empty=0,seen_present=0,last_events=0,stop=0;
 function integer circle(input integer xx,yy,n);
  begin circle=xx>=0 && xx<n && yy>=0 && yy<n;
   if(n==5 && (xx==0 || xx==4) && (yy==0 || yy==4))circle=0;
   if(n==6 && (xx==0 || xx==5) && (yy<2 || yy>=4))circle=0;
   if(n==7 && (((xx==0 || xx==6) && (yy<2 || yy>=5)) || ((xx==1 || xx==5) && (yy==0 || yy==6))))circle=0;
  end
 endfunction
 function integer image(input integer xx,yy);
  integer j,dx,dy,ux,uy;
  begin image=30;
   if(yy>=250 && yy<350)for(j=0;j<5;j=j+1)begin
    dx=xx-(80+j*80+offset);dy=yy-320;
    if(j<3)begin
     if(dx>=-18 && dx<18 && dy>=-22 && dy<22)begin
      ux=(dx+18)/2;uy=(dy+22)/2;
      if(!((ux<2 || ux>=16) && (uy<4 || uy>=18)))image=180;
     end
    end else begin
     ux=(dx+empty_size)/2;uy=(dy+empty_size)/2;
     if(dx>=-empty_size && dy>=-empty_size && circle(ux,uy,empty_size))image=empty_luma;
    end
    dy=yy-280;ux=(dx+7)/2;uy=(dy+7)/2;
    if(dx>=-7 && dy>=-7 && circle(ux,uy,7))begin image=90;if(ux>=2 && ux<5 && uy>=2 && uy<5)image=110;end
   end
  end
 endfunction
 task ticks(input integer count);begin repeat(count)@(negedge clk);end endtask
 always @(negedge clk)begin
  if(ev)begin
   events=events+1;if(ek==3)empty_events=empty_events+1;
   if(ei!=events || er!=1 || ef!=frame+1)$fatal(1,"event identity/frame invalid");
   $display("EVENT frame=%0d number=%0d kind=%0d",ef,ei,ek);
  end
  if(sn)begin
   if(objects[75] && objects[74:73]==3)seen_empty=seen_empty+1;
   if(objects[151] && objects[150:149]==3)seen_empty=seen_empty+1;
   if(objects[75] && objects[74:73]==2)seen_present=seen_present+1;
   if(objects[151] && objects[150:149]==2)seen_present=seen_present+1;
   for(integer k=0;k<4;k++)if(objects[k*76+75] && objects[k*76+73+:2]==3 &&
     (objects[k*76+10+:10]+objects[k*76+:10]<620 || objects[k*76+10+:10]+objects[k*76+:10]>660))
    $fatal(1,"locating-hole row promoted to EMPTY");
  end
 end
 initial begin
  if(!$value$plusargs("EMPTY_LUMA=%d",empty_luma))empty_luma=90;
  if(!$value$plusargs("EMPTY_SIZE=%d",empty_size))empty_size=6;
  if(!$value$plusargs("EXPECT_EMPTY=%d",expect_empty))expect_empty=empty_luma==90;
  ticks(5);rst_n=1;ticks(5);command=2;ticks(5);
  for(frame=0;frame<100 && !stop;frame=frame+1)begin
   fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py=py+1)begin
    for(px=0;px<1280;px=px+4)begin
     x=px;y=py;accept=1;sof=px==0 && py==0;
     for(l=0;l<4;l=l+1)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   commit=1;ticks(1);commit=0;cycles=0;
   while(!cr && cycles<600000)begin ticks(1);cycles=cycles+1;end
   if(!cr)$fatal(1,"no proved packet frame%0d",frame);
   if(first_run<0 && packet[50:48]==2)first_run=frame;
   if(frame%5==0 || events!=last_events || packet[50:48]==3)
    $display("OBS frame=%0d offset=%0d state=%0d code=%0d total=%0d empty=%0d objects=%076h",frame,offset,packet[50:48],packet[54:51],packet[66:58],packet[84:76],objects);
   last_events=events;
   if(packet[50:48]==3)stop=1;
   if(events==(expect_empty ? 5 : 3))stop=1;
   offset=offset+8;
  end
  $display("RESULT empty_luma=%0d empty_size=%0d first_run=%0d total=%0d empty_events=%0d observed_empty=%0d observed_present=%0d",empty_luma,empty_size,first_run,events,empty_events,seen_empty,seen_present);
  if(expect_empty && (events!=5 || empty_events!=2))$fatal(1,"finite leading-empty sequence failed");
  if(!expect_empty && (events!=3 || empty_events!=0 || seen_empty!=0))$fatal(1,"rejection sensitivity probe unexpected");
  $display("PASS classified empty leading: guarded six-cell E,E,P,P,P, phase-eroded locating row excluded, actual RGB classification");$finish;
 end
 initial begin #900000000;$fatal(1,"diagnostic watchdog");end
endmodule
