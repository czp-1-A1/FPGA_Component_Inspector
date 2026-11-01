`timescale 1ns/1ps
module tb_pocket_row_phase_trace;
 integer feed_w=16,feed_h=14,feed_gray=180,pocket_y=320,body_present=0,pocket_w=14,pocket_h=12,pocket_gray=180,xyphase=0;
 integer feed_present=1,feed_offset=-40; reg cancel=0;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,source_start=0,commit=0;reg [16:0] command=0;
 wire [607:0] main_objects,local_objects,records;wire sample,occupied,ready;
 reg sof=0,accept=0,material_present=0;reg [10:0] pixel_x=0;reg [9:0] pixel_y=0;reg [95:0] rgb=0;
 assign main_objects={304'd0,records[303:0]};assign local_objects={304'd0,records[607:304]};
 wire mhv;wire [10:0] mhx;wire [9:0] mhy;
 wire lev;wire [15:0] lerun;wire [8:0] leid;wire [1:0] lekind;
 wire [8:0] query,id,ev_id,main_total,local_total,main_unc,local_unc;
 wire pos_new,ev_new,begin_run,clear_run,good,bad,mdv,mdr,ldv,ldr;
 wire [15:0] main_run,local_run,pos_run,ev_run;wire [31:0] current_frame,pos_frame;
 wire [2:0] ms,ls,state;wire [3:0] fault;wire [1:0] kind;
 wire [10:0] x;wire [9:0] y;wire feed,done,stationary,alarm_stop;wire [63:0] station_diag;wire [95:0] frozen_diag;wire [5:0] radius;wire [7:0] detector_diag;wire [8:0] detector_id;wire [63:0] status;
 wire shv,lhv;wire [10:0] shx,lhx;wire [9:0] shy,lhy;
 classified_count_pipeline #(.LINE_X(640),.LOCAL_RECOVERY(1),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),
  .OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(1000000)) main(
  .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(commit),.frame_bad(1'b0),.sample_new(sample),
  .config_tag(64'd1),.objects(main_objects),.empty_probe(32'd0),.command(command),.stop_query_id(9'd0),
  .event_valid(ev_new),.event_run(ev_run),.event_id(ev_id),.event_kind(kind),
  .stop_begin(begin_run),.stop_clear(clear_run),.stop_good_frame(good),.stop_bad_frame(bad),
  .stop_run(main_run),.stop_state(ms),.stop_current_frame(current_frame),.stop_direction_valid(mdv),.stop_direction_right(mdr),
  .stop_total(main_total),.stop_uncertainty(main_unc),.hold_valid(mhv),.hold_x(mhx),.hold_y(mhy));
 classified_count_pipeline #(.ADJACENT_V6(1),.STOP_POSITION(1),.LINE_X(256),.LOCAL_RECOVERY(0),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),
  .OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(1000000)) station(
  .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(commit),.frame_bad(1'b0),.sample_new(sample),
  .config_tag(64'd1),.objects(local_objects),.empty_probe(32'd0),.command(command),.stop_stationary(stationary),.stop_detector_id(detector_id),.stop_detector_diagnostic(detector_diag),.stop_diagnostic(station_diag),.stop_search_radius(radius),.stop_query_id(query),.event_valid(lev),.event_run(lerun),.event_id(leid),.event_kind(lekind),
  .stop_position_new(pos_new),.stop_position_id(id),.stop_position_run(pos_run),.stop_position_frame(pos_frame),.stop_position_x(x),.stop_position_y(y),
  .stop_run(local_run),.stop_state(ls),.stop_direction_valid(ldv),.stop_direction_right(ldr),
  .stop_total(local_total),.stop_uncertainty(local_unc),.stop_search_valid(shv),.stop_search_x(shx),.stop_search_y(shy),
  .hold_valid(lhv),.hold_x(lhx),.hold_y(lhy));
 frame_shape_search #(.POCKET_ROW_ROLES(1),.ADJACENT_V6(1),.RELAY_LEFT_LAYOUT(1),.LOCAL_EDGE_ASSIST(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),
 .STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REGIONS(1),.WIDTH(1280),.HEIGHT(720),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) detector(
 .clk(clk),.rst_n(rst_n),.frame_start(source_start),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(pixel_x),.pixel_y(pixel_y),.rgb(rgb),.ready(ready),.sample_new(sample),.recorder_objects(records),
 .recorder_hold_valid(mhv),.recorder_hold_x(mhx),.recorder_hold_y(mhy),
 .repair_hold_id(shv ? query : 9'd0),.repair_diagnostic_id(detector_id),.repair_hold_radius(shv ? radius : 6'd12),.repair_empty_only(shv),.repair_diagnostic(detector_diag),.repair_hold_valid(shv || lhv),.repair_hold_x(shv ? shx : lhx),.repair_hold_y(shv ? shy : lhy),.transport_occupied(occupied));
 pocket_relay_stop_v2 #(.FIVE_EMPTY_V7(1),.TARGET_X(152),.ADJACENT_V6(1),.POSITION_TOL_PX(80),.RESTART_NEW_RUN(1),.CLK_HZ(10000000),.HOLD_MS(1000),.ADVANCE_PX(32)) ctl(
  .clk(clk),.rst_n(rst_n),.permit(1'b1),.pause(1'b0),.start_run(begin_run),.clear_run(clear_run),.good_frame(good),.bad_frame(bad),
  .transport_occupied(occupied),.current_frame(current_frame),.counter_run(main_run),.station_run(local_run),
  .counter_state(ms),.station_state(ls),.direction_valid(mdv),.direction_right(mdr),.station_dv(ldv),.station_dr(ldr),
  .counter_total(main_total),.station_total(local_total),.counter_uncertainty(main_unc),.station_uncertainty(local_unc),
  .event_valid(ev_new),.event_run(ev_run),.event_id(ev_id),.event_kind(kind),.query_id(query),
  .station_event_valid(lev),.station_event_run(lerun),.station_event_id(leid),.station_event_kind(lekind),
  .position_new(pos_new),.position_id(id),.position_run(pos_run),.position_frame(pos_frame),.position_x(x),.position_y(y),
  .station_diagnostic(station_diag),.diagnostic(frozen_diag),.alarm_stop(alarm_stop),.stationary_hint(stationary),.feed_enable(feed),.state(state),.fault(fault),.status(status),.cycle_done(done));
 integer lead=870,frames=0,events=0,completions=0,measurements=0,wait_frames=0,hold_cycles=0;
 integer a,b,i,j,k,idx,best,bestd,distance_ref,coast;bit selected[0:5];bit begun=0;
 function integer empty(input integer n);empty=1;endfunction
 function [75:0] obj(input integer xx,input integer n);
  obj={1'b1,(empty(n) ? 2'd3 : 2'd2),4'd0,13'd64,7'd8,7'd8,11'(xx-4),11'(xx+4),10'd312,10'd328};
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 integer pxr,pyr,lane,gray,elapsed,bx,by;integer cycles=0;
 always @(negedge clk)cycles++;
 function integer ellipse(input integer xx,yy,cx,cy,w,h);
  integer dx,dy;begin dx=2*(xx-(cx-w/2))+1-w;dy=2*(yy-(cy-h/2))+1-h;ellipse=dx*dx*h*h+dy*dy*w*w<=w*w*h*h;end
 endfunction
 function integer image(input integer xx,yy);
  integer dx,dy;begin
   image=material_present ? 30 : 150;
   if(material_present)begin
    if(ellipse(xx,yy,700+xyphase,pocket_y,pocket_w,pocket_h))image=pocket_gray;
    if(feed_present && ellipse(xx,yy,700+xyphase,pocket_y+feed_offset,feed_w,feed_h))image=feed_gray;
    dx=xx-760;dy=yy-pocket_y;
    if(body_present && dx>=-18 && dx<18 && dy>=-22 && dy<22 &&
       !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))image=180;
   end
  end
 endfunction
 task frame(input bit material);
  integer start_cycle,waited;
  begin
   start_cycle=cycles;material_present=material;source_start=1;ticks(1);source_start=0;ticks(3);
   for(pyr=0;pyr<720;pyr++)begin
    for(pxr=0;pxr<1280;pxr+=4)begin
     pixel_x=pxr;pixel_y=pyr;sof=pxr==0 && pyr==0;accept=1;
     for(lane=0;lane<4;lane++)begin gray=image(pxr+lane,pyr);rgb[95-lane*24-:24]={3{8'(gray)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   commit=1;ticks(1);commit=0;waited=0;
   while(!ready && waited<600000)begin ticks(1);waited++;end
   if(!ready)$fatal(1,"real image analysis missed deadline");
   ticks(1800);
   if(cycles-start_cycle<370000)ticks(370000-(cycles-start_cycle));
   frames++;if(frames%20==0)$display("RGB frame%0d lead%0d main%0d local%0d Q%0d S%0d F%0h",frames,lead,main_total,local_total,query,state,fault);
  end
 endtask

 integer c=0,slot,cy0,cx0,pocket_e,feed_target,checks=0;
 task check_frame(input integer expect_empty);
  begin
   frame(1);pocket_e=0;feed_target=0;
   for(slot=0;slot<4;slot++)if(records[slot*76+75])begin
    cy0=(integer'(records[slot*76+10+:10])+integer'(records[slot*76+:10]))/2;
    cx0=(integer'(records[slot*76+31+:11])+integer'(records[slot*76+20+:11]))/2;
    if(cx0>=696 && cx0<=706 && cy0>=pocket_y-4 && cy0<=pocket_y+4 && records[slot*76+73+:2]==3)pocket_e++;
    if(feed_present && feed_offset!=0 && cy0>=pocket_y+feed_offset-4 && cy0<=pocket_y+feed_offset+4 && records[slot*76+73+:2]>=2)feed_target++;
   end
   $display("ROW_CONTRACT case=%0d feed_present=%0d offset=%0d body=%0d y=%0d w=%0d gray=%0d actual_E=%0d expected_E=%0d wrong_feed_target=%0d",c,feed_present,feed_offset,body_present,pocket_y,pocket_w,pocket_gray,pocket_e,expect_empty,feed_target);
   if(pocket_e!=expect_empty || feed_target!=0)$fatal(1,"pocket/feed role, current-frame evidence or negative evidence contract failed");
   checks++;c++;
  end
 endtask
 integer xp,yp;
 initial begin
  rst_n=0;ticks(5);rst_n=1;ticks(5);command=2;ticks(5);frame(0);
  for(xp=0;xp<2;xp++)for(yp=0;yp<2;yp++)begin
   xyphase=xp;pocket_y=320+yp;pocket_w=6;pocket_h=6;pocket_gray=180;feed_w=16;feed_h=14;feed_gray=180;
   check_frame(1);
  end
  for(xp=0;xp<2;xp++)for(yp=0;yp<2;yp++)begin
   xyphase=xp;pocket_y=320+yp;pocket_w=14;pocket_h=12;pocket_gray=180;feed_w=8;feed_h=8;feed_gray=95;
   check_frame(1);
  end
  $display("PASS POCKET ROW FOUR PHASES:8 fullRGB sources; all4 independent x/y sampling phases for6px aperture and weak8px upper locating hole; no PRESENT anchor");$finish;
 end
 always @(negedge clk)if(c==7 && detector.phase==14)
  $display("PHASE_TRACE small=%0b x=%0d y=%0d w=%0d h=%0d count=%0d bright=%0d area=%0d circular=%0b cover=%0b row=%0b feed_seen=%0b role_sprocket=%0b E=%0b edge=%0b robust=%0b allowed=%0b border=%0b",detector.small_pass,detector.center_x,detector.center_y,detector.width_now,detector.height_now,detector.component_count,detector.bright_count,detector.component_area,detector.circular,detector.covers_body,detector.pocket_role_ok,detector.edge_feed_observed,detector.role_sprocket,detector.empty_match,detector.edge_aperture_shape,detector.robust_small_shape,detector.candidate_allowed,detector.border);
 initial begin #(64'd10000000000);$fatal(1,"diagnostic timeout");end
endmodule
