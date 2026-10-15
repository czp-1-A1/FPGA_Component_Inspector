`timescale 1ns/1ps
module tb_frame_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,valid=1;reg [151:0] objects=0,expected_objects=0;
reg [1:0] mode=3;wire ov,oh,od;wire [23:0] rgb;
always #5 clk=~clk;
experiment_osd #(.LOCAL_SEARCH(1),.SHAPE_MODEL(1),.DIRECT_DETECTION(1),.FRAME_OBJECTS(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.exposure(16'd2244),.gain(16'd48),
 .wb_r(8'd100),.wb_b(8'd100),.wb_tune(1'b0),.wb_pending(1'b0),.view_mode(mode),.edge_count(13'd0),.edge_sum(24'd0),
 .local_box_valid(1'b1),.local_x0(11'd479),.local_x1(11'd546),.local_y0(10'd261),.local_y1(10'd340),
 .frame_objects(objects),.roi_valid(valid),.roi_mean(8'd120),.roi_min(8'd30),.roi_max(8'd180),.roi_state(2'd2),
 .width(16'd1024),.height(16'd600),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),
 .diagnostics(36'd0),.publish_diagnostic({1'b0,8'hfb,17'h1c200}),.pocket_records(340'd0),.pocket_enable(1'b0),
 .track_valid(1'b0),.track_x0(11'd0),.track_x1(11'd0),.track_reason(4'd0),.track_rows(3'd0),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(rgb));
reg [7:0] ascii_rows[0:2047];reg [23:0] cjk_rows[0:2047];
initial begin $readmemh("osd_assets/osd_ascii_rom.hex",ascii_rows);$readmemh("osd_assets/osd_cjk_rom.hex",cjk_rows);end
function [75:0] record(input integer state,reason,x0,x1,y0,y1);
 begin record={1'b1,2'(state),4'(reason),13'd4000,7'd64,7'd76,11'(x0),11'(x1),10'(y0),10'(y1)};end
endfunction
reg checking=0;integer n=0,checked=0,frames=0,px,py,glyph,col,row,s,r,lx,ly,bx0,bx1,by0,by1;
reg [23:0] expected,color;reg [75:0] a;reg [63:0] text_value;reg [103:0] version_value;reg cjk;
reg [2:0] hd=0,hh=0,hv=0;
always @(posedge clk)begin
 hd={hd[1:0],de};hh={hh[1:0],hs};hv={hv[1:0],vs};#1;
 if(rst && (od!==hd[2] || oh!==hh[2] || ov!==hv[2]))$fatal(1,"full OSD sync pipeline changed");
end
always @(negedge clk)if(checking && od)begin
 px=n%1024;py=n/1024;expected=24'h556677;
 if(py>=80 && py<504)begin
  for(integer obj=0;obj<2;obj++)begin
   a=expected_objects[obj*76+:76];s=a[74:73];r=a[72:69];bx0=a[41:31];bx1=a[30:20];by0=a[19:10];by1=a[9:0];
   color=s==2 ? (r!=0 ? 24'hffcc55 : 24'h74dbc7) : s==3 ? 24'hffae64 : 24'hb0c0d4;
   if(a[75])begin
    if(px>=bx0 && px<bx1 && py>=by0 && py<by1 && (px==bx0 || px==bx1-1 || py==by0 || py==by1-1))expected=color;
    lx=bx0>936 ? 936 : bx0;ly=obj==1 && by1<448 ? by1+4 : by0>=136 ? by0-56 : by1+4;if(ly>448)ly=448;
    if(px>=lx && px<lx+88 && py>=ly && py<ly+56)begin
     expected=24'h142336;cjk=0;row=0;glyph=" ";col=(px-lx)%8;
     if(py<ly+24)begin
      if(px<lx+16)begin if(px<lx+8 && py>=ly+4 && py<ly+20)begin glyph=obj==0 ? "1" : "2";row=py-ly-4;end end
      else begin cjk=1;row=py-ly;col=(px-lx-16)%24;glyph=(px-lx-16)/24==0 ? (s==2 ? 18 : 20) : (px-lx-16)/24==1 ? (s==2 ? 19 : 21) : 0;end
     end else begin
      row=(py-ly-24)%16;
      if(s==2 && r!=0)text_value=py<ly+40 ? {r[0] ? "SIZE" : "----",8'd32,r[1] ? "ASP" : "---"} : {r[2] ? "FILL" : "----",8'd32,r[3] ? "REF" : "---"};
      else text_value=py<ly+40 ? "MODEL OK" : "EDGE ON ";
      if(px<lx+64)glyph=text_value[63-((px-lx)/8)*8-:8];
     end
     if(cjk ? cjk_rows[glyph*32+row][23-col] : ascii_rows[glyph*16+row][7-col])expected=color;
    end
   end
  end
  if(rgb!==expected)$fatal(1,"full OSD pixel (%0d,%0d) got%h expected%h frame%0d",px,py,rgb,expected,frames);checked++;
 end
 if(py>=8 && py<24 && ((px>=128 && px<232) || (px>=240 && px<344)))begin
  version_value=px<232 ? "D9 PFB W1C200" : "FRAME EXP V8 ";
  glyph=version_value[103-((px-(px<232?128:240))/8)*8-:8];col=(px-(px<232?128:240))%8;row=py-8;
  expected=ascii_rows[glyph*16+row][7-col] ? 24'hffffff : 24'h142336;
  if(rgb!==expected)$fatal(1,"full OSD version glyph");checked++;
 end
 n++;
end
task raster(input [151:0] value,input integer v);
 begin
 frames++;checking=0;valid=v;objects=0;expected_objects=v ? value : 0;
 vs=1;repeat(20)@(negedge clk);vs=0;repeat(30)@(negedge clk);
 // Metadata arrives after VS, then changes halfway through active video.
 objects=value;checking=1;n=0;
 for(integer yy=0;yy<600;yy++)begin
  de=1;hs=1;for(integer xx=0;xx<1024;xx++)@(negedge clk);
  de=0;hs=0;repeat(20)@(negedge clk);if(yy==300)objects=0;
 end
 repeat(6)@(negedge clk);checking=0;if(n!=614400)$fatal(1,"full raster missing pixels");
 end
endtask
initial begin
 repeat(5)@(negedge clk);rst=1;repeat(5)@(negedge clk);
 raster({record(3,0,700,722,290,312),record(2,0,100,168,160,240)},1);
 raster({record(2,0,520,588,260,340),record(2,5,424,492,260,340)},1);
 raster(0,1);raster({record(2,0,520,588,260,340),record(2,0,424,492,260,340)},0);
 $display("PASS frame OSD: %0d rasters/%0d independent pixels, both boxes/classes/numbers/size-fill reasons, no algorithm ROI or guide, first-active atomic snapshot, zero/stale result suppression, unchanged 3-clock sync",frames,checked);$finish;
end
initial begin #45000000;$fatal(1,"full OSD watchdog");end
endmodule
