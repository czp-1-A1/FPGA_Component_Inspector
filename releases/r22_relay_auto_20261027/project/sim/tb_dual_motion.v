`timescale 1ns/1ps
// Actual PPC4 pixels -> shared detector -> unmodified R11 recorder.
// R11 detector comparator receives the identical pixels and own recorder.
module tb_dual_motion;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,fs=0,sof=0,accept=0,start_run=0;reg [31:0] frame_id=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire ready,old_ready,sn,old_sn;wire [607:0] objects,old_objects;
frame_shape_search #(.WIDTH(256),.HEIGHT(240),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) detector(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(1'b0),.pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(sn),.recorder_objects(objects),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
frame_shape_search_R11 #(.WIDTH(256),.HEIGHT(240),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),.ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1)) original(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(1'b0),.pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(old_ready),.sample_new(old_sn),.recorder_objects(old_objects),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
wire busy,ev;wire [2:0] state;wire [3:0] reason;wire [8:0] total,pt,et,eid,gap;wire [31:0] ef;wire [1:0] ek;
wire old_busy;wire [2:0] old_state;wire [8:0] old_total,old_et;
classified_pocket_counter #(.LINE_X(128),.HYST(4),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.LOCAL_RECOVERY(1)) counter(
 .clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(1'b0),.frame_bad(1'b0),.sample_new(sn),.frame_id(frame_id),.config_tag(64'd1),.objects(objects),.busy(busy),.state(state),.reason(reason),.total(total),.present_total(pt),.empty_total(et),.event_valid(ev),.event_id(eid),.event_frame(ef),.event_kind(ek),.uncertainty_from(gap),.ledger_address(9'd0),.empty_address(9'd0));
classified_pocket_counter #(.LINE_X(128),.HYST(4),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.LOCAL_RECOVERY(1)) old_counter(
 .clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(1'b0),.frame_bad(1'b0),.sample_new(old_sn),.frame_id(frame_id),.config_tag(64'd1),.objects(old_objects),.busy(old_busy),.state(old_state),.total(old_total),.empty_total(old_et),.ledger_address(9'd0),.empty_address(9'd0));
integer direction=0,f=0,offset=0,px,py,l,v,cycles,events=0,pgm,checks=0;
function integer image(input integer xx,yy);
 integer a,b,rawx;begin
  rawx=direction==0?xx:255-xx;image=30;
  if(((rawx>=146+offset && rawx<182+offset) || (rawx>=44+offset && rawx<80+offset)) && yy>=90 && yy<134)image=180;
  // Fixed odd/odd sampling phase: T80 is4x4 full, T100 retains its corners.
  a=rawx-(109+offset);b=yy-109;
  if(a>=0 && a<10 && b>=0 && b<10 && !((a/2==0 || a/2==4) && (b/2==0 || b/2==4)))image=110;
 end
endfunction
task ticks(input integer count);repeat(count)@(negedge clk);endtask
always @(negedge clk)if(ev)begin
 events++;
 if(eid!=events || ef!=(events==1?10:events==2?22:35) || ek!=(events==2?3:2))$fatal(1,"actual moving crossing identity/source/kind dir%0d id%0d source%0d kind%0d",direction,eid,ef,ek);
 $display("DUAL_RGB_EVENT dir%0d id%0d source%0d kind%0d",direction,eid,ef,ek);
end
initial begin
 ticks(5);rst_n=1;ticks(3);
 for(direction=0;direction<2;direction++)begin
  events=0;frame_id=0;start_run=1;ticks(1);start_run=0;ticks(3);
  for(f=0;f<43;f++)begin
   frame_id=f+1;offset=-64+4*f;fs=1;ticks(1);fs=0;ticks(3);
   pgm=$fopen($sformatf("dual_rgb_%0d_%0d.pgm",direction,frame_id),"w");$fwrite(pgm,"P2\n256 240\n255\n");
   for(py=0;py<240;py++)begin
    for(px=0;px<256;px+=4)begin
     x=px;y=py;accept=1;sof=px==0 && py==0;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};$fwrite(pgm,"%0d ",v);end
     ticks(1);accept=0;sof=0;
    end
    $fwrite(pgm,"\n");ticks(2);
   end
   $fclose(pgm);ticks(5);cycles=0;
   while((!ready || !old_ready) && cycles<250000)begin ticks(1);cycles++;end
   if(!ready || !old_ready)$fatal(1,"moving frame deadline");ticks(4);
   while(busy || old_busy)ticks(1);ticks(4);
   if(state==3 || state==6 || old_state==3 || old_state==6)$fatal(1,"ordinary input terminated run");
   $display("DUAL_RGB_RESULT dir%0d source%0d data%0152h old%0152h T%0d P%0d E%0d oldT%0d oldE%0d",direction,frame_id,objects,old_objects,total,pt,et,old_total,old_et);
   checks++;
  end
  if(total!=3 || pt!=2 || et!=1 || events!=3 || gap!=0 || old_total!=2 || old_et!=0)$fatal(1,"pixel phase count sensitivity dir%0d T%0d P%0d E%0d oldT%0d oldE%0d",direction,total,pt,et,old_total,old_et);
 end
 $display("PASS dual motion: %0d complete actual PPC4 frames, both directions, finite P/E/P, fixed oddphase EMPTY, unmodified R11 recorder, immutable R11 detector loses E on identical pixels, actual source IDs and no duplicates",checks);$finish;
end
initial begin #300000000;$fatal(1,"moving pixel watchdog");end
endmodule
