`timescale 1ns/1ps
module tb_stable_ids_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,valid=1;reg [303:0] objects=0,truth=0;
always #5 clk=~clk;
wire ov,oh,od;wire [23:0] rgb;
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.DIAG_BITS(27),.RESOLUTION_V11(1),.REGIONS(1),.LOCAL_SEARCH(1),.SHAPE_MODEL(1),.DIRECT_DETECTION(1),.FRAME_OBJECTS(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.exposure(16'd1092),.gain(16'd40),
 .wb_r(8'd100),.wb_b(8'd100),.wb_tune(1'b0),.wb_pending(1'b0),.view_mode(2'd3),.edge_count(13'd0),.edge_sum(24'd0),
 .local_box_valid(1'b0),.local_x0(11'd0),.local_x1(11'd0),.local_y0(10'd0),.local_y1(10'd0),
 .frame_objects(objects),.roi_valid(valid),.roi_mean(8'd120),.roi_min(8'd30),.roi_max(8'd180),.roi_state(2'd2),
 .width(16'd1920),.height(16'd1080),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),
 .diagnostics(36'd0),.publish_diagnostic({1'b0,8'hfb,18'h2a300}),.pocket_records(340'd0),.pocket_enable(1'b0),
 .track_valid(1'b0),.track_x0(11'd0),.track_x1(11'd0),.track_reason(4'd0),.track_rows(3'd0),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(rgb));
function [75:0] rec(input integer state,reason,x,y,w,h);
 begin rec={1'b1,2'(state),4'(reason),13'd400,7'(w),7'(h),11'(x),11'(x+w),10'(y),10'(y+h)};end
endfunction
reg [7:0] font[0:2047];initial $readmemh("osd_assets/osd_ascii_rom.hex",font);
reg [2:0] dh=0,dv=0,dd=0;integer errors=0,states=0,pixels=0,rasters=0,n=0,px,py,lx,ly,ch,col,row;
reg checking=0;reg [75:0] a,b,c,d,t;reg [23:0] expected;
task fail(input [511:0] msg);begin if(errors<8)$display("FAIL stable IDs: %0s",msg);errors++;end endtask
always @(posedge clk)begin dd={dd[1:0],de};dh={dh[1:0],hs};dv={dv[1:0],vs};#1;
 if(rst && (od!==dd[2] || oh!==dh[2] || ov!==dv[2]))$fatal(1,"OSD sync changed");end
always @(negedge clk)if(checking && od)begin
 px=n%1280;py=n/1280;
 // The ambiguous single-object summary must be blank in four-object mode.
 if(px>=16 && px<208 && py>=624 && py<720)begin
  if(rgb!==24'h142336)fail("recent-sample summary remains");pixels++;
 end
 // Check the visible R1.1/R1.2/R2.1/R2.2 prefixes at the true current boxes.
 for(integer id=0;id<4;id++)begin
  t=truth[id*76+:76];lx=t[41:31];ly=id%2 ? t[9:0]+4 : t[19:10]-56;
  if(t[75] && px>=lx && px<lx+24 && py>=ly+4 && py<ly+20)begin
   case((px-lx)/8)0:ch=id<2 ? "1" : "2";1:ch=".";2:ch=id%2 ? "2" : "1";endcase
   col=(px-lx)%8;row=py-ly-4;
   expected=font[ch*16+row][7-col] ? (t[74:73]==3 ? 24'hffae64 : t[72:69]!=0 ? 24'hffcc55 : 24'h74dbc7) : 24'h142336;
   if(rgb!==expected)fail("visible number prefix moved to wrong target");pixels++;
  end
 end
 n++;
end
task frame(input [303:0] value,want,input integer v,full);
 begin
 checking=0;valid=v;objects=0;truth=want;vs=1;repeat(20)@(negedge clk);vs=0;repeat(30)@(negedge clk);objects=value;n=0;checking=full;
 de=1;hs=1;@(negedge clk);#1;
 // Raw metadata must be frozen now, even if the incoming bus changes during matching.
 objects=0;
 if(full)begin
  for(integer yy=0;yy<720;yy++)begin
   if(yy!=0)begin de=1;hs=1;end
   for(integer xx=(yy==0 ? 1 : 0);xx<1280;xx++)begin
    @(negedge clk);if(yy==0 && xx==11)begin #1;if(dut.frame_objects_s!==want)fail("per-frame target identity/absence differs from truth");states++;end
   end
   de=0;hs=0;repeat(20)@(negedge clk);if(yy==300)objects=0;
  end
  repeat(6)@(negedge clk);if(n!=921600)$fatal(1,"incomplete stable-ID raster");rasters++;
 end else begin repeat(11)@(negedge clk);#1;if(dut.frame_objects_s!==want)fail("per-frame target identity/absence differs from truth");states++;objects=0;repeat(5)@(negedge clk);if(dut.frame_objects_s!==want)fail("mid-frame metadata changed visible identities");states++;de=0;hs=0;repeat(6)@(negedge clk);end
 checking=0;
 end
endtask
initial begin
 repeat(5)@(negedge clk);rst=1;repeat(5)@(negedge clk);
 a=rec(2,8,600,270,32,32);b=rec(3,0,600,338,12,12);c=rec(2,0,620,462,32,38);d=rec(3,0,620,540,12,12);
 frame({d,c,b,a},{d,c,b,a},1,0);
 // Same vertical pair, one-pixel X jitter reverses detector input order.
 a=rec(2,15,602,271,32,32);b=rec(3,0,598,339,12,12);c=rec(2,5,622,463,32,38);d=rec(3,0,618,541,12,12);
 frame({c,d,a,b},{d,c,b,a},1,1);
 // State and reason are current measurements; they must never be held by ID matching.
 a=rec(3,0,600,270,32,32);c=rec(2,8,620,462,32,38);
 frame({d,c,a,b},{d,c,b,a},1,0);
 frame({76'd0,d,76'd0,b},{d,76'd0,b,76'd0},1,0);
 a=rec(2,0,600,270,32,32);c=rec(2,0,620,462,32,38);
 frame({c,d,a,b},{d,c,b,a},1,1);
 frame({d,c,b,a},0,0,0);
 frame({c,d,a,b},{d,c,b,a},1,0);
 frame(0,0,1,0);
 // An unrelated far-away pair starts a fresh spatial order after absence.
 a=rec(2,0,420,270,32,32);b=rec(3,0,720,338,12,12);
 frame({152'd0,a,b},{152'd0,b,a},1,0);
 if(errors)$fatal(1,"stable IDs regression: %0d failures",errors);
 $display("PASS stable IDs OSD: %0d states, %0d full rasters/%0d independent number-summary pixels; vertical input swaps, both zones, current state/reason, single-target identity, missing/invalid clear, reacquisition, first-pixel raw snapshot, matching before labels and3-clock sync",states,rasters,pixels);$finish;
end
initial begin #30000000;$fatal(1,"stable IDs OSD watchdog");end
endmodule
